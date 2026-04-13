/**
 * Notification Center Screen
 *
 * Mirrors the web NotificationCenter with tabs: All, Mentions, DMs, Friends.
 * Route: /notifications
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../services/supabase';
import { Avatar } from '../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../constants/Colors';
import { useTheme } from '../hooks/useTheme';

interface Notification {
  id: string;
  user_id: string;
  type: 'mention' | 'dm' | 'friend_request' | 'server_invite' | 'event' | 'stream';
  content: any;
  read: boolean;
  created_at: string;
}

const TABS = ['All', 'Mentions', 'DMs', 'Friends'] as const;

function getRelativeTime(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);
  if (diffInSeconds < 60) return `${diffInSeconds}s ago`;
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
  return `${Math.floor(diffInSeconds / 86400)}d ago`;
}

function getTypeIcon(type: string): keyof typeof Ionicons.glyphMap {
  switch (type) {
    case 'mention': return 'at';
    case 'dm': return 'chatbubble';
    case 'friend_request': return 'person-add';
    case 'server_invite': return 'mail';
    case 'event': return 'calendar';
    case 'stream': return 'videocam';
    default: return 'notifications';
  }
}

export default function NotificationsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const [activeTab, setActiveTab] = useState<typeof TABS[number]>('All');
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);

  const fetchNotifications = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    setUserId(user.id);

    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (!error && data) {
      setNotifications(data as Notification[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  // Real-time subscription
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel('mobile_notifications')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
        () => fetchNotifications(),
      )
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [userId, fetchNotifications]);

  const filteredNotifications = notifications.filter((n) => {
    if (activeTab === 'All') return true;
    if (activeTab === 'Mentions') return n.type === 'mention';
    if (activeTab === 'DMs') return n.type === 'dm';
    if (activeTab === 'Friends') return n.type === 'friend_request';
    return true;
  });

  const unreadCount = notifications.filter((n) => !n.read).length;

  const markAsRead = async (id: string) => {
    setNotifications((prev) => prev.map((n) => n.id === id ? { ...n, read: true } : n));
    await supabase.from('notifications').update({ read: true }).eq('id', id);
  };

  const markAllAsRead = async () => {
    if (!userId || unreadCount === 0) return;
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    await supabase.from('notifications').update({ read: true }).eq('user_id', userId).eq('read', false);
  };

  const handleNotificationPress = useCallback((item: Notification) => {
    markAsRead(item.id);
    const meta = item.content || {};
    // Navigate based on type
    if (item.type === 'mention' && meta.channelId && meta.serverId) {
      router.push(`/server/${meta.serverId}/channel/${meta.channelId}` as any);
    } else if (item.type === 'dm' && meta.conversationId) {
      router.push(`/dm/${meta.conversationId}` as any);
    } else if (item.type === 'friend_request' && meta.userId) {
      router.push(`/profile/${meta.userId}` as any);
    } else if (item.type === 'server_invite' && meta.serverId) {
      router.push(`/server/${meta.serverId}` as any);
    }
  }, [markAsRead]);

  const handleAcceptFriend = useCallback(async (notifId: string, senderId?: string) => {
    if (!senderId || !userId) return;
    // Accept in friend_requests table
    await supabase
      .from('friend_requests')
      .update({ status: 'accepted' })
      .eq('sender_id', senderId)
      .eq('receiver_id', userId);
    // Insert friendship
    await supabase.from('friendships').insert([
      { user_id: userId, friend_id: senderId },
      { user_id: senderId, friend_id: userId },
    ]);
    markAsRead(notifId);
  }, [userId, markAsRead]);

  const handleDeclineFriend = useCallback(async (notifId: string, senderId?: string) => {
    if (!senderId || !userId) return;
    await supabase
      .from('friend_requests')
      .update({ status: 'declined' })
      .eq('sender_id', senderId)
      .eq('receiver_id', userId);
    markAsRead(notifId);
  }, [userId, markAsRead]);

  const renderNotification = ({ item }: { item: Notification }) => {
    const meta = item.content || {};
    return (
      <Pressable
        style={({ pressed }) => [
          styles.notifRow,
          !item.read && { backgroundColor: themeColors.bgSecondary },
          pressed && { opacity: 0.8 },
        ]}
        onPress={() => handleNotificationPress(item)}
      >
        {/* Unread dot */}
        {!item.read && <View style={[styles.unreadDot, { backgroundColor: themeColors.accentPrimary }]} />}

        {/* Icon */}
        <View style={[styles.iconCircle, { backgroundColor: themeColors.bgTertiary }]}>
          {meta.userAvatar ? (
            <Avatar name={meta.userName || 'User'} imageUrl={meta.userAvatar} size={32} />
          ) : (
            <Ionicons name={getTypeIcon(item.type)} size={18} color={themeColors.textMuted} />
          )}
        </View>

        {/* Content */}
        <View style={styles.notifContent}>
          {/* Channel/server context */}
          {(item.type === 'mention' || item.type === 'event') && meta.channelName && (
            <Text style={[styles.notifMeta, { color: themeColors.textMuted }]}>
              #{meta.channelName}
            </Text>
          )}
          <Text style={[styles.notifText, { color: themeColors.textPrimary }]} numberOfLines={2}>
            {item.type === 'event' ? (
              meta.content
            ) : (
              <>
                <Text style={{ fontFamily: 'gg-sans-bold' }}>{meta.userName || 'Someone'}</Text>
                {' '}{meta.content || 'sent a notification'}
              </>
            )}
          </Text>
          {meta.preview && (
            <Text style={[styles.notifPreview, { color: themeColors.textMuted }]} numberOfLines={1}>
              {meta.preview}
            </Text>
          )}

          {/* Friend request actions */}
          {item.type === 'friend_request' && !item.read && (
            <View style={styles.actionRow}>
              <Pressable
                style={[styles.actionBtn, { backgroundColor: themeColors.accentPrimary }]}
                onPress={() => handleAcceptFriend(item.id, meta.userId)}
              >
                <Text style={styles.actionBtnText}>Accept</Text>
              </Pressable>
              <Pressable
                style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => handleDeclineFriend(item.id, meta.userId)}
              >
                <Text style={[styles.actionBtnText, { color: themeColors.textMuted }]}>Decline</Text>
              </Pressable>
            </View>
          )}
        </View>

        {/* Time */}
        <Text style={[styles.notifTime, { color: themeColors.textMuted }]}>
          {getRelativeTime(item.created_at)}
        </Text>
      </Pressable>
    );
  };

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Notifications',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
          headerRight: () => (
            <Pressable onPress={markAllAsRead} hitSlop={8} disabled={unreadCount === 0}>
              <Text style={{ color: unreadCount > 0 ? themeColors.accentPrimary : themeColors.textMuted, ...typography.bodySmall }}>
                Mark all read
              </Text>
            </Pressable>
          ),
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Filter Tabs */}
        <View style={[styles.tabBar, { borderBottomColor: themeColors.bgTertiary }]}>
          {TABS.map((tab) => (
            <Pressable
              key={tab}
              style={[
                styles.tab,
                activeTab === tab && { borderBottomColor: themeColors.accentPrimary, borderBottomWidth: 2 },
              ]}
              onPress={() => setActiveTab(tab)}
            >
              <Text
                style={[
                  styles.tabText,
                  { color: activeTab === tab ? themeColors.textPrimary : themeColors.textMuted },
                ]}
              >
                {tab}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* List */}
        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator color={themeColors.accentPrimary} size="large" />
          </View>
        ) : filteredNotifications.length === 0 ? (
          <View style={styles.center}>
            <Ionicons name="notifications-off-outline" size={48} color={themeColors.textMuted} />
            <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
              No notifications to show
            </Text>
          </View>
        ) : (
          <FlatList
            data={filteredNotifications}
            renderItem={renderNotification}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
            refreshControl={
              <RefreshControl
                refreshing={refreshing}
                onRefresh={() => { setRefreshing(true); fetchNotifications(); }}
                tintColor={themeColors.accentPrimary}
              />
            }
          />
        )}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  tabBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  tabText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.md,
  },
  emptyText: {
    ...typography.body,
  },
  notifRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  unreadDot: {
    position: 'absolute',
    left: spacing.xs,
    top: spacing.md + 4,
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  notifContent: {
    flex: 1,
    gap: 2,
  },
  notifMeta: {
    ...typography.caption,
  },
  notifText: {
    ...typography.body,
  },
  notifPreview: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  notifTime: {
    ...typography.caption,
    marginTop: 2,
  },
  actionRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
  actionBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: 4,
  },
  actionBtnText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
    color: '#fff',
  },
});
