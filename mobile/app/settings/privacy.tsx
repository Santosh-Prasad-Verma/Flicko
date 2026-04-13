/**
 * Privacy & Safety Settings Screen
 *
 * Mirrors web UserSettingsModal "Privacy & Safety" tab.
 * Route: /settings/privacy
 */
import React from 'react';
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
import { useAuthStore } from '@stores/authStore';
import { upsertUserPrivacySettings } from '@shared/services/privacySettingsService';

export default function PrivacySettingsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const userId = useAuthStore((s) => s.user?.id);
  const settings = useSettingsStore((s) => s.privacyPreferences);
  const updatePrivacyPreferences = useSettingsStore((s) => s.updatePrivacyPreferences);

  const sections = [
    {
      title: 'DIRECT MESSAGES',
      items: [
        {
          label: 'Allow DMs from server members',
          description: 'Members of your servers can send you DMs',
          key: 'allowDmsFromServerMembers' as const,
        },
        {
          label: 'Allow DMs from everyone',
          description: 'Anyone can send you direct messages',
          key: 'allowDmsFromEveryone' as const,
        },
      ],
    },
    {
      title: 'FRIEND REQUESTS',
      items: [
        {
          label: 'Allow from everyone',
          description: 'Anyone can send you friend requests',
          key: 'allowFriendRequestsFromEveryone' as const,
        },
      ],
    },
    {
      title: 'STATUS',
      items: [
        {
          label: 'Show online status',
          description: 'Display when you are online to others',
          key: 'showOnlineStatus' as const,
        },
        {
          label: 'Show current activity',
          description: 'Display your current activity as a status',
          key: 'showCurrentActivity' as const,
        },
        {
          label: 'Read receipts',
          description: 'Let others see when you have read messages',
          key: 'readReceipts' as const,
        },
      ],
    },
  ];

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Privacy & Safety',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xl }}
      >
        {sections.map((section) => (
          <View key={section.title}>
            <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>{section.title}</Text>
            <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
              {section.items.map((item, i) => (
                <View
                  key={item.key}
                  style={[
                    styles.toggleRow,
                    i < section.items.length - 1 && {
                      borderBottomWidth: StyleSheet.hairlineWidth,
                      borderBottomColor: themeColors.border,
                    },
                  ]}
                >
                  <View style={styles.rowInfo}>
                    <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>{item.label}</Text>
                    <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>{item.description}</Text>
                  </View>
                  <Switch
                    value={settings[item.key]}
                    onValueChange={() => {
                      const nextVal = !settings[item.key];
                      updatePrivacyPreferences({ [item.key]: nextVal });
                      const merged = useSettingsStore.getState().privacyPreferences;
                      if (userId) {
                        void upsertUserPrivacySettings(userId, merged).catch((e: Error) =>
                          console.warn('[privacy] sync failed', e.message)
                        );
                      }
                    }}
                    trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
                    thumbColor="#fff"
                  />
                </View>
              ))}
            </View>
          </View>
        ))}
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  sectionTitle: {
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
  rowInfo: { flex: 1, paddingRight: spacing.sm },
  rowLabel: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  rowDesc: { ...typography.caption, marginTop: 2 },
});
