/**
 * Server Notification Settings Screen
 *
 * Per-server notification level, suppress @everyone/@role, mobile push.
 * Requirements: Feature 18 (Notification Granularity)
 */
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, Stack, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  NotifyLevel,
  ServerNotificationSettings,
  getServerNotificationSettings,
  updateServerNotificationSettings,
} from '@services/notificationSettingsService';
import { useAuthStore } from '@stores/authStore';

const NOTIFY_LEVELS: { value: NotifyLevel; label: string; description: string; icon: keyof typeof Ionicons.glyphMap }[] = [
  { value: 'all', label: 'All Messages', description: 'Get notified for every message', icon: 'notifications' },
  { value: 'mentions', label: 'Only @Mentions', description: 'Get notified only when mentioned', icon: 'at' },
  { value: 'none', label: 'Nothing', description: 'Mute all notifications from this server', icon: 'notifications-off' },
];

export default function NotificationSettingsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const userId = useAuthStore((s: any) => s.user?.id);
  const { themeColors: c } = useTheme();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [level, setLevel] = useState<NotifyLevel>('all');
  const [suppressEveryone, setSuppressEveryone] = useState(false);
  const [suppressRoles, setSuppressRoles] = useState(false);
  const [mobilePush, setMobilePush] = useState(true);

  useEffect(() => {
    if (!serverId || !userId) return;
    (async () => {
      try {
        const settings = await getServerNotificationSettings(serverId, userId);
        if (settings) {
          setLevel(settings.level);
          setSuppressEveryone(settings.suppress_everyone);
          setSuppressRoles(settings.suppress_role_mentions);
          setMobilePush(settings.mobile_push);
        }
      } catch {}
      setLoading(false);
    })();
  }, [serverId, userId]);

  const save = useCallback(
    async (updates: Partial<Omit<ServerNotificationSettings, 'server_id' | 'user_id'>>) => {
      if (!serverId || !userId) return;
      setSaving(true);
      try {
        await updateServerNotificationSettings(serverId, userId, updates);
      } catch {}
      setSaving(false);
    },
    [serverId, userId],
  );

  if (loading) {
    return (
      <View style={[styles.center, { backgroundColor: c.bgPrimary }]}>
        <Stack.Screen options={{ title: 'Notifications' }} />
        <ActivityIndicator color={c.accentPrimary} />
      </View>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: c.bgPrimary }]}> 
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + spacing.sm,
              backgroundColor: c.bgSecondary,
              borderBottomColor: c.border,
            },
          ]}
        >
          <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.headerBtn, { backgroundColor: c.bgTertiary }]}> 
            <Ionicons name="arrow-back" size={24} color={c.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: c.textPrimary }]}>Notifications</Text>
          <View style={[styles.headerBtn, { backgroundColor: c.bgTertiary, opacity: 0 }]}> 
            <Ionicons name="arrow-back" size={24} color={c.textPrimary} />
          </View>
        </View>

        <ScrollView style={styles.scroll}>

      {/* Notification Level */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>NOTIFICATION LEVEL</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        {NOTIFY_LEVELS.map((opt) => {
          const selected = level === opt.value;
          return (
            <Pressable
              key={opt.value}
              style={[styles.levelRow, selected && { backgroundColor: c.bgTertiary }]}
              onPress={() => {
                setLevel(opt.value);
                save({ level: opt.value });
              }}
            >
              <Ionicons name={opt.icon} size={20} color={selected ? c.accentPrimary : c.textMuted} />
              <View style={styles.levelText}>
                <Text style={[styles.levelLabel, { color: c.textPrimary }]}>{opt.label}</Text>
                <Text style={[styles.levelDesc, { color: c.textSecondary }]}>{opt.description}</Text>
              </View>
              {selected && <Ionicons name="checkmark-circle" size={22} color={c.accentPrimary} />}
            </Pressable>
          );
        })}
      </View>

      {/* Suppress Toggles */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>SUPPRESS</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        <View style={styles.switchRow}>
          <View style={styles.switchLabel}>
            <Text style={[styles.switchTitle, { color: c.textPrimary }]}>Suppress @everyone and @here</Text>
            <Text style={[styles.switchDesc, { color: c.textSecondary }]}>
              Don't receive notifications for @everyone or @here pings
            </Text>
          </View>
          <Switch
            value={suppressEveryone}
            onValueChange={(v) => {
              setSuppressEveryone(v);
              save({ suppress_everyone: v });
            }}
            trackColor={{ false: c.border, true: c.accentPrimary }}
            thumbColor={c.textPrimary}
          />
        </View>

        <View style={[styles.divider, { backgroundColor: c.border }]} />

        <View style={styles.switchRow}>
          <View style={styles.switchLabel}>
            <Text style={[styles.switchTitle, { color: c.textPrimary }]}>Suppress Role Mentions</Text>
            <Text style={[styles.switchDesc, { color: c.textSecondary }]}>
              Don't receive notifications when a role you have is mentioned
            </Text>
          </View>
          <Switch
            value={suppressRoles}
            onValueChange={(v) => {
              setSuppressRoles(v);
              save({ suppress_role_mentions: v });
            }}
            trackColor={{ false: c.border, true: c.accentPrimary }}
            thumbColor={c.textPrimary}
          />
        </View>
      </View>

      {/* Mobile Push */}
      <Text style={[styles.sectionTitle, { color: c.textMuted }]}>PUSH NOTIFICATIONS</Text>
      <View style={[styles.card, { backgroundColor: c.bgSecondary }]}>
        <View style={styles.switchRow}>
          <View style={styles.switchLabel}>
            <Text style={[styles.switchTitle, { color: c.textPrimary }]}>Mobile Push</Text>
            <Text style={[styles.switchDesc, { color: c.textSecondary }]}>
              Receive push notifications on your device
            </Text>
          </View>
          <Switch
            value={mobilePush}
            onValueChange={(v) => {
              setMobilePush(v);
              save({ mobile_push: v });
            }}
            trackColor={{ false: c.border, true: c.accentPrimary }}
            thumbColor={c.textPrimary}
          />
        </View>
      </View>

      {saving && (
        <View style={styles.savingBanner}>
          <ActivityIndicator color={c.accentPrimary} size="small" />
          <Text style={[styles.savingText, { color: c.textSecondary }]}>Saving…</Text>
        </View>
      )}

          <View style={{ height: spacing.xxxxl }} />
        </ScrollView>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  scroll: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  headerBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  sectionTitle: {
    ...typography.overline,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    paddingBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: borderRadius.md,
    overflow: 'hidden',
  },
  levelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
    gap: spacing.md,
  },
  levelText: { flex: 1 },
  levelLabel: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  levelDesc: { ...typography.caption, marginTop: 2 },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    gap: spacing.md,
  },
  switchLabel: { flex: 1 },
  switchTitle: { ...typography.bodySmall, fontFamily: 'gg-sans-medium' },
  switchDesc: { ...typography.caption, marginTop: 2 },
  divider: { height: 1, marginHorizontal: spacing.lg },
  savingBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingTop: spacing.lg,
  },
  savingText: { ...typography.caption },
});
