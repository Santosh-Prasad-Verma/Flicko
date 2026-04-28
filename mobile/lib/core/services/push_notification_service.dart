import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/services/clerk_auth_service.dart';

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Handling background message: ${message.messageId}');
  
  // Initialize local notifications for background
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  await _showLocalNotification(notificationsPlugin, message);
}

/// Show local notification
Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  const androidDetails = AndroidNotificationDetails(
    'flicko_default_channel',
    'Flicko Notifications',
    channelDescription: 'Default notification channel for Flicko',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
    icon: '@mipmap/ic_launcher',
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

  final title = message.notification?.title ?? message.data['title'] ?? 'Flicko';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await plugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: details,
    payload: jsonEncode(message.data),
  );
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
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

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request permissions
      await _requestPermissions();

      // 3. Initialize local notifications
      await _initLocalNotifications();

      // 4. Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Set up notification tap handler
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. Get and register FCM token
      await _updateToken();

      // 7. Listen for token refreshes
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

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'flicko_default_channel',
        'Flicko Notifications',
        description: 'Default notification channel for Flicko',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received:');
    debugPrint('  - Title: ${message.notification?.title}');
    debugPrint('  - Body: ${message.notification?.body}');
    debugPrint('  - Data: ${message.data}');

    // Show local notification for foreground messages
    _showLocalNotification(_localNotifications, message);

    // Notify listeners
    _foregroundMessageController.add(message);
  }

  /// Handle notification taps from FCM
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
    _notificationTapController.add(message.data);
  }

  /// Handle local notification taps
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('👆 Local notification tapped: $data');
        _notificationTapController.add(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Handle background notification response
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('👆 Background notification response: ${response.payload}');
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
      // Get User ID from Clerk
      final userId = ClerkAuthService.currentAuthState?.user?.id;

      if (userId == null) {
        debugPrint('⚠️ No user logged in, cannot register FCM token');
        return;
      }

      // Store token in user_devices table
      await supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.operatingSystem,
        'device_name': Platform.localHostname,
        'last_used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,fcm_token');

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
      final userId = ClerkAuthService.currentAuthState?.user?.id;
      
      if (userId != null && _fcmToken != null) {
        await supabase
            .from('user_devices')
            .delete()
            .eq('user_id', userId)
            .eq('fcm_token', _fcmToken!);
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
          return '/dm/$senderId';
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
