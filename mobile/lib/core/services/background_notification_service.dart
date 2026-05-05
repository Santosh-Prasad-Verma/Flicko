import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'push_notification_service.dart';

/// Provider for BackgroundNotificationService
final backgroundNotificationServiceProvider = Provider<BackgroundNotificationService>((ref) {
  return BackgroundNotificationService();
});

/// Background task callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔔 Background task: $task');
    
    switch (task) {
      case 'checkNotifications':
        await _checkPendingNotifications();
        break;
      case 'cleanupOldNotifications':
        await _cleanupOldNotifications();
        break;
      case 'syncUnreadCounts':
        await _syncUnreadCounts();
        break;
    }
    
    return Future.value(true);
  });
}

/// Check for pending notifications in background
Future<void> _checkPendingNotifications() async {
  // This would typically check with your backend or local DB
  // for notifications that need to be displayed
  debugPrint('🔔 Checking pending notifications...');
}

/// Cleanup old notifications
Future<void> _cleanupOldNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  // Cancel notifications older than 7 days
  // In a real app, you'd track notification IDs and timestamps
  debugPrint('🧹 Cleaning up old notifications...');
}

/// Sync unread counts
Future<void> _syncUnreadCounts() async {
  // Sync unread message counts with server
  debugPrint('📊 Syncing unread counts...');
}

/// Background Notification Service
/// 
/// Manages persistent notifications and background tasks:
/// - Scheduled notification checks
/// - Unread count syncing
/// - Old notification cleanup
/// - Background message processing
class BackgroundNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  
  // Background task identifiers
  static const String _checkNotificationsTask = 'checkNotifications';
  static const String _cleanupTask = 'cleanupOldNotifications';
  static const String _syncCountsTask = 'syncUnreadCounts';

  /// Initialize the background notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Workmanager for background tasks
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic tasks
      await _registerBackgroundTasks();

      _initialized = true;
      debugPrint('✅ BackgroundNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundNotificationService: $e');
    }
  }

  /// Register background tasks
  Future<void> _registerBackgroundTasks() async {
    // Check notifications every 15 minutes
    await Workmanager().registerPeriodicTask(
      _checkNotificationsTask,
      _checkNotificationsTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    // Cleanup old notifications daily
    await Workmanager().registerPeriodicTask(
      _cleanupTask,
      _cleanupTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    // Sync unread counts every 30 minutes
    await Workmanager().registerPeriodicTask(
      _syncCountsTask,
      _syncCountsTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    debugPrint('🛑 All background tasks cancelled');
  }

  /// Cancel specific task
  Future<void> cancelTask(String taskName) async {
    await Workmanager().cancelByUniqueName(taskName);
    debugPrint('🛑 Task $taskName cancelled');
  }

  /// Show persistent notification for ongoing call
  Future<void> showOngoingCallNotification({
    required String channelName,
    required String callerName,
    String? callerAvatar,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ongoing_call_channel',
      'Ongoing Calls',
      channelDescription: 'Notifications for ongoing voice/video calls',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          'end_call',
          'End Call',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'mute',
          'Mute',
          showsUserInterface: false,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      999999, // Special ID for ongoing call
      'Ongoing Call',
      'In call with $callerName in $channelName',
      details,
      payload: jsonEncode({
        'type': 'ongoing_call',
        'channel_name': channelName,
        'caller_name': callerName,
      }),
    );
  }

  /// Remove ongoing call notification
  Future<void> removeOngoingCallNotification() async {
    await _notifications.cancel(999999);
  }

  /// Show summary notification for multiple unread messages
  Future<void> showSummaryNotification({
    required int unreadCount,
    required Map<String, int> serverUnreadCounts,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'summary_channel',
      'Message Summary',
      channelDescription: 'Summary of unread messages',
      importance: Importance.low,
      priority: Priority.low,
      groupKey: 'flicko_messages',
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation(
        [],
        contentTitle: '$unreadCount new messages',
        summaryText: 'Flicko',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: unreadCount > 0,
      presentBadge: true,
      presentSound: false,
      badgeNumber: unreadCount,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      0, // ID 0 for summary
      '$unreadCount new messages',
      'You have unread messages',
      details,
    );
  }

  /// Show notification for mention
  Future<void> showMentionNotification({
    required String serverName,
    required String channelName,
    required String senderName,
    required String messageContent,
    required String serverId,
    required String channelId,
    String? messageId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mentions_channel',
      'Mentions',
      channelDescription: 'Notifications when you are mentioned',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$senderName mentioned you in #$channelName',
      messageContent.length > 100 
          ? '${messageContent.substring(0, 100)}...' 
          : messageContent,
      details,
      payload: jsonEncode({
        'type': 'mention',
        'server_id': serverId,
        'channel_id': channelId,
        'message_id': messageId,
      }),
    );
  }

  /// Show notification for direct message
  Future<void> showDirectMessageNotification({
    required String senderName,
    required String messageContent,
    required String senderId,
    String? messageId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dm_channel',
      'Direct Messages',
      channelDescription: 'Notifications for direct messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      senderName,
      messageContent.length > 100 
          ? '${messageContent.substring(0, 100)}...' 
          : messageContent,
      details,
      payload: jsonEncode({
        'type': 'dm',
        'sender_id': senderId,
        'message_id': messageId,
      }),
    );
  }

  /// Show notification for friend request
  Future<void> showFriendRequestNotification({
    required String senderName,
    required String senderId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'friend_requests_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: [
        AndroidNotificationAction(
          'accept',
          'Accept',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'decline',
          'Decline',
          showsUserInterface: false,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      senderId.hashCode,
      'New Friend Request',
      '$senderName wants to be your friend',
      details,
      payload: jsonEncode({
        'type': 'friend_request',
        'sender_id': senderId,
      }),
    );
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get active notifications (Android only)
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (Platform.isAndroid) {
      return await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications() ?? [];
    }
    return [];
  }

  /// Dispose resources
  void dispose() {
    // Clean up resources if needed
  }
}

/// Background notification data
class BackgroundNotificationData {
  final NotificationType type;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;

  BackgroundNotificationData({
    required this.type,
    required this.payload,
    required this.receivedAt,
  });
}

/// Unread count data
class UnreadCountData {
  final int totalUnread;
  final Map<String, int> serverUnreadCounts;
  final Map<String, int> dmUnreadCounts;
  final DateTime lastUpdated;

  UnreadCountData({
    required this.totalUnread,
    required this.serverUnreadCounts,
    required this.dmUnreadCounts,
    required this.lastUpdated,
  });

  factory UnreadCountData.fromJson(Map<String, dynamic> json) {
    return UnreadCountData(
      totalUnread: json['total_unread'] as int,
      serverUnreadCounts: Map<String, int>.from(json['server_unread'] as Map),
      dmUnreadCounts: Map<String, int>.from(json['dm_unread'] as Map),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }
}
