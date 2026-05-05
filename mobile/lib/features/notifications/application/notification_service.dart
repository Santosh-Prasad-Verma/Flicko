import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  NotificationService();

  Future<void> init() async {
    // Request permissions (especially for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _logger.i('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      _logger.i('User granted provisional notification permission');
    } else {
      _logger.w('User declined or has not accepted notification permission');
    }

    // Get FCM token
    try {
      final token = await _fcm.getToken();
      _logger.i('FCM Token: $token');
      // In a real app, you would send this token to your backend/Supabase
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
    }

    // Initialize local notifications for foreground messaging
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _handleNotificationClick(details.payload);
      },
    );

    // Create the notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'flicko_channel',
      'Flicko Notifications',
      description: 'Main notification channel for Flicko',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.d('Foreground message received: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle clicks when app is in background but still in memory
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.d('Notification clicked while app in background: ${message.data}');
      _handleNotificationClick(message.data.toString());
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _logger.d('App opened from terminated state via notification: ${initialMessage.data}');
      _handleNotificationClick(initialMessage.data.toString());
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'flicko_channel',
            'Flicko Notifications',
            channelDescription: 'Main notification channel for Flicko',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    _logger.i('Notification payload clicked: $payload');
    // Implement navigation logic here based on payload
    // Example: Use go_router to navigate to a specific channel or DM
  }
}
