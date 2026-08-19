import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/supabase_client.dart';

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// Check if quiet hours are currently active by reading SharedPreferences.
/// Used in top-level / static contexts where Riverpod is unavailable.
Future<bool> _isQuietHoursActive() async {
  final prefs = await SharedPreferences.getInstance();
  final quietEnabled = prefs.getBool('notif_quiet_hours') ?? false;
  if (!quietEnabled) return false;

  final startStr = prefs.getString('notif_quiet_start') ?? '22:00';
  final endStr = prefs.getString('notif_quiet_end') ?? '08:00';

  final now = DateTime.now();
  final currentMinutes = now.hour * 60 + now.minute;

  final startParts = startStr.split(':');
  final startMinutes =
      (int.tryParse(startParts[0]) ?? 22) * 60 +
      (int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0);

  final endParts = endStr.split(':');
  final endMinutes =
      (int.tryParse(endParts[0]) ?? 8) * 60 +
      (int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0);

  if (startMinutes <= endMinutes) {
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  } else {
    // Overnight range (e.g. 22:00 → 08:00)
    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Handling background message: ${message.messageId}');

  // Check quiet hours before showing notification
  if (await _isQuietHoursActive()) {
    debugPrint('🌙 Quiet hours active — suppressing background notification');
    return;
  }

  await PushNotificationService.showRichNotification(message);
}

/// Push Notification Service
/// 
/// Handles all Firebase Cloud Messaging functionality:
/// - FCM token management
/// - Permission requests
/// - Foreground/Background message handling
/// - Local notification display
/// - Deep linking from notifications
class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  bool _initialized = false;
  String? _fcmToken;
  
  // Streams for notification handling
  final _foregroundMessageController = StreamController<RemoteMessage>.broadcast();
  final _notificationTapController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream of foreground messages
  Stream<RemoteMessage> get onForegroundMessage => _foregroundMessageController.stream;
  
  /// Stream of notification taps
  Stream<Map<String, dynamic>> get onNotificationTap => _notificationTapController.stream;
  
  /// Current FCM token
  String? get fcmToken => _fcmToken;

  static PushNotificationService? _instance;

  PushNotificationService() {
    _instance = this;
  }

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request permissions
      await _requestPermissions();

      // 3. Initialize AwesomeNotifications
      await AwesomeNotifications().initialize(
        null, // Use default app icon
        [
          NotificationChannel(
            channelGroupKey: 'flicko_group',
            channelKey: 'flicko_default_channel',
            channelName: 'Flicko Notifications',
            channelDescription: 'Default notification channel for Flicko',
            defaultColor: const Color(0xFF7D39EB),
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          )
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: 'flicko_group',
            channelGroupName: 'Flicko Group',
          )
        ],
        debug: kDebugMode,
      );

      // 4. Check if notification permissions are allowed, if not request
      bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      // 5. Set up awesome_notifications event listeners
      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
        onNotificationCreatedMethod: onNotificationCreatedMethod,
        onNotificationDisplayedMethod: onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: onDismissActionReceivedMethod,
      );

      // 6. Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. Set up notification tap handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 8. Get and register FCM token
      await _updateToken();

      // 9. Listen for token refreshes
      _fcm.onTokenRefresh.listen(_onTokenRefresh);

      _initialized = true;
      debugPrint('✅ PushNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing PushNotificationService: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );

    debugPrint('📢 Notification permission status: ${settings.authorizationStatus}');
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint('👆 User tapped notification. Payload: ${receivedAction.payload}');
    if (receivedAction.payload != null) {
      _instance?._notificationTapController.add(Map<String, dynamic>.from(receivedAction.payload!));
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    debugPrint('Notification created: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    debugPrint('Notification displayed: ${receivedNotification.id}');
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint('Notification dismissed: ${receivedAction.id}');
  }

  /// Show rich notification using AwesomeNotifications
  static Future<void> showRichNotification(RemoteMessage message) async {
    // Check quiet hours before displaying
    if (await _isQuietHoursActive()) {
      debugPrint('🌙 Quiet hours active — suppressing rich notification');
      return;
    }

    final title = message.notification?.title ?? message.data['title'] ?? 'Flicko';
    var body = message.notification?.body ?? message.data['body'] ?? '';
    var imageUrl = message.notification?.android?.imageUrl ?? message.data['image_url'];

    // Rewrite media URLs to human-readable strings and set as big picture
    final lowerBody = body.trim().toLowerCase();
    if (lowerBody.startsWith('http://') || lowerBody.startsWith('https://')) {
      final mediaUrl = body.trim();
      imageUrl ??= mediaUrl;
      if (lowerBody.contains('/sticker/')) {
        body = 'sent a sticker ⚡';
      } else if (lowerBody.endsWith('.gif') || lowerBody.contains('.gif')) {
        body = 'sent a GIF 🎬';
      } else if (lowerBody.endsWith('.png') || lowerBody.endsWith('.jpg') || lowerBody.endsWith('.jpeg') || lowerBody.endsWith('.webp')) {
        body = 'sent a photo 📷';
      } else if (lowerBody.endsWith('.mp4') || lowerBody.endsWith('.mov') || lowerBody.endsWith('.webm') || lowerBody.endsWith('.avi')) {
        body = 'sent a video 🎥';
      }
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.hashCode,
        channelKey: 'flicko_default_channel',
        title: title,
        body: body,
        bigPicture: imageUrl,
        largeIcon: imageUrl,
        hideLargeIconOnExpand: true,
        notificationLayout: imageUrl != null 
            ? NotificationLayout.BigPicture 
            : NotificationLayout.Default,
        payload: Map<String, String>.from(message.data.map(
          (key, value) => MapEntry(key, value.toString()),
        )),
      ),
    );
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 Foreground message received:');
    debugPrint('  - Title: ${message.notification?.title}');
    debugPrint('  - Body: ${message.notification?.body}');
    debugPrint('  - Data: ${message.data}');

    // Check quiet hours before showing notification
    if (await _isQuietHoursActive()) {
      debugPrint('🌙 Quiet hours active — suppressing foreground notification');
      _foregroundMessageController.add(message);
      return;
    }

    // Show local notification for foreground messages
    showRichNotification(message);

    // Notify listeners
    _foregroundMessageController.add(message);
  }

  /// Handle notification taps from FCM
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
    _notificationTapController.add(message.data);
  }

  /// Update and register FCM token with Supabase
  Future<void> _updateToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _registerTokenWithSupabase(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('🔄 FCM token refreshed');
    _fcmToken = newToken;
    await _registerTokenWithSupabase(newToken);
  }

  /// Register FCM token with Supabase
  Future<void> _registerTokenWithSupabase(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('⚠️ No user logged in, cannot register FCM token');
        return;
      }

      String platformStr = 'web';
      if (Platform.isAndroid) {
        platformStr = 'android';
      } else if (Platform.isIOS) {
        platformStr = 'ios';
      }

      // Store token in push_notification_tokens table
      await supabase.from('push_notification_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platformStr,
        'device_id': Platform.localHostname,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');

      debugPrint('✅ FCM token registered with Supabase');
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId != null && _fcmToken != null) {
        await supabase
            .from('push_notification_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', _fcmToken!);
      }

      _fcmToken = null;
      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('📡 Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('📡 Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _foregroundMessageController.close();
    _notificationTapController.close();
  }
}

/// Notification types
enum NotificationType {
  message,
  mention,
  dm,
  friendRequest,
  serverInvite,
  voiceCall,
  system,
}

/// Extension to parse notification type
extension NotificationTypeExtension on String {
  NotificationType toNotificationType() {
    switch (toLowerCase()) {
      case 'message':
        return NotificationType.message;
      case 'mention':
        return NotificationType.mention;
      case 'dm':
        return NotificationType.dm;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'server_invite':
        return NotificationType.serverInvite;
      case 'voice_call':
        return NotificationType.voiceCall;
      default:
        return NotificationType.system;
    }
  }
}

/// Notification data model
class NotificationData {
  final NotificationType type;
  final String? serverId;
  final String? channelId;
  final String? messageId;
  final String? senderId;
  final String? senderName;
  final String? content;

  NotificationData({
    required this.type,
    this.serverId,
    this.channelId,
    this.messageId,
    this.senderId,
    this.senderName,
    this.content,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      type: (map['type'] as String? ?? 'system').toNotificationType(),
      serverId: map['server_id'] as String?,
      channelId: map['channel_id'] as String?,
      messageId: map['message_id'] as String?,
      senderId: map['sender_id'] as String?,
      senderName: map['sender_name'] as String?,
      content: map['content'] as String?,
    );
  }

  /// Get navigation route from notification data
  String? get navigationRoute {
    switch (type) {
      case NotificationType.message:
      case NotificationType.mention:
        if (serverId != null && channelId != null) {
          return '/server/$serverId/channel/$channelId';
        }
        return null;
      case NotificationType.dm:
        if (senderId != null) {
          return '/dms/$senderId';
        }
        return null;
      case NotificationType.friendRequest:
        return '/friends/requests';
      case NotificationType.serverInvite:
        if (serverId != null) {
          return '/server/$serverId';
        }
        return null;
      case NotificationType.voiceCall:
        if (serverId != null && channelId != null) {
          return '/server/$serverId/channel/$channelId/voice';
        }
        return null;
      case NotificationType.system:
        return '/notifications';
    }
  }
}
