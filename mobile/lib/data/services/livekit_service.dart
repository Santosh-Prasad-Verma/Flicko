import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/services/media_engine.dart';

final mediaEngineProvider = Provider<MediaEngine>((ref) {
  return MediaEngine();
});

final livekitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService(ref.watch(mediaEngineProvider));
});

class LiveKitService {
  final MediaEngine _mediaEngine;

  LiveKitService(this._mediaEngine);

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isDeafened = false;

  Room? get currentRoom => _room;
  bool get isDeafened => _isDeafened;
  MediaEngine get mediaEngine => _mediaEngine;

  final _activeSpeakersController = StreamController<List<Participant>>.broadcast();
  Stream<List<Participant>> get activeSpeakersStream => _activeSpeakersController.stream;

  Future<void> connect(
    String token, {
    RoomOptions? roomOptions,
    ConnectOptions? connectOptions,
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    final roomOps = roomOptions ?? const RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultAudioPublishOptions: AudioPublishOptions(
        dtx: true,
      ),
    );

    _room = Room(roomOptions: roomOps);

    final connOps = connectOptions ?? const ConnectOptions(
      autoSubscribe: true,
    );

    final defaultAudioOptions = audioCaptureOptions ?? const AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      typingNoiseDetection: true,
    );

    AppConfig.requireLivekitUrl();

    await _room!.connect(
      AppConfig.livekitUrl,
      token,
      connectOptions: connOps,
    );

    try {
      await _mediaEngine.setMicrophoneEnabled(
        _room!,
        true,
        audioCaptureOptions: defaultAudioOptions,
      );
    } catch (e) {
      debugPrint('Warning: Could not enable microphone on join: $e');
    }

    _listener?.dispose();
    _listener = _room!.createListener();
    _listener!.on<ActiveSpeakersChangedEvent>((event) {
      _activeSpeakersController.add(event.speakers);
    });
  }

  /// Toggle local microphone (mute/unmute)
  Future<void> toggleMicrophone() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isMicrophoneEnabled();
    await _mediaEngine.setMicrophoneEnabled(_room!, !isEnabled);
  }

  /// Toggle local camera
  Future<void> toggleCamera() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isCameraEnabled();
    await _mediaEngine.setCameraEnabled(_room!, !isEnabled);
  }

  /// Toggle screen share
  Future<void> toggleScreenShare() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isScreenShareEnabled();
    await _mediaEngine.setScreenShareEnabled(_room!, !isEnabled);
  }

  /// Toggle deafen mode
  Future<void> toggleDeafen() async {
    if (_room == null) return;
    _isDeafened = !_isDeafened;
    for (final participant in _room!.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        if (_isDeafened) {
          await publication.unsubscribe();
        } else {
          await publication.subscribe();
        }
      }
    }
  }

  Future<void> disconnect() async {
    _listener?.dispose();
    _listener = null;
    if (_room != null) {
      await _mediaEngine.disposeRoomMedia(_room);
      await _room!.disconnect();
      _room = null;
    }
  }
}
