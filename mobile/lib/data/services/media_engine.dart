import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Serial task runner (Mutex lock) to guarantee that media lifecycle operations
/// execute sequentially without race conditions.
class MediaLock {
  Future<void>? _lastOperation;

  Future<T> run<T>(Future<T> Function() operation) async {
    final previous = _lastOperation;
    final completer = Completer<void>();
    _lastOperation = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // Ignore previous errors in queue so next task can run
      }
    }

    try {
      final result = await operation();
      return result;
    } finally {
      completer.complete();
    }
  }
}

/// Production-Grade Media Lifecycle Engine using flutter_webrtc.
///
/// Handles microphone, camera, and Android 14+ Screen Capture Foreground Service (FGS).
class MediaEngine {
  final MediaLock _lock = MediaLock();
  static const _screenCaptureChannel =
      MethodChannel('tech.focko.flicko/screen_capture');

  RTCVideoRenderer? _localRenderer;
  MediaStream? _localStream;
  MediaStream? _screenStream;

  bool _isScreenServiceRunning = false;
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = true;

  MediaLock get lock => _lock;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  MediaStream? get localStream => _localStream;
  MediaStream? get screenStream => _screenStream;

  Future<void> initLocalMedia() async {
    return _lock.run(() async {
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }

      if (_localStream == null) {
        try {
          final mediaConstraints = <String, dynamic>{
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': false,
          };
          _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
          _isMicrophoneEnabled = true;
          _isCameraEnabled = false;
        } catch (e) {
          developer.log('[MediaEngine] Error initializing audio stream: $e', name: 'MediaEngine');
        }
      }
    });
  }

  /// Safely toggles local camera stream.
  Future<bool> setCameraEnabled(bool enabled) {
    return _lock.run(() async {
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }

      if (!enabled) {
        developer.log('[MediaEngine] Disabling camera...', name: 'MediaEngine');
        if (_localStream != null) {
          for (final track in _localStream!.getVideoTracks()) {
            track.enabled = false;
            await track.stop();
            _localStream!.removeTrack(track);
          }
        }
        _localRenderer?.srcObject = null;
        _isCameraEnabled = false;
        return false;
      }

      developer.log('[MediaEngine] Enabling camera...', name: 'MediaEngine');
      try {
        final videoConstraints = <String, dynamic>{
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 720},
            'height': {'ideal': 1280},
          },
        };
        final videoStream = await navigator.mediaDevices.getUserMedia(videoConstraints);
        if (_localStream == null) {
          _localStream = videoStream;
        } else {
          for (final track in videoStream.getVideoTracks()) {
            _localStream!.addTrack(track);
          }
        }
        _localRenderer?.srcObject = _localStream;
        _isCameraEnabled = true;
        return true;
      } catch (e) {
        developer.log('[MediaEngine] Failed to enable camera: $e', name: 'MediaEngine', error: e);
        _isCameraEnabled = false;
        return false;
      }
    });
  }

  /// Safely toggles local screen share stream.
  ///
  /// CRITICAL Android 14+ (API 34) FGS Timing:
  /// The MediaProjection foreground service MUST be started AFTER the user
  /// grants consent.
  Future<bool> setScreenShareEnabled(bool enabled) {
    return _lock.run(() async {
      if (enabled) {
        developer.log('[MediaEngine] Starting screen share process...', name: 'MediaEngine');
        if (Platform.isAndroid) {
          try {
            developer.log('[MediaEngine] Starting Android Screen Capture FGS...', name: 'MediaEngine');
            await _screenCaptureChannel.invokeMethod('startService');
            _isScreenServiceRunning = true;
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            developer.log('[MediaEngine] Failed to start screen capture service: $e', name: 'MediaEngine', error: e);
          }
        }

        try {
          final stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': true,
            'audio': false,
          });
          _screenStream = stream;
          _isScreenServiceRunning = Platform.isAndroid;
          return true;
        } catch (e) {
          developer.log('[MediaEngine] Failed to capture display media: $e', name: 'MediaEngine', error: e);
          if (Platform.isAndroid) {
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
            } catch (_) {}
            _isScreenServiceRunning = false;
          }
          return false;
        }
      } else {
        developer.log('[MediaEngine] Stopping screen share process...', name: 'MediaEngine');
        try {
          if (_screenStream != null) {
            for (final track in _screenStream!.getTracks()) {
              await track.stop();
            }
            await _screenStream!.dispose();
            _screenStream = null;
          }
        } catch (e) {
          developer.log('[MediaEngine] Error stopping screen share: $e', name: 'MediaEngine', error: e);
        } finally {
          if (Platform.isAndroid && _isScreenServiceRunning) {
            await Future.delayed(const Duration(milliseconds: 400));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
            } catch (e) {
              developer.log('[MediaEngine] Failed to stop screen service: $e', name: 'MediaEngine');
            }
            _isScreenServiceRunning = false;
          }
        }
        return false;
      }
    });
  }

  /// Safely toggles local microphone mute state.
  Future<bool> setMicrophoneMuted(bool muted) {
    return _lock.run(() async {
      _isMicrophoneEnabled = !muted;
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          track.enabled = _isMicrophoneEnabled;
        }
      }
      return _isMicrophoneEnabled;
    });
  }

  /// Sets deafened mode
  Future<void> setDeafened(bool deafened) {
    return _lock.run(() async {
      try {
        await Helper.setSpeakerphoneOn(!deafened);
      } catch (e) {
        developer.log('[MediaEngine] Error setting deafen audio state: $e', name: 'MediaEngine');
      }
    });
  }

  /// Safely stops foreground services and releases streams on room disconnect.
  Future<void> disposeRoomMedia() {
    return _lock.run(() async {
      developer.log('[MediaEngine] Cleaning up media background services on room disconnect...', name: 'MediaEngine');
      if (Platform.isAndroid && _isScreenServiceRunning) {
        try {
          await _screenCaptureChannel.invokeMethod('stopService');
        } catch (_) {}
        _isScreenServiceRunning = false;
      }

      if (_screenStream != null) {
        for (final track in _screenStream!.getTracks()) {
          await track.stop();
        }
        await _screenStream!.dispose();
        _screenStream = null;
      }

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      _localRenderer?.srcObject = null;
    });
  }

  Future<void> dispose() async {
    await disposeRoomMedia();
    await _localRenderer?.dispose();
    _localRenderer = null;
  }
}
