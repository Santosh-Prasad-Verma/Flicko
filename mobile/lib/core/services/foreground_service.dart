import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for ForegroundService
final foregroundServiceProvider = Provider<ForegroundService>((ref) {
  return ForegroundService();
});

/// Foreground task handler
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceCallTaskHandler());
}

/// Voice Call Task Handler
/// 
/// Handles the foreground task execution for voice calls.
/// Keeps the app alive in background and manages call state.
class VoiceCallTaskHandler extends TaskHandler {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isMuted = false;
  bool _isDeafened = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Update notification every second to show call duration
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _updateNotification();
    });

    // Notify main isolate
    FlutterForegroundTask.sendDataToMain({
      'type': 'call_started',
      'timestamp': timestamp.toIso8601String(),
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Periodic events can be handled here
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();

    // Notify main isolate
    FlutterForegroundTask.sendDataToMain({
      'type': 'call_ended',
      'duration': _elapsedSeconds,
      'killed_by_system': isTimeout,
    });
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button presses
    switch (id) {
      case 'mute':
        _isMuted = !_isMuted;
        FlutterForegroundTask.sendDataToMain({
          'type': 'mute_toggled',
          'is_muted': _isMuted,
        });
        break;
      case 'deafen':
        _isDeafened = !_isDeafened;
        FlutterForegroundTask.sendDataToMain({
          'type': 'deafen_toggled',
          'is_deafened': _isDeafened,
        });
        break;
      case 'disconnect':
        FlutterForegroundTask.sendDataToMain({
          'type': 'disconnect_pressed',
        });
        break;
    }
  }

  @override
  void onNotificationPressed() {
    // Bring app to foreground
    FlutterForegroundTask.sendDataToMain({
      'type': 'notification_pressed',
    });
    FlutterForegroundTask.launchApp('/voice-call');
  }

  void _updateNotification() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    final duration = '$minutes:$seconds';

    String subtitle = 'Duration: $duration';
    if (_isMuted) subtitle += ' | Muted';
    if (_isDeafened) subtitle += ' | Deafened';

    FlutterForegroundTask.updateService(
      notificationTitle: 'Voice Call in Progress',
      notificationText: subtitle,
    );
  }
}

/// Foreground Service
/// 
/// Manages foreground tasks for voice calls to keep the app alive:
/// - Start/stop foreground service
/// - Handle call duration tracking
/// - Manage mute/deafen states
/// - Handle notification actions
/// - Communicate between main isolate and foreground task
class ForegroundService {
  bool _initialized = false;
  bool _isRunning = false;

  // Callbacks
  void Function(Duration duration)? onDurationUpdate;
  void Function(bool isMuted)? onMuteToggled;
  void Function(bool isDeafened)? onDeafenToggled;
  void Function()? onDisconnectPressed;
  void Function()? onNotificationPressed;
  void Function(bool killedBySystem)? onCallEnded;

  /// Initialize the foreground service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permissions
      await FlutterForegroundTask.requestNotificationPermission();
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_handleMessageFromTask);
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'voice_call_service',
          channelName: 'Voice Calls',
          channelDescription: 'Keeps Flicko voice calls connected in the background',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(1000),
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      _initialized = true;
      debugPrint('✅ ForegroundService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing ForegroundService: $e');
    }
  }

  /// Start foreground service for voice call
  Future<bool> startVoiceCallService({
    required String channelName,
    required String serverName,
    void Function(Duration duration)? onDurationUpdate,
    void Function(bool isMuted)? onMuteToggled,
    void Function(bool isDeafened)? onDeafenToggled,
    void Function()? onDisconnectPressed,
    void Function()? onNotificationPressed,
    void Function(bool killedBySystem)? onCallEnded,
  }) async {
    if (!_initialized) await initialize();
    if (_isRunning) return true;

    try {
      // Set up callbacks
      this.onDurationUpdate = onDurationUpdate;
      this.onMuteToggled = onMuteToggled;
      this.onDeafenToggled = onDeafenToggled;
      this.onDisconnectPressed = onDisconnectPressed;
      this.onNotificationPressed = onNotificationPressed;
      this.onCallEnded = onCallEnded;

      // Start foreground task
      final result = await FlutterForegroundTask.startService(
        serviceId: 256, // Unique service ID
        notificationTitle: 'Voice Call in Progress',
        notificationText: 'In $channelName on $serverName',
        notificationIcon: const NotificationIcon(
          metaDataName: 'app.icon',
        ),
        notificationButtons: [
          const NotificationButton(
            id: 'mute',
            text: 'Mute',
          ),
          const NotificationButton(
            id: 'deafen',
            text: 'Deafen',
          ),
          const NotificationButton(
            id: 'disconnect',
            text: 'Disconnect',
          ),
        ],
        callback: startCallback,
      );

      if (result is ServiceRequestSuccess) {
        _isRunning = true;
        debugPrint('✅ Voice call foreground service started');
      }

      return _isRunning;
    } catch (e) {
      debugPrint('❌ Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop foreground service
  Future<bool> stopVoiceCallService() async {
    if (!_isRunning) return true;

    try {
      final result = await FlutterForegroundTask.stopService();
      
      if (result is ServiceRequestSuccess) {
        _isRunning = false;
        debugPrint('🛑 Voice call foreground service stopped');
      }

      return _isRunning == false;
    } catch (e) {
      debugPrint('❌ Error stopping foreground service: $e');
      return false;
    }
  }

  /// Handle messages from foreground task
  void _handleMessageFromTask(dynamic message) {
    if (message is! Map<String, dynamic>) return;

    final type = message['type'] as String?;

    switch (type) {
      case 'call_started':
        debugPrint('📞 Call started in foreground task');
        break;
      case 'call_ended':
        final duration = message['duration'] as int? ?? 0;
        final killedBySystem = message['killed_by_system'] as bool? ?? false;
        onCallEnded?.call(killedBySystem);
        debugPrint('📞 Call ended. Duration: ${Duration(seconds: duration)}');
        break;
      case 'mute_toggled':
        final isMuted = message['is_muted'] as bool? ?? false;
        onMuteToggled?.call(isMuted);
        break;
      case 'deafen_toggled':
        final isDeafened = message['is_deafened'] as bool? ?? false;
        onDeafenToggled?.call(isDeafened);
        break;
      case 'disconnect_pressed':
        onDisconnectPressed?.call();
        break;
      case 'notification_pressed':
        onNotificationPressed?.call();
        break;
    }
  }

  /// Update notification text
  Future<void> updateNotification({
    String? title,
    String? text,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Send data to foreground task
  Future<void> sendDataToTask(Map<String, dynamic> data) async {
    if (!_isRunning) return;
    
    FlutterForegroundTask.sendDataToTask(data);
  }

  /// Save data that persists between foreground task restarts
  static Future<void> saveData(String key, dynamic value) async {
    await FlutterForegroundTask.saveData(key: key, value: value);
  }

  /// Get saved data
  static Future<dynamic> getData(String key) async {
    return await FlutterForegroundTask.getData(key: key);
  }

  /// Remove saved data
  static Future<void> removeData(String key) async {
    await FlutterForegroundTask.removeData(key: key);
  }

  /// Clear all saved data
  static Future<void> clearAllData() async {
    await FlutterForegroundTask.clearAllData();
  }

  /// Wake up screen (for incoming calls)
  static Future<void> wakeUpScreen() async {
    FlutterForegroundTask.wakeUpScreen();
  }

  /// Check if app is in foreground
  static Future<bool> isAppInForeground() async {
    return await FlutterForegroundTask.isAppOnForeground;
  }

  /// Minimize app to background
  static Future<void> minimizeApp() async {
    FlutterForegroundTask.minimizeApp();
  }

  /// Launch app with route
  static Future<void> launchApp([String? route]) async {
    FlutterForegroundTask.launchApp(route);
  }

  /// Set ignore battery optimization (Android)
  static Future<bool> setIgnoreBatteryOptimization() async {
    return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  /// Check if battery optimization is ignored
  static Future<bool> get isIgnoringBatteryOptimization async {
    return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
  }

  /// Dispose resources
  void dispose() {
    stopVoiceCallService();
    FlutterForegroundTask.removeTaskDataCallback(_handleMessageFromTask);
  }
}

/// Foreground service configuration
class ForegroundServiceConfig {
  final String channelName;
  final String serverName;
  final String? callerName;
  final bool isVideoCall;
  final Duration? maxDuration;

  ForegroundServiceConfig({
    required this.channelName,
    required this.serverName,
    this.callerName,
    this.isVideoCall = false,
    this.maxDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'channel_name': channelName,
      'server_name': serverName,
      'caller_name': callerName,
      'is_video_call': isVideoCall,
      'max_duration': maxDuration?.inSeconds,
    };
  }
}

/// Call state for foreground service
class ForegroundCallState {
  final bool isRunning;
  final Duration duration;
  final bool isMuted;
  final bool isDeafened;
  final String channelName;
  final String serverName;

  ForegroundCallState({
    required this.isRunning,
    required this.duration,
    required this.isMuted,
    required this.isDeafened,
    required this.channelName,
    required this.serverName,
  });

  factory ForegroundCallState.initial() {
    return ForegroundCallState(
      isRunning: false,
      duration: Duration.zero,
      isMuted: false,
      isDeafened: false,
      channelName: '',
      serverName: '',
    );
  }

  ForegroundCallState copyWith({
    bool? isRunning,
    Duration? duration,
    bool? isMuted,
    bool? isDeafened,
    String? channelName,
    String? serverName,
  }) {
    return ForegroundCallState(
      isRunning: isRunning ?? this.isRunning,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      channelName: channelName ?? this.channelName,
      serverName: serverName ?? this.serverName,
    );
  }
}
