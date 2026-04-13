/**
 * Bans Screen
 *
 * Lists banned members with unban functionality.
 * Route: /server/[serverId]/settings/bans
 * Requirements: Feature 17
 */
import React, { useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  ActivityIndicator,
  Image,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as memberService from '@services/memberService';
import type { BannedMember } from '@services/memberService';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function BansScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const { data: bans = [], isLoading, refetch } = useQuery({
    queryKey: ['server-bans', serverId],
    queryFn: () => memberService.getServerBans(serverId!),
    enabled: !!serverId,
  });

  const unbanMutation = useMutation({
    mutationFn: (userId: string) => memberService.unbanMember(serverId!, userId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-bans', serverId] }),
  });

  const handleUnban = useCallback(
    (ban: BannedMember) => {
      Alert.alert('Unban', `Unban ${ban.user?.username}?`, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Unban', onPress: () => unbanMutation.mutate(ban.user_id) },
      ]);
    },
    [unbanMutation],
  );

  const renderBan = useCallback(
    ({ item }: { item: BannedMember }) => (
      <View style={[styles.row, { backgroundColor: themeColors.cardBg }]}>
        <View style={[styles.avatar, { backgroundColor: themeColors.bgTertiary }]}>
          {item.user?.avatar_url ? (
            <Image source={{ uri: item.user.avatar_url }} style={styles.avatarImg} />
          ) : (
            <Text style={[styles.avatarText, { color: themeColors.textMuted }]}>
              {(item.user?.username || '?')[0].toUpperCase()}
            </Text>
          )}
        </View>
        <View style={styles.info}>
          <Text style={[styles.name, { color: themeColors.textPrimary }]}>{item.user?.username}</Text>
          {item.reason && (
            <Text style={[styles.reason, { color: themeColors.textMuted }]} numberOfLines={1}>
              {item.reason}
            </Text>
          )}
        </View>
        <Pressable
          onPress={() => handleUnban(item)}
          style={[styles.unbanBtn, { backgroundColor: themeColors.bgTertiary }]}
        >
          <Text style={[styles.unbanText, { color: themeColors.danger }]}>Unban</Text>
        </Pressable>
      </View>
    ),
    [themeColors, handleUnban],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Bans ({bans.length})
          </Text>
        </View>
        <FlatList
          data={bans}
          renderItem={renderBan}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          refreshing={false}
          onRefresh={() => refetch()}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.empty, { color: themeColors.textMuted }]}>No bans</Text>
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
  headerTitle: { ...typography.headingM, marginLeft: spacing.sm },
  list: { padding: spacing.md, gap: spacing.sm },
  row: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, borderRadius: borderRadius.md, gap: spacing.md },
  avatar: { width: 36, height: 36, borderRadius: 18, justifyContent: 'center', alignItems: 'center', overflow: 'hidden' },
  avatarImg: { width: 36, height: 36, borderRadius: 18 },
  avatarText: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  info: { flex: 1 },
  name: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  reason: { ...typography.caption, marginTop: 2 },
  unbanBtn: { paddingHorizontal: spacing.md, paddingVertical: spacing.xs, borderRadius: borderRadius.sm },
  unbanText: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  loader: { marginTop: spacing.xxxxl },
  empty: { ...typography.body, textAlign: 'center', marginTop: spacing.xxxxl },
});
