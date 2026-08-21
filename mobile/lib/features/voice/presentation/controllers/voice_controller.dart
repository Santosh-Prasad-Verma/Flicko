import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/azure_calling_service.dart';
import 'package:mobile/data/services/media_engine.dart';
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

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

class VoiceController extends Notifier<VoiceState> {
  late final VoiceRepository _repository;
  late final AzureCallingService _callingService;
  late final MediaEngine _mediaEngine;
  late final AudioPlayer _audioPlayer;
  String? _activeServerId;
  StreamSubscription<List<AzureCallingParticipant>>? _speakerSubscription;

  String? get activeServerId => _activeServerId;

  @override
  VoiceState build() {
    _repository = ref.watch(voiceRepositoryProvider);
    _callingService = ref.watch(azureCallingServiceProvider);
    _mediaEngine = ref.watch(mediaEngineProvider);
    _audioPlayer = ref.watch(audioPlayerProvider);

    ref.onDispose(() {
      _speakerSubscription?.cancel();
      _callingService.disconnect();
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
    state = state.copyWith(
      isConnecting: true,
      error: null,
      activeChannelId: channelId,
    );

    try {
      // 2. Configure Audio Session
      final session = await ref.read(audioSessionProvider);
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ));
      try {
        await session.setActive(true);
      } catch (sessionErr) {
        developer.log('AudioSession activation warning: $sessionErr',
            name: 'VoiceController');
      }

      // 3. Get Azure ACS voice token
      final connection = await _repository.fetchConnection(channelId, serverId);

      // 4. Connect to Azure Calling VoIP Room
      await _callingService.connect(
        connection.token,
        roomName: connection.room ?? 'channel_$channelId',
        channelId: channelId,
        serverId: serverId,
      );

      _speakerSubscription?.cancel();
      _speakerSubscription =
          _callingService.activeSpeakersStream.listen((speakers) {
        state = state.copyWith(
          speakingParticipants: speakers.map((p) => p.id).toSet(),
        );
      });

      state = state.copyWith(
        token: connection.token,
        roomName: connection.room ?? 'channel_$channelId',
        isConnected: true,
        isConnecting: false,
        isMuted: false,
        participants: [
          AzureCallingParticipant(
            id: connection.userId ?? 'me',
            name: 'You',
          ),
          ..._callingService.remoteParticipants.values,
        ],
      );

      _playFlickoJoinSound();
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
        activeChannelId: null,
      );
    }
  }

  Future<void> _playFlickoSFX(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      developer.log('Error playing Flicko sound effect: $assetPath',
          name: 'VoiceController', error: e);
    }
  }

  Future<void> _playFlickoJoinSound() async =>
      _playFlickoSFX('assets/sounds/flicko_join.mp3');
  Future<void> _playFlickoLeaveSound() async =>
      _playFlickoSFX('assets/sounds/flicko_leave.mp3');
  Future<void> _playFlickoUnmuteSound() async =>
      _playFlickoSFX('assets/sounds/flicko_unmute.mp3');
  Future<void> playFlickoNotificationSound() async =>
      _playFlickoSFX('assets/sounds/flicko_notification.mp3');

  Future<void> _playRemoteSound(String url) async {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _audioPlayer.setUrl(url);
      } else {
        await _audioPlayer.setFilePath(url);
      }
      await _audioPlayer.play();
    } catch (e) {
      developer.log('Error playing remote sound',
          name: 'VoiceController', error: e);
    }
  }

  Future<void> sendSoundboardSound(SoundboardSound sound) async {
    if (!state.isConnected) return;
    _playRemoteSound(sound.url);
  }

  Future<void> toggleMute() async {
    if (!state.isConnected) return;
    final newMute = !state.isMuted;
    await _callingService.toggleMicrophone();
    state = state.copyWith(isMuted: newMute, error: null);
    if (!newMute) {
      _playFlickoUnmuteSound();
    }
  }

  Future<void> toggleDeafen() async {
    if (!state.isConnected) return;
    final newDeafen = !state.isDeafened;
    await _callingService.toggleDeafen();
    state = state.copyWith(isDeafened: newDeafen);
  }

  Future<void> toggleVideo() async {
    if (!state.isConnected) return;
    final targetEnabled = !state.isCameraEnabled;

    if (targetEnabled) {
      final camStatus = await Permission.camera.request();
      if (camStatus != PermissionStatus.granted) {
        state = state.copyWith(error: 'Camera permission denied');
        return;
      }
    }

    await _callingService.toggleCamera();
    state = state.copyWith(
      isCameraEnabled: _callingService.isCameraEnabled,
      error: null,
    );
    await _syncPublishState(isVideo: _callingService.isCameraEnabled);
  }

  Future<void> toggleScreenShare() async {
    if (!state.isConnected) return;
    await _callingService.toggleScreenShare();
    state = state.copyWith(
      isScreenSharing: _callingService.isScreenSharing,
      error: null,
    );
    await _syncPublishState(isStreaming: _callingService.isScreenSharing);
  }

  Future<void> _syncPublishState({bool? isVideo, bool? isStreaming}) async {
    final channelId = state.activeChannelId;
    if (channelId == null) return;
    await _repository.syncPublishState(
      channelId,
      isVideo: isVideo,
      isStreaming: isStreaming,
    );
  }

  void setParticipantVolume(String participantId, double volume) {
    final updatedVolumes = Map<String, double>.from(state.participantVolumes);
    updatedVolumes[participantId] = volume.clamp(0.0, 2.0);
    state = state.copyWith(participantVolumes: updatedVolumes);
  }

  Future<void> leaveChannel() async {
    _playFlickoLeaveSound();
    _speakerSubscription?.cancel();
    await _callingService.disconnect();
    _activeServerId = null;
    state = const VoiceState();
    final session = await ref.read(audioSessionProvider);
    await session.setActive(false);
  }
}
