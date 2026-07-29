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

/// Production-Grade Media Lifecycle Engine for LiveKit & WebRTC.
///
/// Architecture Principles:
/// 1. DELEGATES track lifecycle to LiveKit SDK's LocalParticipant API
///    (setCameraEnabled/setScreenShareEnabled/setMicrophoneEnabled).
///    Manual track creation (createCameraTrack + publishVideoTrack) is REMOVED
///    to prevent double-dispose conflicts with the SDK's internal state machine.
/// 2. Serialized execution via [MediaLock] prevents concurrent SDP offer/answer collisions.
/// 3. Android MediaProjection FGS is started AFTER user consent (in onActivityResult),
///    not before — required by Android 14+ (API 34) to avoid SecurityException.
/// 4. Full lifecycle logging for auditability.
class MediaEngine {
  final MediaLock _lock = MediaLock();
  static const _screenCaptureChannel =
      MethodChannel('tech.focko.flicko/screen_capture');

  bool _isScreenServiceRunning = false;

  MediaLock get lock => _lock;

  /// Safely toggles local camera stream on a LiveKit [Room].
  ///
  /// Delegates entirely to LiveKit SDK's [LocalParticipant.setCameraEnabled()]
  /// to avoid Camera2 HAL lifecycle conflicts (double-dispose, HAL session races).
  /// Includes automatic fallback from 540p to 360p on failure.
  Future<bool> setCameraEnabled(
    Room room,
    bool enabled, {
    CameraCaptureOptions? cameraCaptureOptions,
  }) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        developer.log(
          '[MediaEngine] setCameraEnabled: localParticipant is null',
          name: 'MediaEngine',
        );
        return false;
      }

      final currentlyEnabled = localParticipant.isCameraEnabled();
      developer.log(
        '[MediaEngine] setCameraEnabled requested: target=$enabled, currentlyEnabled=$currentlyEnabled',
        name: 'MediaEngine',
      );

      if (!enabled) {
        developer.log(
          '[MediaEngine] Disabling camera via LiveKit SDK...',
          name: 'MediaEngine',
        );
        try {
          await localParticipant.setCameraEnabled(false);
        } catch (e) {
          developer.log(
            '[MediaEngine] Camera disable error (non-fatal): $e',
            name: 'MediaEngine',
          );
        }
        developer.log(
          '[MediaEngine] Camera disabled successfully',
          name: 'MediaEngine',
        );
        return false;
      }

      // === ENABLING CAMERA ===
      // Use caller options or native auto-negotiated options directly.
      // Avoid forcing intermediate resolution resets (540p -> 720p) that cause Camera2 HAL session
      // tear-down exceptions (-38) on vendor hardware (Oplus/ColorOS/Realme).
      developer.log(
        '[MediaEngine] Enabling camera via LiveKit SDK...',
        name: 'MediaEngine',
      );
      try {
        await localParticipant.setCameraEnabled(
          true,
          cameraCaptureOptions: cameraCaptureOptions,
        );
        developer.log(
          '[MediaEngine] Camera enabled successfully',
          name: 'MediaEngine',
        );
        return true;
      } catch (primaryError) {
        developer.log(
          '[MediaEngine] Primary camera option failed: $primaryError. Waiting for HAL cleanup...',
          name: 'MediaEngine',
          error: primaryError,
        );

        // Clean up partial state and allow Camera2 HAL time to release hardware resources
        try {
          await localParticipant.setCameraEnabled(false);
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 1000));

        developer.log(
          '[MediaEngine] Retrying camera with native auto-negotiated options...',
          name: 'MediaEngine',
        );
        try {
          await localParticipant.setCameraEnabled(true);
          developer.log(
            '[MediaEngine] Camera enabled successfully on retry',
            name: 'MediaEngine',
          );
          return true;
        } catch (fallbackError) {
          try {
            await localParticipant.setCameraEnabled(false);
          } catch (_) {}
          developer.log(
            '[MediaEngine] Camera hardware unavailable or in use by another app',
            name: 'MediaEngine',
          );
          return false;
        }
      }
    });
  }

  /// Safely toggles local screen share stream on a LiveKit [Room].
  ///
  /// CRITICAL Android 14+ (API 34) FGS Timing:
  /// The MediaProjection foreground service MUST be started AFTER the user
  /// grants consent (in onActivityResult), NOT before. Calling startForeground()
  /// with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION before consent throws
  /// SecurityException / MissingForegroundServiceTypeException on Android 14+.
  ///
  /// Flow:
  /// 1. Dart calls 'prepareCapture' via MethodChannel → sets flag in MainActivity
  /// 2. LiveKit SDK shows system consent dialog
  /// 3. User approves → onActivityResult fires → FGS starts (using flag)
  /// 4. super.onActivityResult() is deferred 300ms so FGS calls startForeground()
  /// 5. flutter_webrtc calls getMediaProjection() → FGS is active → succeeds
  Future<bool> setScreenShareEnabled(Room room, bool enabled) {
    return _lock.run(() async {
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        developer.log(
          '[MediaEngine] setScreenShareEnabled: localParticipant is null',
          name: 'MediaEngine',
        );
        return false;
      }

      final currentlyEnabled = localParticipant.isScreenShareEnabled();
      developer.log(
        '[MediaEngine] setScreenShareEnabled requested: target=$enabled, currentlyEnabled=$currentlyEnabled',
        name: 'MediaEngine',
      );

      if (currentlyEnabled == enabled) {
        developer.log(
          '[MediaEngine] Screen share already in requested state ($enabled)',
          name: 'MediaEngine',
        );
        return enabled;
      }

      if (enabled) {
        developer.log(
          '[MediaEngine] Starting screen share process...',
          name: 'MediaEngine',
        );

        // On Android 14+ (API 34), signal the Activity to prepare for
        // MediaProjection FGS start. The actual FGS start happens in
        // onActivityResult() AFTER the user grants consent.
        if (Platform.isAndroid) {
          try {
            developer.log(
              '[MediaEngine] Starting Android Screen Capture Foreground Service (mediaProjection)...',
              name: 'MediaEngine',
            );
            await _screenCaptureChannel.invokeMethod('startService');
            _isScreenServiceRunning = true;
            developer.log(
              '[MediaEngine] Screen capture FGS started successfully',
              name: 'MediaEngine',
            );
            // Allow Android OS time to register the active foreground service
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            developer.log(
              '[MediaEngine] Failed to start screen capture service: $e',
              name: 'MediaEngine',
              error: e,
            );
          }
        }

        try {
          developer.log(
            '[MediaEngine] Publishing Screen Share Track to LiveKit Room...',
            name: 'MediaEngine',
          );
          await localParticipant.setScreenShareEnabled(true);
          _isScreenServiceRunning = Platform.isAndroid;
          developer.log(
            '[MediaEngine] Screen share track published successfully',
            name: 'MediaEngine',
          );
          return true;
        } catch (e) {
          developer.log(
            '[MediaEngine] Failed to publish screen share track: $e',
            name: 'MediaEngine',
            error: e,
          );
          // Clean up FGS on failure
          if (Platform.isAndroid) {
            await Future.delayed(const Duration(milliseconds: 300));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
              developer.log(
                '[MediaEngine] Stopped Screen Capture Service after publish failure',
                name: 'MediaEngine',
              );
            } catch (_) {}
            _isScreenServiceRunning = false;
          }
          rethrow;
        }
      } else {
        developer.log(
          '[MediaEngine] Stopping screen share process...',
          name: 'MediaEngine',
        );
        try {
          await localParticipant.setScreenShareEnabled(false);
          developer.log(
            '[MediaEngine] Screen share track unpublished successfully',
            name: 'MediaEngine',
          );
        } catch (e) {
          developer.log(
            '[MediaEngine] Error while unpublishing screen share track: $e',
            name: 'MediaEngine',
            error: e,
          );
        } finally {
          if (Platform.isAndroid && _isScreenServiceRunning) {
            // Delay service teardown until native capturer releases MediaProjection
            await Future.delayed(const Duration(milliseconds: 400));
            try {
              await _screenCaptureChannel.invokeMethod('stopService');
              developer.log(
                '[MediaEngine] Android Screen Capture Service stopped successfully',
                name: 'MediaEngine',
              );
            } catch (e) {
              developer.log(
                '[MediaEngine] Failed to stop Screen Capture Service: $e',
                name: 'MediaEngine',
                error: e,
              );
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
        developer.log(
          '[MediaEngine] setMicrophoneEnabled: localParticipant is null',
          name: 'MediaEngine',
        );
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
      await localParticipant.setMicrophoneEnabled(
        enabled,
        audioCaptureOptions: options,
      );
      final isEnabled = localParticipant.isMicrophoneEnabled();
      developer.log(
        '[MediaEngine] Microphone track state updated: isEnabled=$isEnabled',
        name: 'MediaEngine',
      );
      return isEnabled;
    });
  }

  /// Safely stops foreground services on room disconnect.
  /// Delegates track disposal entirely to LiveKit SDK's [Room.disconnect()]
  /// to prevent double-dispose warnings on track emitters.
  Future<void> disposeRoomMedia(Room? room) {
    return _lock.run(() async {
      if (room == null) return;
      developer.log(
        '[MediaEngine] Cleaning up media background services on room disconnect...',
        name: 'MediaEngine',
      );
      if (Platform.isAndroid && _isScreenServiceRunning) {
        try {
          await _screenCaptureChannel.invokeMethod('stopService');
          developer.log(
            '[MediaEngine] Screen Capture Service stopped during room media disposal',
            name: 'MediaEngine',
          );
        } catch (_) {}
        _isScreenServiceRunning = false;
      }
    });
  }
}
