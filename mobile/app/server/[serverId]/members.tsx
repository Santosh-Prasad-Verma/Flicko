/**
 * Server Member List Screen
 *
 * Shows all members of a server grouped by role/status.
 * Route: /server/[serverId]/members
 */
import React, { useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SectionList,
  Pressable,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../services/supabase';
import { Avatar } from '../../../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useTheme } from '../../../hooks/useTheme';

interface ServerMember {
  id: string;
  user_id: string;
  roles: string[];
  profile: {
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
    status?: string;
  };
  role_label: string; // computed: 'Owner' | 'Admin' | 'Member'
}

export default function ServerMembersScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const { data: members, isLoading } = useQuery({
    queryKey: ['server-members', serverId],
    queryFn: async () => {
      // Fetch server to know owner
      const { data: server } = await supabase
        .from('servers')
        .select('owner_id')
        .eq('id', serverId!)
        .single();

      // Fetch all admin role IDs for this server
      const { data: adminRoles } = await supabase
        .from('roles')
        .select('id')
        .eq('server_id', serverId!)
        .ilike('name', '%admin%');
      const adminRoleIds = new Set((adminRoles ?? []).map((r: any) => r.id));

      // Fetch members with profiles
      const { data, error } = await supabase
        .from('server_members')
        .select('id, user_id, roles, profile:profiles!user_id(id, username, display_name, avatar_url:avatar, status)')
        .eq('server_id', serverId!);
      if (error) throw error;

      return (data ?? []).map((m: any) => {
        let role_label = 'Member';
        if (server?.owner_id === m.user_id) {
          role_label = 'Owner';
        } else if ((m.roles ?? []).some((rid: string) => adminRoleIds.has(rid))) {
          role_label = 'Admin';
        }
        return { ...m, role_label } as ServerMember;
      });
    },
    enabled: !!serverId,
  });

  const sections = useMemo(() => {
    if (!members || members.length === 0) return [];

    const grouped: Record<string, ServerMember[]> = {};
    for (const m of members) {
      const role = m.role_label;
      if (!grouped[role]) grouped[role] = [];
      grouped[role].push(m);
    }

    const order = ['Owner', 'Admin', 'Member'];
    return order
      .filter((role) => grouped[role]?.length > 0)
      .map((role) => ({
        title: `${role} — ${grouped[role].length}`,
        data: grouped[role],
      }));
  }, [members]);

  const renderMember = ({ item }: { item: ServerMember }) => {
    const profile = Array.isArray(item.profile) ? item.profile[0] : item.profile;
    const displayName = profile?.display_name || profile?.username || 'Unknown';
    const isOnline = profile?.status === 'online' || profile?.status === 'idle';

    return (
      <Pressable
        style={({ pressed }) => [
          styles.memberRow,
          pressed && { backgroundColor: themeColors.bgTertiary },
        ]}
        onPress={() => router.push(`/profile/${item.user_id}`)}
      >
        <Avatar
          name={displayName}
          imageUrl={profile?.avatar_url || undefined}
          size={36}
        />
        <View style={styles.memberInfo}>
          <Text
            style={[
              styles.memberName,
              {
                color: item.role_label === 'Owner'
                  ? themeColors.accentPrimary
                  : themeColors.textPrimary,
              },
            ]}
            numberOfLines={1}
          >
            {displayName}
          </Text>
          <View style={styles.statusRow}>
            <View
              style={[
                styles.statusDot,
                {
                  backgroundColor: isOnline
                    ? (profile?.status === 'idle' ? '#faa61a' : '#43b581')
                    : '#72767d',
                },
              ]}
            />
            <Text style={[styles.memberStatus, { color: themeColors.textMuted }]}>
              {profile?.status === 'online'
                ? 'Online'
                : profile?.status === 'idle'
                  ? 'Idle'
                  : 'Offline'}
            </Text>
          </View>
        </View>
        {item.role_label === 'Owner' && (
          <Ionicons name="shield" size={16} color={themeColors.accentPrimary} />
        )}
      </Pressable>
    );
  };

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
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
          <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.iconBtn, { backgroundColor: themeColors.bgTertiary }]}> 
            <Ionicons name="arrow-back" size={22} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Members</Text>
          <Pressable
            onPress={() => router.push(`/server/${serverId}/settings/invites` as any)}
            hitSlop={12}
            style={[styles.iconBtn, { backgroundColor: themeColors.bgTertiary }]}
            accessibilityLabel="Invite members"
          >
            <Ionicons name="person-add-outline" size={20} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        {isLoading ? (
          <View style={styles.center}>
            <ActivityIndicator color={themeColors.accentPrimary} size="large" />
          </View>
        ) : (
          <SectionList
            sections={sections}
            renderItem={renderMember}
            renderSectionHeader={({ section }) => (
              <View style={[styles.sectionHeader, { backgroundColor: themeColors.bgPrimary }]}>
                <Text style={[styles.sectionHeaderText, { color: themeColors.textMuted }]}>
                  {section.title}
                </Text>
              </View>
            )}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
            stickySectionHeadersEnabled
          />
        )}
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  iconBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sectionHeader: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  sectionHeaderText: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  memberInfo: {
    flex: 1,
  },
  memberName: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  memberStatus: {
    ...typography.caption,
    marginTop: 1,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 1,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
});
