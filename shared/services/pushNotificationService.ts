/**
 * Push Notification Service
 *
 * Handles Expo push notification registration, token management,
 * channel creation, foreground/background listeners, and deep linking.
 *
 * Requirements: Feature 20 (Push Notifications)
 * Zero-cost: Uses Expo Push (free tier) + Supabase push_notification_tokens table.
 */
import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import Constants from 'expo-constants';
import { supabase } from '../lib/supabase';

// ── Configuration ─────────────────────────────────────────────────────────

/** Show notification even when app is in foreground */
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
    priority: Notifications.AndroidNotificationPriority.HIGH,
  }),
});

// ── Types ────────────────────────────────────────────────────────────────

export interface PushTokenRecord {
  user_id: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
  device_id: string;
  is_active: boolean;
}

type NotificationListener = (notification: Notifications.Notification) => void;
type ResponseListener = (response: Notifications.NotificationResponse) => void;

// ── Push Notification Service ─────────────────────────────────────────────

class PushNotificationService {
  private expoPushToken: string | null = null;
  private notificationListener: Notifications.Subscription | null = null;
  private responseListener: Notifications.Subscription | null = null;
  private onNotificationReceived: NotificationListener | null = null;
  private onNotificationResponse: ResponseListener | null = null;

  /**
   * Initialize push notifications:
   * 1. Request permission
   * 2. Get Expo push token
   * 3. Create Android notification channel
   * 4. Register token with backend
   */
  async init(userId: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      console.warn('[PushNotificationService] Push notifications require a physical device');
      return null;
    }

    // Request permissions
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }

    if (finalStatus !== 'granted') {
      console.warn('[PushNotificationService] Permission not granted');
      return null;
    }

    // Create Android notification channels
    if (Platform.OS === 'android') {
      await this.createAndroidChannels();
    }

    // Get Expo push token
    try {
      const projectId = Constants.expoConfig?.extra?.eas?.projectId;
      const tokenData = await Notifications.getExpoPushTokenAsync({
        projectId,
      });
      this.expoPushToken = tokenData.data;

      // Register token in Supabase
      await this.registerToken(userId, this.expoPushToken);

      // Start listeners
      this.startListeners();

      return this.expoPushToken;
    } catch (err) {
      console.error('[PushNotificationService] Token error:', err);
      return null;
    }
  }

  /**
   * Register or update a push token in the database
   */
  private async registerToken(userId: string, token: string): Promise<void> {
    const platform = Platform.OS === 'ios' ? 'ios' : 'android';
    const deviceId = `${platform}-${Constants.deviceName ?? 'unknown'}`;

    const { error } = await supabase.from('push_notification_tokens').upsert(
      {
        user_id: userId,
        token,
        platform,
        device_id: deviceId,
        is_active: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'token' },
    );

    if (error) {
      console.error('[PushNotificationService] registerToken error:', error);
    }
  }

  /**
   * Deactivate the current token (on logout)
   */
  async deactivateToken(): Promise<void> {
    if (!this.expoPushToken) return;

    const { error } = await supabase
      .from('push_notification_tokens')
      .update({ is_active: false })
      .eq('token', this.expoPushToken);

    if (error) {
      console.error('[PushNotificationService] deactivateToken error:', error);
    }

    this.expoPushToken = null;
  }

  /**
   * Create Android notification channels for different notification types
   */
  private async createAndroidChannels(): Promise<void> {
    await Notifications.setNotificationChannelAsync('messages', {
      name: 'Messages',
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#5B4CFF',
      sound: 'default',
    });

    await Notifications.setNotificationChannelAsync('mentions', {
      name: 'Mentions',
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#ED4245',
      sound: 'default',
    });

    await Notifications.setNotificationChannelAsync('friend-requests', {
      name: 'Friend Requests',
      importance: Notifications.AndroidImportance.DEFAULT,
      sound: 'default',
    });

    await Notifications.setNotificationChannelAsync('system', {
      name: 'System',
      importance: Notifications.AndroidImportance.LOW,
    });
  }

  /**
   * Start foreground/response listeners
   */
  private startListeners(): void {
    // Foreground notification
    this.notificationListener = Notifications.addNotificationReceivedListener(
      (notification) => {
        this.onNotificationReceived?.(notification);
      },
    );

    // User tapped on notification
    this.responseListener = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        this.onNotificationResponse?.(response);
      },
    );
  }

  /**
   * Register a callback for when a notification is received in foreground
   */
  setOnNotificationReceived(handler: NotificationListener): void {
    this.onNotificationReceived = handler;
  }

  /**
   * Register a callback for when user interacts with a notification
   */
  setOnNotificationResponse(handler: ResponseListener): void {
    this.onNotificationResponse = handler;
  }

  /**
   * Get the current badge count
   */
  async getBadgeCount(): Promise<number> {
    return Notifications.getBadgeCountAsync();
  }

  /**
   * Set the app badge count
   */
  async setBadgeCount(count: number): Promise<void> {
    await Notifications.setBadgeCountAsync(count);
  }

  /**
   * Schedule a local notification (e.g., for reminders or offline mode)
   */
  async scheduleLocal(
    title: string,
    body: string,
    data?: Record<string, unknown>,
    seconds = 0,
  ): Promise<string> {
    return Notifications.scheduleNotificationAsync({
      content: {
        title,
        body,
        data,
        sound: 'default',
      },
      trigger: seconds > 0 ? { seconds, type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL } : null,
    });
  }

  /**
   * Dismiss all notifications
   */
  async dismissAll(): Promise<void> {
    await Notifications.dismissAllNotificationsAsync();
  }

  /**
   * Clean up listeners
   */
  destroy(): void {
    this.notificationListener?.remove();
    this.responseListener?.remove();
    this.notificationListener = null;
    this.responseListener = null;
    this.onNotificationReceived = null;
    this.onNotificationResponse = null;
  }

  /**
   * Get the current push token
   */
  getToken(): string | null {
    return this.expoPushToken;
  }
}

export const pushNotificationService = new PushNotificationService();
