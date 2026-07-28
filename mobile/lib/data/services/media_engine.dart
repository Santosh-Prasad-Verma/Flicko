import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

/// Serial task runner (Mutex lock) to guarantee that media lifecycle operations
/// (camera toggles, screen share toggles, track publishing/unpublishing, room joins)
/// execute sequentially without race conditions or overlapping WebRTC SDP renegotiations.
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

/// Robust Media Lifecycle Engine for LiveKit & WebRTC.
///
/// Ensures:
/// 1. Only ONE media operation modifies room/track state at a time.
/// 2. Camera hardware HAL errors on Android do not crash PeerConnection signaling.
/// 3. Android Foreground Service for screen sharing starts BEFORE MediaProjection dialog.
/// 4. All tracks, capturers, and services are released deterministically exactly once.
class MediaEngine {
  final MediaLock _lock = MediaLock();
  static const _screenCaptureChannel =
      MethodChannel('tech.focko.flicko/screen_capture');

  bool _isScreenServiceRunning = false;

  MediaLock get lock => _lock;

  /// Safely toggles local camera stream on a LiveKit [Room].
  Future<bool> setCameraEnabled(
    Room room,
    bool enabled, {
    CameraCaptureOptions? cameraCaptureOptions,
  }) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        developer.log('setCameraEnabled: localParticipant is null', name: 'MediaEngine');
        return false;
      }

      final currentlyEnabled = localParticipant.isCameraEnabled();
      if (currentlyEnabled == enabled) {
        developer.log('setCameraEnabled: camera is already ${enabled ? "enabled" : "disabled"}', name: 'MediaEngine');
        return enabled;
      }

      if (!enabled) {
        developer.log('Disabling camera track...', name: 'MediaEngine');
        try {
          await localParticipant.setCameraEnabled(false);
          developer.log('Camera track disabled successfully', name: 'MediaEngine');
          return false;
        } catch (e) {
          developer.log('Error disabling camera track: $e', name: 'MediaEngine', error: e);
          rethrow;
        }
      }

      // Enabling Camera
      developer.log('Enabling camera track...', name: 'MediaEngine');
      final primaryOptions = cameraCaptureOptions ??
          const CameraCaptureOptions(
            params: VideoParametersPresets.h540_169,
            maxFrameRate: 30,
          );

      try {
        await localParticipant.setCameraEnabled(
          true,
          cameraCaptureOptions: primaryOptions,
        );
        developer.log('Camera track enabled successfully (540p)', name: 'MediaEngine');
        return true;
      } catch (primaryError) {
        developer.log(
          'Primary camera publish failed: $primaryError. Attempting 360p fallback after HAL settle...',
          name: 'MediaEngine',
          error: primaryError,
        );

        // Allow Android Camera2 HAL time to settle if session reset occurred
        await Future.delayed(const Duration(milliseconds: 400));

        try {
          await localParticipant.setCameraEnabled(
            true,
            cameraCaptureOptions: const CameraCaptureOptions(
              params: VideoParametersPresets.h360_169,
              maxFrameRate: 24,
            ),
          );
          developer.log('Camera track enabled successfully (360p fallback)', name: 'MediaEngine');
          return true;
        } catch (fallbackError) {
          developer.log('Fallback camera publish failed: $fallbackError', name: 'MediaEngine', error: fallbackError);
          // Ensure state is clean
          try {
            await localParticipant.setCameraEnabled(false);
          } catch (_) {}
          throw TrackPublishException('Failed to publish camera track: $fallbackError');
        }
      }
    });
  }

  /// Safely toggles local screen share stream on a LiveKit [Room].
  Future<bool> setScreenShareEnabled(Room room, bool enabled) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        developer.log('setScreenShareEnabled: localParticipant is null', name: 'MediaEngine');
        return false;
      }

      final currentlyEnabled = localParticipant.isScreenShareEnabled();
      if (currentlyEnabled == enabled) {
        developer.log('setScreenShareEnabled: screen share is already ${enabled ? "enabled" : "disabled"}', name: 'MediaEngine');
        return enabled;
      }

      if (enabled) {
        developer.log('Starting screen share process...', name: 'MediaEngine');
        if (Platform.isAndroid) {
          try {
            developer.log('Starting Android Foreground Service for MediaProjection...', name: 'MediaEngine');
            await _screenCaptureChannel.invokeMethod('startService');
            _isScreenServiceRunning = true;
            // Wait for OS to bind foreground service
            await Future.delayed(const Duration(milliseconds: 350));
          } catch (e) {
            developer.log('Failed to start Screen Capture Service: $e', name: 'MediaEngine', error: e);
          }
        }

        try {
          await localParticipant.setScreenShareEnabled(true);
          developer.log('Screen share enabled successfully', name: 'MediaEngine');
          return true;
        } catch (e) {
          developer.log('Failed to enable screen share: $e', name: 'MediaEngine', error: e);
          // Teardown service on failure
          if (Platform.isAndroid && _isScreenServiceRunning) {
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
            } catch (_) {}
            _isScreenServiceRunning = false;
          }
          rethrow;
        }
      } else {
        developer.log('Stopping screen share process...', name: 'MediaEngine');
        try {
          await localParticipant.setScreenShareEnabled(false);
          developer.log('Screen share disabled successfully', name: 'MediaEngine');
        } catch (e) {
          developer.log('Error while disabling screen share: $e', name: 'MediaEngine', error: e);
        } finally {
          if (Platform.isAndroid && _isScreenServiceRunning) {
            // Delay service stop until capturer completes native teardown
            await Future.delayed(const Duration(milliseconds: 400));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
              developer.log('Screen Capture Service stopped', name: 'MediaEngine');
            } catch (e) {
              developer.log('Failed to stop Screen Capture Service: $e', name: 'MediaEngine', error: e);
            }
            _isScreenServiceRunning = false;
          }
        }
        return false;
      }
    });
  }

  /// Safely toggles local microphone stream on a LiveKit [Room].
  Future<bool> setMicrophoneEnabled(
    Room room,
    bool enabled, {
    AudioCaptureOptions? audioCaptureOptions,
  }) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) return false;

      const defaultAudioOptions = AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        typingNoiseDetection: true,
      );

      final options = audioCaptureOptions ?? defaultAudioOptions;
      await localParticipant.setMicrophoneEnabled(enabled, audioCaptureOptions: options);
      return localParticipant.isMicrophoneEnabled();
    });
  }

  /// Safely stops all media tracks and services on room disconnect.
  Future<void> disposeRoomMedia(Room? room) {
    return _lock.run(() async {
      if (room == null) return;
      developer.log('Disposing room media tracks cleanly...', name: 'MediaEngine');
      try {
        final localParticipant = room.localParticipant;
        if (localParticipant != null) {
          if (localParticipant.isScreenShareEnabled()) {
            try { await localParticipant.setScreenShareEnabled(false); } catch (_) {}
          }
          if (localParticipant.isCameraEnabled()) {
            try { await localParticipant.setCameraEnabled(false); } catch (_) {}
          }
          if (localParticipant.isMicrophoneEnabled()) {
            try { await localParticipant.setMicrophoneEnabled(false); } catch (_) {}
          }
        }
      } catch (e) {
        developer.log('Error during room media disposal: $e', name: 'MediaEngine', error: e);
      } finally {
        if (Platform.isAndroid && _isScreenServiceRunning) {
          try { await _screenCaptureChannel.invokeMethod('stopService'); } catch (_) {}
          _isScreenServiceRunning = false;
        }
      }
    });
  }
}
