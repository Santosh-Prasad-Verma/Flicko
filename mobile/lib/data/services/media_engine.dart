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

/// Robust, Production-Grade Media Lifecycle Engine for LiveKit & WebRTC.
///
/// Guaranteed Guarantees:
/// 1. Only ONE camera capturer exists at any time during the room session.
/// 2. Clean single-disposal: Partial/failed track creations are immediately un-published & stopped.
/// 3. Serialized execution via [MediaLock]: Prevents concurrent SDP offer/answer collisions.
/// 4. Android Camera2 HAL isolation: Screen sharing NEVER touches or recreates camera tracks.
/// 5. Full lifecycle logging for auditability.
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
        developer.log('[MediaEngine] setCameraEnabled: localParticipant is null', name: 'MediaEngine');
        return false;
      }

      final currentlyEnabled = localParticipant.isCameraEnabled();
      developer.log(
        '[MediaEngine] setCameraEnabled requested: target=$enabled, currentlyEnabled=$currentlyEnabled',
        name: 'MediaEngine',
      );

      if (currentlyEnabled == enabled) {
        developer.log(
          '[MediaEngine] setCameraEnabled: camera is already ${enabled ? "enabled" : "disabled"}',
          name: 'MediaEngine',
        );
        return enabled;
      }

      if (!enabled) {
        developer.log('[MediaEngine] Disabling camera track...', name: 'MediaEngine');
        try {
          await localParticipant.setCameraEnabled(false);
          developer.log('[MediaEngine] Camera track disabled and disposed cleanly', name: 'MediaEngine');
          return false;
        } catch (e) {
          developer.log('[MediaEngine] Error disabling camera track: $e', name: 'MediaEngine', error: e);
          rethrow;
        }
      }

      // ENABLING CAMERA:
      // CRITICAL FIX FOR DOUBLE-CAMERA CREATION:
      // Ensure any existing camera track is completely stopped and disposed first
      // before attempting to instantiate a new Camera2Capturer.
      try {
        developer.log('[MediaEngine] Pre-cleaning existing camera tracks prior to enable...', name: 'MediaEngine');
        await localParticipant.setCameraEnabled(false);
      } catch (e) {
        developer.log('[MediaEngine] Pre-clean setCameraEnabled(false) ignored: $e', name: 'MediaEngine');
      }

      // Settle HAL before opening new CameraCaptureSession
      await Future.delayed(const Duration(milliseconds: 150));

      developer.log('[MediaEngine] Creating & Publishing Camera Track (Primary 540p)...', name: 'MediaEngine');
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
        developer.log('[MediaEngine] Camera track created & published successfully (540p)', name: 'MediaEngine');
        return true;
      } catch (primaryError) {
        developer.log(
          '[MediaEngine] Primary camera publish failed: $primaryError. Unwinding partial track...',
          name: 'MediaEngine',
          error: primaryError,
        );

        // MANDATORY: Unwind the partial track creation in LiveKit!
        // Calling setCameraEnabled(false) stops the orphaned Camera2Capturer #1
        // so that it does NOT linger when attempting 360p fallback!
        try {
          await localParticipant.setCameraEnabled(false);
          developer.log('[MediaEngine] Cleanly stopped failed primary camera capturer', name: 'MediaEngine');
        } catch (unwindErr) {
          developer.log('[MediaEngine] Error unwinding failed primary camera track: $unwindErr', name: 'MediaEngine');
        }

        // Allow Android Camera2 HAL time to completely release hardware lock
        developer.log('[MediaEngine] Waiting 500ms for Camera2 HAL to settle...', name: 'MediaEngine');
        await Future.delayed(const Duration(milliseconds: 500));

        developer.log('[MediaEngine] Creating & Publishing Camera Track (Fallback 360p)...', name: 'MediaEngine');
        try {
          await localParticipant.setCameraEnabled(
            true,
            cameraCaptureOptions: const CameraCaptureOptions(
              params: VideoParametersPresets.h360_169,
              maxFrameRate: 24,
            ),
          );
          developer.log('[MediaEngine] Camera track created & published successfully (360p fallback)', name: 'MediaEngine');
          return true;
        } catch (fallbackError) {
          developer.log(
            '[MediaEngine] Fallback camera publish failed: $fallbackError. Unwinding fallback track...',
            name: 'MediaEngine',
            error: fallbackError,
          );

          // Clean up lingering fallback capturer
          try {
            await localParticipant.setCameraEnabled(false);
          } catch (_) {}

          throw TrackPublishException('Failed to publish camera track: $fallbackError');
        }
      }
    });
  }

  /// Safely toggles local screen share stream on a LiveKit [Room].
  ///
  /// CRITICAL: Screen Share lifecycle is COMPLETELY ISOLATED from Camera lifecycle.
  /// Starting or stopping screen share NEVER touches or recreates camera tracks.
  Future<bool> setScreenShareEnabled(Room room, bool enabled) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        developer.log('[MediaEngine] setScreenShareEnabled: localParticipant is null', name: 'MediaEngine');
        return false;
      }

      final currentlyEnabled = localParticipant.isScreenShareEnabled();
      developer.log(
        '[MediaEngine] setScreenShareEnabled requested: target=$enabled, currentlyEnabled=$currentlyEnabled',
        name: 'MediaEngine',
      );

      if (currentlyEnabled == enabled) {
        developer.log(
          '[MediaEngine] setScreenShareEnabled: screen share is already ${enabled ? "enabled" : "disabled"}',
          name: 'MediaEngine',
        );
        return enabled;
      }

      if (enabled) {
        developer.log('[MediaEngine] Starting screen share process...', name: 'MediaEngine');
        if (Platform.isAndroid) {
          try {
            developer.log('[MediaEngine] Invoking Android Foreground Service for MediaProjection...', name: 'MediaEngine');
            await _screenCaptureChannel.invokeMethod('startService');
            _isScreenServiceRunning = true;
            developer.log('[MediaEngine] Android Foreground Service started successfully', name: 'MediaEngine');
            // Wait for OS foreground service binding to stabilize before MediaProjection request
            await Future.delayed(const Duration(milliseconds: 350));
          } catch (e) {
            developer.log('[MediaEngine] Failed to start Screen Capture Service: $e', name: 'MediaEngine', error: e);
          }
        }

        try {
          developer.log('[MediaEngine] Publishing Screen Share Track to LiveKit Room...', name: 'MediaEngine');
          await localParticipant.setScreenShareEnabled(true);
          developer.log('[MediaEngine] Screen share track published successfully', name: 'MediaEngine');
          return true;
        } catch (e) {
          developer.log('[MediaEngine] Failed to publish screen share track: $e', name: 'MediaEngine', error: e);
          // Clean up service on publication error
          if (Platform.isAndroid && _isScreenServiceRunning) {
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
              developer.log('[MediaEngine] Stopped Screen Capture Service after publish failure', name: 'MediaEngine');
            } catch (_) {}
            _isScreenServiceRunning = false;
          }
          rethrow;
        }
      } else {
        developer.log('[MediaEngine] Stopping screen share process...', name: 'MediaEngine');
        try {
          await localParticipant.setScreenShareEnabled(false);
          developer.log('[MediaEngine] Screen share track unpublished successfully', name: 'MediaEngine');
        } catch (e) {
          developer.log('[MediaEngine] Error while unpublishing screen share track: $e', name: 'MediaEngine', error: e);
        } finally {
          if (Platform.isAndroid && _isScreenServiceRunning) {
            // Delay service teardown until native capturer releases MediaProjection
            await Future.delayed(const Duration(milliseconds: 400));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
              developer.log('[MediaEngine] Android Screen Capture Service stopped successfully', name: 'MediaEngine');
            } catch (e) {
              developer.log('[MediaEngine] Failed to stop Screen Capture Service: $e', name: 'MediaEngine', error: e);
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
      if (localParticipant == null) {
        developer.log('[MediaEngine] setMicrophoneEnabled: localParticipant is null', name: 'MediaEngine');
        return false;
      }

      developer.log(
        '[MediaEngine] setMicrophoneEnabled requested: target=$enabled',
        name: 'MediaEngine',
      );

      const defaultAudioOptions = AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        typingNoiseDetection: true,
      );

      final options = audioCaptureOptions ?? defaultAudioOptions;
      await localParticipant.setMicrophoneEnabled(enabled, audioCaptureOptions: options);
      final isEnabled = localParticipant.isMicrophoneEnabled();
      developer.log(
        '[MediaEngine] Microphone track state updated: isEnabled=$isEnabled',
        name: 'MediaEngine',
      );
      return isEnabled;
    });
  }

  /// Safely stops all media tracks and services on room disconnect.
  Future<void> disposeRoomMedia(Room? room) {
    return _lock.run(() async {
      if (room == null) return;
      developer.log('[MediaEngine] Disposing all room media tracks deterministically...', name: 'MediaEngine');
      try {
        final localParticipant = room.localParticipant;
        if (localParticipant != null) {
          if (localParticipant.isScreenShareEnabled()) {
            developer.log('[MediaEngine] Disposing screen share track...', name: 'MediaEngine');
            try { await localParticipant.setScreenShareEnabled(false); } catch (e) {
              developer.log('[MediaEngine] Screen share disposal error: $e', name: 'MediaEngine');
            }
          }
          if (localParticipant.isCameraEnabled()) {
            developer.log('[MediaEngine] Disposing camera track...', name: 'MediaEngine');
            try { await localParticipant.setCameraEnabled(false); } catch (e) {
              developer.log('[MediaEngine] Camera track disposal error: $e', name: 'MediaEngine');
            }
          }
          if (localParticipant.isMicrophoneEnabled()) {
            developer.log('[MediaEngine] Disposing microphone track...', name: 'MediaEngine');
            try { await localParticipant.setMicrophoneEnabled(false); } catch (e) {
              developer.log('[MediaEngine] Microphone track disposal error: $e', name: 'MediaEngine');
            }
          }
        }
      } catch (e) {
        developer.log('[MediaEngine] Error during room media disposal: $e', name: 'MediaEngine', error: e);
      } finally {
        if (Platform.isAndroid && _isScreenServiceRunning) {
          try {
            await _screenCaptureChannel.invokeMethod('stopService');
            developer.log('[MediaEngine] Screen Capture Service stopped during room media disposal', name: 'MediaEngine');
          } catch (_) {}
          _isScreenServiceRunning = false;
        }
      }
    });
  }
}

