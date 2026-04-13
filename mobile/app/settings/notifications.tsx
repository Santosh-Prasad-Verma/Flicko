/**
 * Notification Settings Screen
 *
 * Full notification controls: push, types, suppression, quiet hours.
 * All settings backed by settingsStore for persistence.
 * Route: /settings/notifications
 */
import React, { useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Switch,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useSettingsStore } from '@stores/settingsStore';

interface ToggleSetting {
  label: string;
  description: string;
  value: boolean;
  onToggle: () => void;
}

export default function NotificationSettingsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const notifications = useSettingsStore((s) => s.notifications);
  const updateNotifications = useSettingsStore((s) => s.updateNotifications);

  const pushSettings: ToggleSetting[] = [
    { label: 'Mobile Push Notifications', description: 'Receive push notifications on this device', value: notifications.mobilePush, onToggle: () => updateNotifications({ mobilePush: !notifications.mobilePush }) },
    { label: 'Desktop Notifications', description: 'Show desktop notifications', value: notifications.desktop, onToggle: () => updateNotifications({ desktop: !notifications.desktop }) },
    { label: 'Notification Sounds', description: 'Play sounds for incoming notifications', value: notifications.sound, onToggle: () => updateNotifications({ sound: !notifications.sound }) },
  ];

  const typeSettings: ToggleSetting[] = [
    { label: 'Mentions', description: 'When someone @mentions you', value: notifications.mentions, onToggle: () => updateNotifications({ mentions: !notifications.mentions }) },
    { label: 'DM Notifications', description: 'Notify for new direct messages', value: notifications.dmNotifications, onToggle: () => updateNotifications({ dmNotifications: !notifications.dmNotifications }) },
  ];

  const suppressionSettings: ToggleSetting[] = [
    { label: 'Suppress @everyone and @here', description: 'Don\'t get notified for @everyone or @here mentions', value: notifications.suppressEveryone, onToggle: () => updateNotifications({ suppressEveryone: !notifications.suppressEveryone }) },
    { label: 'Suppress All Role @mentions', description: 'Don\'t get notified for role mentions', value: notifications.suppressRoles, onToggle: () => updateNotifications({ suppressRoles: !notifications.suppressRoles }) },
  ];

  const quietHoursSettings: ToggleSetting[] = [
    { label: 'Enable Quiet Hours', description: `Mute notifications ${notifications.quietHoursStart} – ${notifications.quietHoursEnd}`, value: notifications.quietHoursEnabled, onToggle: () => updateNotifications({ quietHoursEnabled: !notifications.quietHoursEnabled }) },
  ];

  const renderToggleSection = (title: string, items: ToggleSetting[]) => (
    <>
      <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>{title}</Text>
      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        {items.map((item, i) => (
          <View
            key={item.label}
            style={[
              styles.toggleRow,
              i < items.length - 1 && {
                borderBottomWidth: StyleSheet.hairlineWidth,
                borderBottomColor: themeColors.border,
              },
            ]}
          >
            <View style={styles.toggleInfo}>
              <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>
                {item.label}
              </Text>
              <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
                {item.description}
              </Text>
            </View>
            <Switch
              value={item.value}
              onValueChange={item.onToggle}
              trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              thumbColor="#fff"
            />
          </View>
        ))}
      </View>
    </>
  );

  const renderTimePickerRow = (label: string, value: string, onPress: () => {}) => (
    <Pressable style={styles.toggleRow} onPress={onPress}>
      <View style={styles.toggleInfo}>
        <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>{label}</Text>
      </View>
      <Text style={[styles.timeValue, { color: themeColors.accentPrimary }]}>{value}</Text>
      <Ionicons name="chevron-forward" size={16} color={themeColors.textMuted} />
    </Pressable>
  );

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
        }}
      />
      <ScrollView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
      >
        {renderToggleSection('PUSH NOTIFICATIONS', pushSettings)}
        {renderToggleSection('NOTIFICATION TYPES', typeSettings)}
        {renderToggleSection('SUPPRESSION', suppressionSettings)}
        {renderToggleSection('QUIET HOURS', quietHoursSettings)}
        {notifications.quietHoursEnabled && (
          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary, marginHorizontal: spacing.md, marginTop: spacing.sm }]}>
            <View style={[styles.toggleRow, { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: themeColors.border }]}>
              <View style={styles.toggleInfo}>
                <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>Start Time</Text>
              </View>
              <Text style={[styles.timeValue, { color: themeColors.accentPrimary }]}>{notifications.quietHoursStart}</Text>
            </View>
            <View style={styles.toggleRow}>
              <View style={styles.toggleInfo}>
                <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>End Time</Text>
              </View>
              <Text style={[styles.timeValue, { color: themeColors.accentPrimary }]}>{notifications.quietHoursEnd}</Text>
            </View>
          </View>
        )}
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  sectionHeader: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginHorizontal: spacing.md + spacing.sm,
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  card: {
    marginHorizontal: spacing.md,
    borderRadius: 12,
    overflow: 'hidden',
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  toggleInfo: {
    flex: 1,
    marginRight: spacing.md,
  },
  toggleLabel: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  toggleDesc: {
    ...typography.caption,
    marginTop: 2,
  },
  timeValue: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    marginRight: spacing.xs,
  },
});
