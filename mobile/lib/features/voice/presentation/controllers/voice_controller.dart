import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';
import 'voice_state.dart';

final audioPlayerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

final audioSessionProvider = Provider<Future<AudioSession>>((ref) {
  return AudioSession.instance;
});

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

class VoiceController extends Notifier<VoiceState> {
  late final VoiceRepository _repository;
  EventsListener<RoomEvent>? _listener;
  late final AudioPlayer _audioPlayer;
  Room? _room;

  @override
  VoiceState build() {
    _repository = ref.watch(voiceRepositoryProvider);
    _audioPlayer = ref.watch(audioPlayerProvider);

    ref.onDispose(() {
      _listener?.dispose();
      _room?.disconnect();
      _room = null;
    });

    return const VoiceState();
  }

  Future<void> joinChannel(String channelId, String serverId) async {
    if (state.activeChannelId == channelId && state.isConnected) return;

    // 1. Request Permissions
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      state = state.copyWith(error: 'Microphone permission denied');
      return;
    }

    state = state.copyWith(isConnecting: true, error: null, activeChannelId: channelId);

    try {
      // 2. Configure Audio Session
      final session = await ref.read(audioSessionProvider);
      await session.configure(const AudioSessionConfiguration.speech());
      if (!await session.setActive(true)) {
        throw Exception('Failed to activate audio session');
      }

      // 3. Get Token
      final token = await _repository.getAccessToken(channelId, serverId);

      // 4. Connect to Room
      final room = await _repository.connect(
        token,
        options: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
          ),
        ),
      );

      _setupRoomListeners(room);

      // 5. Publish Local Audio
      bool micPublishFailed = false;
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
      } catch (trackErr) {
        developer.log('Failed to publish microphone track', name: 'VoiceController', error: trackErr);
        micPublishFailed = true;
      }

      state = state.copyWith(
        room: room,
        isConnected: true,
        isConnecting: false,
        isMuted: micPublishFailed,
        error: micPublishFailed ? 'Failed to publish audio track (joined in listen-only mode)' : null,
        participants: [room.localParticipant!, ...room.remoteParticipants.values],
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
        activeChannelId: null,
      );
    }
  }

  void _setupRoomListeners(Room room) {
    _listener = room.createListener();

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        state = const VoiceState();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _updateParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _updateParticipants();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        state = state.copyWith(
          speakingParticipants: event.speakers.map((p) => p.sid).toSet(),
        );
      })
      ..on<DataReceivedEvent>((event) {
        final decoded = utf8.decode(event.data);
        final data = jsonDecode(decoded);
        if (data['type'] == 'soundboard') {
          _playRemoteSound(data['url']);
        }
      });
  }

  Future<void> _playRemoteSound(String url) async {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _audioPlayer.setUrl(url);
      } else {
        await _audioPlayer.setFilePath(url);
      }
      await _audioPlayer.play();
    } catch (e) {
      developer.log('Error playing remote sound', name: 'VoiceController', error: e);
    }
  }

  Future<void> sendSoundboardSound(SoundboardSound sound) async {
    final room = state.room;
    if (room == null) return;

    // 1. Play locally
    _playRemoteSound(sound.url);

    // 2. Send to others
    final message = jsonEncode({
      'type': 'soundboard',
      'soundId': sound.id,
      'url': sound.url,
    });

    await room.localParticipant?.publishData(
      utf8.encode(message),
      reliable: true,
    );
  }


  void _updateParticipants() {
    if (state.room == null) return;
    state = state.copyWith(
      participants: [
        state.room!.localParticipant!,
        ...state.room!.remoteParticipants.values,
      ],
    );
  }

  Future<void> toggleMute() async {
    final room = state.room;
    if (room == null) return;

    final newMute = !state.isMuted;
    try {
      await room.localParticipant?.setMicrophoneEnabled(!newMute);
      
      // If we are unmuting, we must also undeafen (a deafened user cannot be unmuted)
      bool newDeafen = state.isDeafened;
      if (!newMute && state.isDeafened) {
        newDeafen = false;
        // Resubscribe to remote audio tracks
        for (final p in room.remoteParticipants.values) {
          for (final sub in p.audioTrackPublications) {
            await sub.subscribe();
          }
        }
      }

      state = state.copyWith(isMuted: newMute, isDeafened: newDeafen, error: null);
    } catch (trackErr) {
      developer.log('Failed to toggle microphone', name: 'VoiceController', error: trackErr);
      state = state.copyWith(error: 'Failed to access microphone: $trackErr');
    }
  }

  Future<void> toggleDeafen() async {
    final room = state.room;
    if (room == null) return;

    final newDeafen = !state.isDeafened;
    // Deafen logic: unsubscribe/subscribe remote audio tracks
    for (final p in room.remoteParticipants.values) {
      for (final sub in p.audioTrackPublications) {
        if (newDeafen) {
          await sub.unsubscribe();
        } else {
          await sub.subscribe();
        }
      }
    }

    // If we are deafening ourselves, we MUST also mute ourselves
    bool newMute = state.isMuted;
    if (newDeafen && !state.isMuted) {
      newMute = true;
      try {
        await room.localParticipant?.setMicrophoneEnabled(false);
      } catch (trackErr) {
        developer.log('Failed to mute on deafen', name: 'VoiceController', error: trackErr);
      }
    }
    // Note: When undeafening, we do not automatically unmute, so the user stays in their controlled mute state.

    state = state.copyWith(isDeafened: newDeafen, isMuted: newMute);
  }

  Future<void> toggleVideo() async {
    final room = state.room;
    if (room == null) return;

    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    final isVideoEnabled = localParticipant.isCameraEnabled();
    await localParticipant.setCameraEnabled(!isVideoEnabled);
    _updateParticipants();
  }

  Future<void> toggleScreenShare() async {
    final room = state.room;
    if (room == null) return;

    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    try {
      final isScreenShareEnabled = localParticipant.isScreenShareEnabled();
      await localParticipant.setScreenShareEnabled(!isScreenShareEnabled);
      _updateParticipants();
    } catch (e) {
      developer.log('Error toggling screen share', name: 'VoiceController', error: e);
      state = state.copyWith(error: 'Failed to share screen: ${e.toString()}');
    }
  }

  Future<void> leaveChannel() async {
    await state.room?.disconnect();
    state = const VoiceState();
    final session = await ref.read(audioSessionProvider);
    await session.setActive(false);
  }
}
