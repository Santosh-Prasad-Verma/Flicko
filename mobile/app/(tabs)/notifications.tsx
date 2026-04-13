/**
 * Notifications Tab Screen
 *
 * Tab version of NotificationCenter with tabs: All, Mentions, DMs, Friends.
 * Shows real-time notifications with filter tabs.
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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../services/supabase';
import { Avatar } from '../../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';

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

export default function NotificationsTabScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const [activeTab, setActiveTab] = useState<typeof TABS[number]>('All');
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchNotifications = useCallback(async () => {
    if (!user?.id) {
      setLoading(false);
      setRefreshing(false);
      return;
    }

    const { data, error: fetchError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (fetchError) {
      console.warn('[Notifications] fetch error:', fetchError.message);
      setError(fetchError.message);
    } else if (data) {
      setNotifications(data as Notification[]);
      setError(null);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications, user?.id]);

  // Real-time subscription
  useEffect(() => {
    if (!user?.id) return;
    const channel = supabase
      .channel('tab_notifications')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${user.id}` },
        () => fetchNotifications(),
      )
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [user?.id, fetchNotifications]);

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
    if (!user?.id || unreadCount === 0) return;
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    await supabase.from('notifications').update({ read: true }).eq('user_id', user.id).eq('read', false);
  };

  const renderNotification = ({ item }: { item: Notification }) => {
    const meta = item.content || {};
    return (
      <Pressable
        style={({ pressed }) => [
          styles.notifRow,
          !item.read && { backgroundColor: themeColors.bgSecondary },
          pressed && { opacity: 0.8 },
        ]}
        onPress={() => markAsRead(item.id)}
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
              <Pressable style={[styles.actionBtn, { backgroundColor: themeColors.accentPrimary }]}>
                <Text style={styles.actionBtnText}>Accept</Text>
              </Pressable>
              <Pressable style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}>
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
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary, paddingTop: insets.top }]}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: themeColors.border }]}>
        <Pressable
          onPress={() => router.push('/search' as any)}
          hitSlop={12}
          style={[{ marginRight: 'auto', padding: spacing.xs }]}
        >
          <Ionicons name="search" size={24} color={themeColors.textPrimary} />
        </Pressable>
        {unreadCount > 0 && (
          <Pressable onPress={markAllAsRead} hitSlop={8}>
            <Text style={{ color: themeColors.accentPrimary, fontSize: 14, fontFamily: 'gg-sans-semibold' }}>
              Mark all read
            </Text>
          </Pressable>
        )}
      </View>

      {/* Filter Tabs */}
      <View style={[styles.tabBar, { borderBottomColor: themeColors.border }]}>
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
          <Text style={[styles.loadingText, { color: themeColors.textMuted }]}>Loading notifications...</Text>
        </View>
      ) : error ? (
        <View style={styles.center}>
          <View style={[styles.iconCircleLarge, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="alert-circle-outline" size={56} color={themeColors.danger} />
          </View>
          <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>
            Could not load notifications
          </Text>
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            {error}
          </Text>
          <Pressable 
            onPress={() => { setLoading(true); setError(null); fetchNotifications(); }}
            style={[styles.retryButton, { backgroundColor: themeColors.accentPrimary }]}
          >
            <Text style={styles.retryButtonText}>Tap to retry</Text>
          </Pressable>
        </View>
      ) : filteredNotifications.length === 0 ? (
        <View style={styles.center}>
          <View style={[styles.iconCircleLarge, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="notifications-off-outline" size={56} color={themeColors.textMuted} />
          </View>
          <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>
            No notifications
          </Text>
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            {activeTab === 'All' 
              ? "You're all caught up! Notifications will appear here."
              : `No ${activeTab.toLowerCase()} notifications to show.`}
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
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
  },
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
    paddingHorizontal: spacing.xl,
  },
  iconCircleLarge: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  emptyTitle: {
    fontSize: 18,
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
  },
  emptyText: {
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 20,
  },
  loadingText: {
    fontSize: 14,
    marginTop: spacing.sm,
  },
  retryButton: {
    marginTop: spacing.md,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.sm,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
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
