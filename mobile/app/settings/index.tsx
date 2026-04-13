/**
 * Settings Index Screen
 *
 * Main settings navigation mirroring web UserSettingsModal sidebar.
 * Route: /settings
 * Requirements: 10.3, 10.4
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore } from '@stores/authStore';
import { useSettingsStore } from '@stores/settingsStore';
import { Avatar } from '../../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface SettingsRow {
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  route: string;
  danger?: boolean;
}

const USER_SETTINGS: SettingsRow[] = [
  { label: 'My Account', icon: 'person-outline', route: '/settings/account' },
  { label: 'Edit Profile', icon: 'create-outline', route: '/settings/edit-profile' },
  { label: 'Privacy & Safety', icon: 'shield-checkmark-outline', route: '/settings/privacy' },
  // { label: 'Switch Accounts', icon: 'swap-horizontal-outline', route: '/settings/accounts' },
];

const APP_SETTINGS: SettingsRow[] = [
  { label: 'Appearance', icon: 'color-palette-outline', route: '/settings/appearance' },
  { label: 'Accessibility', icon: 'accessibility-outline', route: '/settings/accessibility' },
  { label: 'Chat', icon: 'chatbubbles-outline', route: '/settings/chat' },
  { label: 'Notifications', icon: 'notifications-outline', route: '/settings/notifications' },
  { label: 'Voice & Video', icon: 'mic-outline', route: '/settings/voice' },
  { label: 'Language', icon: 'language-outline', route: '/settings/language' },
  { label: 'Data & Storage', icon: 'server-outline', route: '/settings/storage' },
  // { label: 'Saved Messages', icon: 'bookmark-outline', route: '/settings/saved-messages' },
];

const ADVANCED_SETTINGS: SettingsRow[] = [
  { label: 'Developer Mode', icon: 'code-outline', route: '' },
];

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const logout = useAuthStore((s: any) => s.logout);
  const developerMode = useSettingsStore((s) => s.developerMode);
  const setDeveloperMode = useSettingsStore((s) => s.setDeveloperMode);

  const handleLogout = async () => {
    await logout();
    router.replace('/(auth)/login');
  };

  const renderSection = (title: string, items: SettingsRow[]) => (
    <View style={styles.section}>
      <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>
        {title}
      </Text>
      {items.map((item, index) => (
        <Pressable
          key={item.label}
          style={({ pressed }) => [
            styles.row,
            {
              backgroundColor: pressed
                ? themeColors.bgTertiary
                : themeColors.bgSecondary,
              borderTopLeftRadius: index === 0 ? 10 : 0,
              borderTopRightRadius: index === 0 ? 10 : 0,
              borderBottomLeftRadius: index === items.length - 1 ? 10 : 0,
              borderBottomRightRadius: index === items.length - 1 ? 10 : 0,
            },
          ]}
          onPress={() => router.push(item.route as any)}
        >
          <View style={[styles.rowIcon, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons
              name={item.icon}
              size={20}
              color={item.danger ? themeColors.danger : themeColors.textSecondary}
            />
          </View>
          <Text
            style={[
              styles.rowLabel,
              { color: item.danger ? themeColors.danger : themeColors.textPrimary },
            ]}
          >
            {item.label}
          </Text>
          <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
        </Pressable>
      ))}
    </View>
  );

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Settings',
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
        {/* Profile Card */}
        <Pressable
          style={[styles.profileCard, { backgroundColor: themeColors.bgSecondary }]}
          onPress={() => router.push('/settings/edit-profile')}
        >
          <Avatar
            name={user?.display_name || user?.username || 'User'}
            imageUrl={user?.avatar || undefined}
            size={56}
          />
          <View style={styles.profileInfo}>
            <Text style={[styles.profileName, { color: themeColors.textPrimary }]}>
              {user?.display_name || user?.username || 'User'}
            </Text>
            <Text style={[styles.profileTag, { color: themeColors.textMuted }]}>
              @{user?.username || '...'}
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
        </Pressable>

        {renderSection('USER SETTINGS', USER_SETTINGS)}
        {renderSection('APP SETTINGS', APP_SETTINGS)}

        {/* Advanced / Developer Mode */}
        <View style={styles.section}>
          <Text style={[styles.sectionHeader, { color: themeColors.textMuted }]}>
            ADVANCED
          </Text>
          <Pressable
            style={({ pressed }) => [
              styles.row,
              {
                backgroundColor: pressed ? themeColors.bgTertiary : themeColors.bgSecondary,
                borderRadius: 10,
              },
            ]}
            onPress={() => setDeveloperMode(!developerMode)}
          >
            <View style={[styles.rowIcon, { backgroundColor: themeColors.bgTertiary }]}>
              <Ionicons name="code-outline" size={20} color={themeColors.textSecondary} />
            </View>
            <Text style={[styles.rowLabel, { color: themeColors.textPrimary }]}>Developer Mode</Text>
            <View style={{
              width: 42, height: 24, borderRadius: 12,
              backgroundColor: developerMode ? themeColors.accentPrimary : themeColors.bgTertiary,
              justifyContent: 'center',
              paddingHorizontal: 2,
            }}>
              <View style={{
                width: 20, height: 20, borderRadius: 10, backgroundColor: '#fff',
                alignSelf: developerMode ? 'flex-end' : 'flex-start',
              }} />
            </View>
          </Pressable>
          {developerMode && (
            <Text style={[styles.devModeHint, { color: themeColors.textMuted }]}>
              Long-press items to copy their IDs
            </Text>
          )}
        </View>

        {/* Logout */}
        <View style={styles.section}>
          <Pressable
            style={({ pressed }) => [
              styles.row,
              styles.logoutRow,
              {
                backgroundColor: pressed
                  ? 'rgba(239,68,68,0.15)'
                  : themeColors.bgSecondary,
                borderRadius: 10,
              },
            ]}
            onPress={handleLogout}
          >
            <View style={[styles.rowIcon, { backgroundColor: 'rgba(239,68,68,0.12)' }]}>
              <Ionicons name="log-out-outline" size={20} color={themeColors.danger} />
            </View>
            <Text style={[styles.rowLabel, { color: themeColors.danger }]}>Log Out</Text>
          </Pressable>
        </View>

        {/* Version */}
        <Text style={[styles.version, { color: themeColors.textMuted }]}>
          Flicko Mobile v1.0.0
        </Text>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  profileCard: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: spacing.md,
    padding: spacing.md,
    borderRadius: 12,
    gap: spacing.sm,
  },
  profileInfo: {
    flex: 1,
  },
  profileName: {
    ...typography.headingM,
  },
  profileTag: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  section: {
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
  },
  sectionHeader: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
    marginLeft: spacing.sm,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET,
    gap: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.04)',
  },
  rowIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  rowLabel: {
    ...typography.body,
    flex: 1,
  },
  logoutRow: {
    borderBottomWidth: 0,
  },
  devModeHint: {
    ...typography.caption,
    marginHorizontal: spacing.md + spacing.sm,
    marginTop: spacing.xs,
  },
  version: {
    ...typography.caption,
    textAlign: 'center',
    marginTop: spacing.xl,
  },
});
