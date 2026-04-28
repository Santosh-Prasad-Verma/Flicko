import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';
import 'voice_state.dart';


class VoiceController extends StateNotifier<VoiceState> {
  final VoiceRepository _repository;
  EventsListener<RoomEvent>? _listener;
  final AudioPlayer _audioPlayer = AudioPlayer();

  VoiceController(this._repository) : super(const VoiceState());


  Future<void> joinChannel(String channelId) async {
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
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      if (!await session.setActive(true)) {
        throw Exception('Failed to activate audio session');
      }

      // 3. Get Token
      final token = await _repository.getAccessToken(channelId);

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
      await room.localParticipant?.setMicrophoneEnabled(true);

      state = state.copyWith(
        room: room,
        isConnected: true,
        isConnecting: false,
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
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing remote sound: $e');
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
    await room.localParticipant?.setMicrophoneEnabled(!newMute);
    state = state.copyWith(isMuted: newMute);
  }

  Future<void> toggleDeafen() async {
    final room = state.room;
    if (room == null) return;

    final newDeafen = !state.isDeafened;
    // Deafen logic: mute microphone AND local playback
    // In LiveKit, we might handle this by muting all remote audio tracks
    for (final p in room.remoteParticipants.values) {
      for (final sub in p.audioTrackPublications) {
        if (!newDeafen) {
          await sub.subscribe();
        } else {
          await sub.unsubscribe();
        }
      }
    }
    
    if (newDeafen && !state.isMuted) {
      await toggleMute();
    } else if (!newDeafen && state.isMuted) {
      await toggleMute();
    }

    state = state.copyWith(isDeafened: newDeafen);
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

    final isScreenShareEnabled = localParticipant.isScreenShareEnabled();
    await localParticipant.setScreenShareEnabled(!isScreenShareEnabled);
    _updateParticipants();
  }

  Future<void> leaveChannel() async {
    await state.room?.disconnect();
    state = const VoiceState();
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  void dispose() {
    _listener?.dispose();
    state.room?.disconnect();
    _audioPlayer.dispose();
    super.dispose();
  }

}

final voiceControllerProvider = StateNotifierProvider<VoiceController, VoiceState>((ref) {
  final repository = ref.watch(voiceRepositoryProvider);
  return VoiceController(repository);
});
