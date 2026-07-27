import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
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
  // Configure audio attributes to play mixed with voice call audio on voice stream
  player.setAndroidAudioAttributes(const AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.voiceCommunication,
  ));
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
  String? _activeServerId;

  String? get activeServerId => _activeServerId;

  @override
  VoiceState build() {
    _repository = ref.watch(voiceRepositoryProvider);
    _audioPlayer = ref.watch(audioPlayerProvider);

    ref.onDispose(() {
      _listener?.dispose();
      _room?.disconnect();
      _room = null;
      _activeServerId = null;
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

    _activeServerId = serverId;
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
          defaultVideoPublishOptions: VideoPublishOptions(
            videoEncoding: VideoEncoding(
              maxBitrate: 1700000,
              maxFramerate: 30,
            ),
          ),
          defaultCameraCaptureOptions: CameraCaptureOptions(
            maxFrameRate: 30,
            params: VideoParametersPresets.h720_169,
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

      _playDiscordJoinSound();
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
        activeChannelId: null,
      );
    }
  }

  Future<void> _playDiscordJoinSound() async {
    try {
      final sfxPlayer = AudioPlayer();
      await sfxPlayer.setAsset('assets/sounds/discord_join.mp3');
      await sfxPlayer.play();
      sfxPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          sfxPlayer.dispose();
        }
      });
    } catch (e) {
      developer.log('Error playing Discord join sound effect', name: 'VoiceController', error: e);
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
        _playDiscordJoinSound();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _updateParticipants();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        state = state.copyWith(
          speakingParticipants: event.speakers.map((p) => p.sid).toSet(),
        );
      })
      ..on<TrackPublishedEvent>((_) {
        _updateParticipants();
      })
      ..on<TrackUnpublishedEvent>((_) {
        _updateParticipants();
      })
      ..on<LocalTrackPublishedEvent>((_) {
        _updateParticipants();
      })
      ..on<LocalTrackUnpublishedEvent>((_) {
        _updateParticipants();
      })
      ..on<TrackSubscribedEvent>((_) {
        _updateParticipants();
      })
      ..on<TrackUnsubscribedEvent>((_) {
        _updateParticipants();
      })
      ..on<TrackMutedEvent>((_) {
        _updateParticipants();
      })
      ..on<TrackUnmutedEvent>((_) {
        _updateParticipants();
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
    final room = state.room;
    if (room == null) return;
    final local = room.localParticipant;
    state = state.copyWith(
      participants: [
        if (local != null) local,
        ...room.remoteParticipants.values,
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

    // Request camera permission before toggling
    final camStatus = await Permission.camera.request();
    if (camStatus != PermissionStatus.granted) {
      state = state.copyWith(error: 'Camera permission denied');
      return;
    }

    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    try {
      final isVideoEnabled = localParticipant.isCameraEnabled();
      await localParticipant.setCameraEnabled(!isVideoEnabled);
      _updateParticipants();
    } catch (e) {
      developer.log('Failed to toggle camera video', name: 'VoiceController', error: e);
      state = state.copyWith(error: 'Camera track publish failed: ${e.toString()}');
    }
  }

  static const _screenCaptureChannel =
      MethodChannel('tech.focko.flicko/screen_capture');

  Future<void> toggleScreenShare() async {
    final room = state.room;
    if (room == null) return;

    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    try {
      final isScreenShareEnabled = localParticipant.isScreenShareEnabled();

      if (!isScreenShareEnabled && Platform.isAndroid) {
        // MUST start Android foreground service BEFORE launching MediaProjection screen capture
        try {
          await _screenCaptureChannel.invokeMethod('startService');
        } catch (e) {
          developer.log(
            'Failed to start screen capture foreground service',
            name: 'VoiceController',
            error: e,
          );
        }
      }

      await localParticipant.setScreenShareEnabled(!isScreenShareEnabled);
      _updateParticipants();

      if (isScreenShareEnabled && Platform.isAndroid) {
        // Screen share was just disabled — stop the foreground service
        try {
          await _screenCaptureChannel.invokeMethod('stopService');
        } catch (e) {
          developer.log(
            'Failed to stop screen capture service',
            name: 'VoiceController',
            error: e,
          );
        }
      }
    } catch (e) {
      developer.log('Error toggling screen share', name: 'VoiceController', error: e);
      final String userMsg = e.toString().contains('TrackPublishException')
          ? 'Screen sharing cancelled or unavailable'
          : 'Failed to share screen: ${e.toString()}';
      state = state.copyWith(error: userMsg);

      // Auto-clear error toast after 3 seconds so banner does not stay on screen
      Future.delayed(const Duration(seconds: 3), () {
        if (state.error == userMsg) {
          state = state.copyWith(error: null);
        }
      });

      // Stop the service if we started it but screen share failed or was cancelled
      if (Platform.isAndroid) {
        try {
          await _screenCaptureChannel.invokeMethod('stopService');
        } catch (_) {}
      }
    }
  }

  /// Sets per-user volume override (0.0 to 2.0)
  void setParticipantVolume(String participantSid, double volume) {
    final updatedVolumes = Map<String, double>.from(state.participantVolumes);
    updatedVolumes[participantSid] = volume.clamp(0.0, 2.0);
    state = state.copyWith(participantVolumes: updatedVolumes);
  }

  Future<void> leaveChannel() async {
    await state.room?.disconnect();
    _activeServerId = null;
    state = const VoiceState();
    final session = await ref.read(audioSessionProvider);
    await session.setActive(false);
  }
}
