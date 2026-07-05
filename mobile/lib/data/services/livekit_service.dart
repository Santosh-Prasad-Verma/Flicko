import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/config/app_config.dart';

final livekitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService();
});

class LiveKitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isDeafened = false;

  Room? get currentRoom => _room;
  bool get isDeafened => _isDeafened;

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

    // Default WebRTC Audio Processing options: Echo Cancellation, Noise Suppression, Auto Gain
    final defaultAudioOptions = audioCaptureOptions ?? const AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      typingNoiseDetection: true,
    );

    await _room!.connect(
      AppConfig.livekitUrl,
      token,
      connectOptions: connOps,
    );

    // Enable local microphone with WebRTC Noise Suppression
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(true, audioCaptureOptions: defaultAudioOptions);
    } catch (e) {
      debugPrint('Warning: Could not enable microphone on join: $e');
    }

    // Listen to active speakers event
    _listener?.dispose();
    _listener = _room!.createListener();
    _listener!.on<ActiveSpeakersChangedEvent>((event) {
      _activeSpeakersController.add(event.speakers);
    });
  }

  /// Toggle local microphone (mute/unmute) with WebRTC noise suppression
  Future<void> toggleMicrophone() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isMicrophoneEnabled();
    const audioOptions = AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      typingNoiseDetection: true,
    );
    await _room!.localParticipant!.setMicrophoneEnabled(!isEnabled, audioCaptureOptions: audioOptions);
  }

  /// Toggle local camera
  Future<void> toggleCamera() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isCameraEnabled();
    await _room!.localParticipant!.setCameraEnabled(!isEnabled);
  }

  /// Toggle screen share
  Future<void> toggleScreenShare() async {
    if (_room == null || _room!.localParticipant == null) return;
    final isEnabled = _room!.localParticipant!.isScreenShareEnabled();
    await _room!.localParticipant!.setScreenShareEnabled(!isEnabled);
  }

  /// Toggle deafen mode (mute/unmute incoming audio from all remote participants)
  Future<void> toggleDeafen() async {
    if (_room == null) return;
    _isDeafened = !_isDeafened;
    for (final participant in _room!.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        await publication.setSubscribed(!_isDeafened);
      }
    }
  }

  Future<void> disconnect() async {
    _listener?.dispose();
    _listener = null;
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
  }
}
