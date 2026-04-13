/**
 * Members List Screen
 *
 * Shows all server members with search, role badges, timeout/kick/ban actions.
 * Route: /server/[serverId]/settings/members
 * Requirements: Feature 17 (Member Management)
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
  Image,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as memberService from '@services/memberService';
import type { ServerMember } from '@services/memberService';
import { usePermissions } from '@hooks/usePermissions';
import { useAuthStore } from '@stores/authStore';
import { Permissions } from '@shared/constants/permissions';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function MembersScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const { can } = usePermissions(serverId!);

  const [search, setSearch] = useState('');

  const canKick = can(Permissions.KICK_MEMBERS);
  const canBan = can(Permissions.BAN_MEMBERS);
  const canTimeout = can(Permissions.MODERATE_MEMBERS);
  const canManageRoles = can(Permissions.MANAGE_ROLES);
  const canManageNicknames = can(Permissions.MANAGE_NICKNAMES);

  // Fetch members
  const { data: members = [], isLoading, refetch } = useQuery({
    queryKey: ['server-members', serverId, search],
    queryFn: () => memberService.getServerMembers(serverId!, { search: search || undefined, limit: 100 }),
    enabled: !!serverId,
  });

  // Kick
  const kickMutation = useMutation({
    mutationFn: (userId: string) => memberService.kickMember(serverId!, userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-members', serverId] });
    },
  });

  // Timeout
  const timeoutMutation = useMutation({
    mutationFn: ({ userId, seconds }: { userId: string; seconds: number }) =>
      memberService.timeoutMember(serverId!, userId, seconds),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-members', serverId] });
    },
  });

  const handleMemberPress = useCallback(
    (member: ServerMember) => {
      const actions: { text: string; onPress: () => void; style?: 'cancel' | 'destructive' }[] = [
        { text: 'View Profile', onPress: () => router.push(`/profile/${member.user_id}` as any) },
      ];

      if (canManageNicknames) {
        actions.push({
          text: 'Change Nickname',
          onPress: () => {
            Alert.prompt?.('Set Nickname', 'Enter new nickname (leave empty to clear)',
              (nick: string) => {
                memberService.setNickname(serverId!, member.user_id, nick || null);
                queryClient.invalidateQueries({ queryKey: ['server-members', serverId] });
              },
            );
          },
        });
      }

      if (canTimeout) {
        actions.push({
          text: member.timeout_until && new Date(member.timeout_until) > new Date()
            ? 'Remove Timeout'
            : 'Timeout',
          onPress: () => {
            if (member.timeout_until && new Date(member.timeout_until) > new Date()) {
              memberService.removeTimeout(serverId!, member.user_id).then(() =>
                queryClient.invalidateQueries({ queryKey: ['server-members', serverId] }),
              );
            } else {
              showTimeoutPicker(member);
            }
          },
        });
      }

      if (canKick) {
        actions.push({
          text: 'Kick',
          style: 'destructive',
          onPress: () => {
            Alert.alert('Kick Member', `Kick ${member.user?.username}?`, [
              { text: 'Cancel', style: 'cancel' },
              {
                text: 'Kick',
                style: 'destructive',
                onPress: () => kickMutation.mutate(member.user_id),
              },
            ]);
          },
        });
      }

      if (canBan) {
        actions.push({
          text: 'Ban',
          style: 'destructive',
          onPress: () => {
            Alert.alert('Ban Member', `Ban ${member.user?.username}? They will not be able to rejoin.`, [
              { text: 'Cancel', style: 'cancel' },
              {
                text: 'Ban',
                style: 'destructive',
                onPress: () => {
                  memberService.banMember(serverId!, member.user_id, useAuthStore.getState().user?.id ?? '', undefined).then(() =>
                    queryClient.invalidateQueries({ queryKey: ['server-members', serverId] }),
                  );
                },
              },
            ]);
          },
        });
      }

      actions.push({ text: 'Cancel', onPress: () => {}, style: 'cancel' });

      Alert.alert(
        member.nickname || member.user?.display_name || member.user?.username || 'Member',
        undefined,
        actions,
      );
    },
    [serverId, canKick, canBan, canTimeout, canManageNicknames, kickMutation, queryClient],
  );

  const showTimeoutPicker = (member: ServerMember) => {
    const durations = memberService.TIMEOUT_DURATIONS;
    Alert.alert(
      'Timeout Duration',
      `Timeout ${member.user?.username}`,
      [
        ...durations.map((d) => ({
          text: d.label,
          onPress: () => timeoutMutation.mutate({ userId: member.user_id, seconds: d.seconds }),
        })),
        { text: 'Cancel', style: 'cancel' as const },
      ],
    );
  };

  const renderMember = useCallback(
    ({ item }: { item: ServerMember }) => {
      const isTimedOut = item.timeout_until && new Date(item.timeout_until) > new Date();
      const displayName = item.nickname || item.user?.display_name || item.user?.username || 'Unknown';

      return (
        <Pressable
          style={[styles.memberRow, { backgroundColor: themeColors.cardBg }]}
          onPress={() => handleMemberPress(item)}
        >
          {/* Avatar */}
          <View style={[styles.avatar, { backgroundColor: themeColors.bgTertiary }]}>
            {item.user?.avatar_url ? (
              <Image source={{ uri: item.user.avatar_url }} style={styles.avatarImage} />
            ) : (
              <Text style={[styles.avatarText, { color: themeColors.textMuted }]}>
                {displayName[0]?.toUpperCase()}
              </Text>
            )}
          </View>

          <View style={styles.memberInfo}>
            <View style={styles.nameRow}>
              <Text style={[styles.displayName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {displayName}
              </Text>
              {isTimedOut && (
                <Ionicons name="time-outline" size={14} color={themeColors.warning} />
              )}
            </View>
            <Text style={[styles.username, { color: themeColors.textMuted }]} numberOfLines={1}>
              @{item.user?.username}
            </Text>
          </View>

          <Ionicons name="chevron-forward" size={16} color={themeColors.textMuted} />
        </Pressable>
      );
    },
    [themeColors, handleMemberPress],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}
        >
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Members ({members.length})
          </Text>
        </View>

        {/* Search */}
        <View style={[styles.searchRow, { backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Ionicons name="search" size={18} color={themeColors.textMuted} />
          <TextInput
            style={[styles.searchInput, { color: themeColors.textPrimary }]}
            placeholder="Search members..."
            placeholderTextColor={themeColors.textMuted}
            value={search}
            onChangeText={setSearch}
            autoCapitalize="none"
          />
          {search.length > 0 && (
            <Pressable onPress={() => setSearch('')} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
            </Pressable>
          )}
        </View>

        {/* Member list */}
        <FlatList
          data={members}
          renderItem={renderMember}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshing={false}
          onRefresh={() => refetch()}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>No members found</Text>
            )
          }
        />
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
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingM, marginLeft: spacing.sm },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    gap: spacing.sm,
  },
  searchInput: { flex: 1, ...typography.body, paddingVertical: spacing.xs },
  listContent: { padding: spacing.md, gap: spacing.sm },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    gap: spacing.md,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  avatarImage: { width: 40, height: 40, borderRadius: 20 },
  avatarText: { ...typography.headingS },
  memberInfo: { flex: 1 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  displayName: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  username: { ...typography.caption },
  loader: { marginTop: spacing.xxxxl },
  emptyText: { ...typography.body, textAlign: 'center', marginTop: spacing.xxxxl },
});
