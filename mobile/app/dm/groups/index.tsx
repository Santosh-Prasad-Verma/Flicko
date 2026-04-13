/**
 * Group DM List Screen
 *
 * Shows group DM conversations with create functionality.
 * Route: /dm/groups
 * Requirements: Feature 14 (Group DMs)
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as groupDMService from '@services/groupDMService';
import type { GroupDM } from '@services/groupDMService';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useTheme } from '../../../hooks/useTheme';

export default function GroupDMsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);

  const { data: groups = [], isLoading, refetch } = useQuery({
    queryKey: ['group-dms', user?.id],
    queryFn: () => groupDMService.getGroupDMs(user?.id!),
    enabled: !!user?.id,
  });

  const handleGroupPress = useCallback((group: GroupDM) => {
    router.push(`/dm/group/${group.id}` as any);
  }, []);

  const renderGroup = useCallback(
    ({ item }: { item: GroupDM }) => {
      const participantNames = (item.participants ?? [])
        .filter((p) => p.user_id !== user?.id)
        .map((p) => p.display_name || p.username)
        .join(', ');
      const displayName = item.name || participantNames || 'Group DM';
      const memberCount = item.participants?.length ?? 0;

      return (
        <Pressable
          style={[styles.groupRow, { backgroundColor: themeColors.cardBg }]}
          onPress={() => handleGroupPress(item)}
        >
          <View style={[styles.groupIcon, { backgroundColor: themeColors.bgTertiary }]}>
            <Ionicons name="people" size={20} color={themeColors.textSecondary} />
          </View>
          <View style={styles.groupInfo}>
            <Text style={[styles.groupName, { color: themeColors.textPrimary }]} numberOfLines={1}>
              {displayName}
            </Text>
            <Text style={[styles.groupMeta, { color: themeColors.textMuted }]}>
              {memberCount} members
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={16} color={themeColors.textMuted} />
        </Pressable>
      );
    },
    [themeColors, user, handleGroupPress],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Group Messages</Text>
          <Pressable
            onPress={() => router.push('/dm/groups/create' as any)}
            hitSlop={8}
            style={styles.addBtn}
          >
            <Ionicons name="add-circle-outline" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        <FlatList
          data={groups}
          renderItem={renderGroup}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          refreshing={false}
          onRefresh={() => refetch()}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <View style={styles.emptyState}>
                <Ionicons name="people-outline" size={48} color={themeColors.textMuted} />
                <Text style={[styles.emptyText, { color: themeColors.textSecondary }]}>
                  No group conversations yet
                </Text>
              </View>
            )
          }
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.md, paddingBottom: spacing.md, borderBottomWidth: 1 },
  backBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, justifyContent: 'center', alignItems: 'center' },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  addBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, justifyContent: 'center', alignItems: 'center' },
  list: { padding: spacing.md, gap: spacing.sm },
  groupRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, borderRadius: borderRadius.md, gap: spacing.md },
  groupIcon: { width: 44, height: 44, borderRadius: 22, justifyContent: 'center', alignItems: 'center' },
  groupInfo: { flex: 1 },
  groupName: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  groupMeta: { ...typography.caption, marginTop: 2 },
  loader: { marginTop: spacing.xxxxl },
  emptyState: { alignItems: 'center', marginTop: spacing.xxxxl * 2, gap: spacing.md },
  emptyText: { ...typography.body },
});
