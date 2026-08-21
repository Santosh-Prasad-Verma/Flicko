import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile/data/services/media_engine.dart';

final mediaEngineProvider = Provider<MediaEngine>((ref) {
  final engine = MediaEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

final azureCallingServiceProvider = Provider<AzureCallingService>((ref) {
  final service = AzureCallingService(ref.watch(mediaEngineProvider));
  ref.onDispose(() => service.disconnect());
  return service;
});

class AzureCallingParticipant {
  final String id;
  final String name;
  final bool isSpeaking;
  final bool isMuted;
  final bool hasVideo;
  final RTCVideoRenderer? videoRenderer;

  const AzureCallingParticipant({
    required this.id,
    required this.name,
    this.isSpeaking = false,
    this.isMuted = false,
    this.hasVideo = false,
    this.videoRenderer,
  });

  bool isMicrophoneEnabled() => !isMuted;
  bool isCameraEnabled() => hasVideo;
  bool isScreenShareEnabled() => false;

  AzureCallingParticipant copyWith({
    String? id,
    String? name,
    bool? isSpeaking,
    bool? isMuted,
    bool? hasVideo,
    RTCVideoRenderer? videoRenderer,
  }) {
    return AzureCallingParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      hasVideo: hasVideo ?? this.hasVideo,
      videoRenderer: videoRenderer ?? this.videoRenderer,
    );
  }
}

class AzureCallingService extends ChangeNotifier {
  final MediaEngine _mediaEngine;

  AzureCallingService(this._mediaEngine);

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraEnabled = false;
  bool _isScreenSharing = false;
  bool _isDeafened = false;
  String? _currentRoom;
  String? _token;

  final Map<String, AzureCallingParticipant> _participants = {};
  final _activeSpeakersController =
      StreamController<List<AzureCallingParticipant>>.broadcast();

  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isScreenSharing => _isScreenSharing;
  bool get isDeafened => _isDeafened;
  String? get currentRoom => _currentRoom;
  String? get token => _token;
  MediaEngine get mediaEngine => _mediaEngine;

  Map<String, AzureCallingParticipant> get remoteParticipants =>
      Map.unmodifiable(_participants);
  Stream<List<AzureCallingParticipant>> get activeSpeakersStream =>
      _activeSpeakersController.stream;

  RTCVideoRenderer? get localVideoRenderer => _mediaEngine.localRenderer;

  Future<void> connect(
    String token, {
    String? roomName,
    String? channelId,
    String? serverId,
  }) async {
    _token = token;
    _currentRoom = roomName ?? (channelId != null ? 'channel_$channelId' : 'voice_room');

    if (Platform.isAndroid) {
      try {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('Warning: Could not set Android audio mode on join: $e');
      }
    }

    // Initialize local media through MediaEngine
    try {
      await _mediaEngine.initLocalMedia();
      _isConnected = true;
      _isMuted = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Warning: Could not initialize local media: $e');
      _isConnected = true;
      notifyListeners();
    }
  }

  /// Toggle local microphone (mute/unmute)
  Future<void> toggleMicrophone() async {
    await setMicrophoneMuted(!_isMuted);
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    _isMuted = muted;
    await _mediaEngine.setMicrophoneMuted(_isMuted);
    notifyListeners();
  }

  /// Toggle local camera
  Future<void> toggleCamera() async {
    await setCameraEnabled(!_isCameraEnabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    _isCameraEnabled = enabled;
    await _mediaEngine.setCameraEnabled(_isCameraEnabled);
    notifyListeners();
  }

  /// Toggle screen share
  Future<void> toggleScreenShare() async {
    await setScreenShareEnabled(!_isScreenSharing);
  }

  Future<void> setScreenShareEnabled(bool enabled) async {
    _isScreenSharing = enabled;
    await _mediaEngine.setScreenShareEnabled(_isScreenSharing);
    notifyListeners();
  }

  /// Toggle deafen mode
  Future<void> toggleDeafen() async {
    await setDeafened(!_isDeafened);
  }

  Future<void> setDeafened(bool deafened) async {
    _isDeafened = deafened;
    await _mediaEngine.setDeafened(_isDeafened);
    notifyListeners();
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _isCameraEnabled = false;
    _isScreenSharing = false;
    _isMuted = false;
    _isDeafened = false;
    _currentRoom = null;
    _token = null;
    _participants.clear();

    await _mediaEngine.disposeRoomMedia();
    notifyListeners();
  }
}
