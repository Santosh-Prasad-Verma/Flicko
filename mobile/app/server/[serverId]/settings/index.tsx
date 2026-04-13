/**
 * Server Settings Hub
 *
 * Overview settings screen with sections for: overview, roles, emoji,
 * moderation, audit log, integrations, members/bans.
 *
 * Route: /server/[serverId]/settings
 */
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { usePermissions } from '@hooks/usePermissions';
import { Permissions } from '@shared/constants/permissions';
import { useTheme } from '../../../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';

interface SettingsItem {
  id: string;
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  route: string;
  requiredPermission?: bigint;
  description?: string;
  danger?: boolean;
}

export default function ServerSettingsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const { can, isOwner } = usePermissions(serverId ?? '');
  const currentUser = useAuthStore((s: any) => s.user);

  const { data: server, isLoading: serverLoading } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('servers')
        .select('*')
        .eq('id', serverId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId,
  });

  // Only server owner can access settings
  const isServerOwner = server?.owner_id === currentUser?.id;
  if (!serverLoading && server && !isServerOwner && !isOwner) {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <View style={[styles.container, { backgroundColor: themeColors.bgPrimary, justifyContent: 'center', alignItems: 'center', padding: spacing.xl }]}>
          <Ionicons name="lock-closed-outline" size={48} color={themeColors.textMuted} />
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary, marginTop: spacing.md, textAlign: 'center' }]}>
            Access Denied
          </Text>
          <Text style={{ color: themeColors.textMuted, textAlign: 'center', marginTop: spacing.sm }}>
            Only the server owner can access server settings.
          </Text>
          <Pressable onPress={() => router.back()} style={{ marginTop: spacing.lg, paddingVertical: spacing.sm, paddingHorizontal: spacing.lg, backgroundColor: themeColors.accentPrimary, borderRadius: 8 }}>
            <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Go Back</Text>
          </Pressable>
        </View>
      </>
    );
  }

  const SETTINGS_SECTIONS: { title: string; items: SettingsItem[] }[] = [
    {
      title: 'Server',
      items: [
        {
          id: 'overview',
          icon: 'settings-outline',
          label: 'Overview',
          route: `/server/${serverId}/settings/overview`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Name, icon, description',
        },
        {
          id: 'channels',
          icon: 'list-outline',
          label: 'Channels',
          route: `/server/${serverId}/settings/channels`,
          requiredPermission: Permissions.MANAGE_CHANNELS,
          description: 'Create, edit, reorder channels',
        },
      ],
    },
    {
      title: 'User Management',
      items: [
        {
          id: 'roles',
          icon: 'shield-outline',
          label: 'Roles',
          route: `/server/${serverId}/settings/roles`,
          requiredPermission: Permissions.MANAGE_ROLES,
          description: 'Create and manage roles',
        },
        {
          id: 'members',
          icon: 'people-outline',
          label: 'Members',
          route: `/server/${serverId}/members`,
          description: 'View and manage members',
        },
        {
          id: 'bans',
          icon: 'ban-outline',
          label: 'Bans',
          route: `/server/${serverId}/settings/bans`,
          requiredPermission: Permissions.BAN_MEMBERS,
          description: 'View and manage bans',
        },
        {
          id: 'invites',
          icon: 'link-outline',
          label: 'Invites',
          route: `/server/${serverId}/settings/invites`,
          description: 'View active invites',
        },
      ],
    },
    {
      title: 'Content',
      items: [
        {
          id: 'emojis',
          icon: 'happy-outline',
          label: 'Emoji',
          route: `/server/${serverId}/settings/emojis`,
          requiredPermission: Permissions.MANAGE_EMOJIS_AND_STICKERS,
          description: 'Upload and manage custom emojis',
        },
        {
          id: 'stickers',
          icon: 'images-outline',
          label: 'Stickers',
          route: `/server/${serverId}/settings/stickers`,
          requiredPermission: Permissions.MANAGE_EMOJIS_AND_STICKERS,
          description: 'Upload and manage stickers',
        },
      ],
    },
    {
      title: 'Moderation',
      items: [
        {
          id: 'moderation',
          icon: 'shield-checkmark-outline',
          label: 'Safety Setup',
          route: `/server/${serverId}/settings/moderation`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Verification level, content filter',
        },
        {
          id: 'automod',
          icon: 'construct-outline',
          label: 'AutoMod',
          route: `/server/${serverId}/settings/automod`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Automated moderation rules',
        },
        {
          id: 'audit-log',
          icon: 'document-text-outline',
          label: 'Audit Log',
          route: `/server/${serverId}/settings/audit-log`,
          requiredPermission: Permissions.VIEW_AUDIT_LOG,
          description: 'View all administrative actions',
        },
      ],
    },
    {
      title: 'Integrations',
      items: [
        {
          id: 'bots',
          icon: 'hardware-chip-outline',
          label: 'Bots',
          route: `/server/${serverId}/settings/bots`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Manage server bots and automation',
        },
        {
          id: 'webhooks',
          icon: 'code-slash-outline',
          label: 'Webhooks',
          route: `/server/${serverId}/settings/webhooks`,
          requiredPermission: Permissions.MANAGE_WEBHOOKS,
          description: 'Manage incoming webhooks',
        },
        {
          id: 'events',
          icon: 'calendar-outline',
          label: 'Events',
          route: `/server/${serverId}/settings/events`,
          requiredPermission: Permissions.MANAGE_EVENTS,
          description: 'Create and manage scheduled events',
        },
      ],
    },
    {
      title: 'Community',
      items: [
        {
          id: 'onboarding',
          icon: 'rocket-outline',
          label: 'Onboarding',
          route: `/server/${serverId}/settings/onboarding`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Welcome screen and onboarding questions',
        },
        {
          id: 'templates',
          icon: 'copy-outline',
          label: 'Server Template',
          route: `/server/${serverId}/settings/templates`,
          requiredPermission: Permissions.MANAGE_GUILD,
          description: 'Save and share server layout',
        },
      ],
    },
    {
      title: 'Danger Zone',
      items: [
        {
          id: 'delete',
          icon: 'trash-outline',
          label: 'Delete Server',
          route: `/server/${serverId}/settings/delete`,
          description: 'Permanently delete this server',
          danger: true,
        },
      ],
    },
  ];

  // Filter items by permission
  const visibleSections = SETTINGS_SECTIONS.map((section) => ({
    ...section,
    items: section.items.filter((item) => {
      if (item.id === 'delete') return isOwner;
      if (!item.requiredPermission) return true;
      return can(item.requiredPermission) || isOwner;
    }),
  })).filter((s) => s.items.length > 0);

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + spacing.sm,
              backgroundColor: themeColors.bgSecondary,
              borderBottomColor: themeColors.border,
            },
          ]}
        >
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={[styles.backBtn, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
              Server Settings
            </Text>
            <Text style={[styles.serverName, { color: themeColors.textMuted }]} numberOfLines={1}>
              {server?.name}
            </Text>
          </View>
        </View>

        <ScrollView contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xl }}>
          {visibleSections.map((section) => (
            <View key={section.title} style={styles.section}>
              <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>
                {section.title.toUpperCase()}
              </Text>
              {section.items.map((item) => (
                <Pressable
                  key={item.id}
                  onPress={() => router.push(item.route as any)}
                  style={({ pressed }) => [
                    styles.settingsRow,
                    {
                      backgroundColor: pressed ? themeColors.bgTertiary : themeColors.bgSecondary,
                      borderBottomColor: themeColors.border,
                    },
                  ]}
                >
                  <Ionicons
                    name={item.icon}
                    size={20}
                    color={item.danger ? themeColors.danger : themeColors.textSecondary}
                    style={styles.rowIcon}
                  />
                  <View style={styles.rowInfo}>
                    <Text
                      style={[
                        styles.rowLabel,
                        { color: item.danger ? themeColors.danger : themeColors.textPrimary },
                      ]}
                    >
                      {item.label}
                    </Text>
                    {item.description && (
                      <Text style={[styles.rowDesc, { color: themeColors.textMuted }]}>
                        {item.description}
                      </Text>
                    )}
                  </View>
                  <Ionicons name="chevron-forward" size={16} color={themeColors.textMuted} />
                </Pressable>
              ))}
            </View>
          ))}
        </ScrollView>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerInfo: { flex: 1, marginLeft: spacing.sm },
  headerTitle: { ...typography.headingS },
  serverName: { ...typography.caption, marginTop: 2 },
  section: { marginTop: spacing.lg },
  sectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.sm,
  },
  settingsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  rowIcon: { marginRight: spacing.md },
  rowInfo: { flex: 1 },
  rowLabel: { ...typography.bodyM },
  rowDesc: { ...typography.caption, marginTop: 2 },
});
