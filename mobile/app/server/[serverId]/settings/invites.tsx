/**
 * Invites Screen
 *
 * Lists active invites with create/delete.
 * Route: /server/[serverId]/settings/invites
 * Requirements: Feature 17
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
  Share,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as memberService from '@services/memberService';
import type { ServerInvite } from '@services/memberService';
import { useAuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function InvitesScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);

  const { data: invites = [], isLoading, refetch } = useQuery({
    queryKey: ['server-invites', serverId],
    queryFn: () => memberService.getServerInvites(serverId!),
    enabled: !!serverId,
  });

  const createMutation = useMutation({
    mutationFn: () => memberService.createInvite(serverId!, user?.id!, { expiresIn: 86400 }),
    onSuccess: (invite) => {
      queryClient.invalidateQueries({ queryKey: ['server-invites', serverId] });
      Share.share({ message: `Join my server: flicko.app/invite/${invite.code}` });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: memberService.deleteInvite,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-invites', serverId] }),
  });

  const handleShare = (invite: ServerInvite) => {
    Share.share({ message: `flicko.app/invite/${invite.code}` });
  };

  const handleDelete = (invite: ServerInvite) => {
    Alert.alert('Delete Invite', `Delete invite ${invite.code}?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteMutation.mutate(invite.id) },
    ]);
  };

  const renderInvite = useCallback(
    ({ item }: { item: ServerInvite }) => {
      const expired = item.expires_at && new Date(item.expires_at) < new Date();
      return (
        <View style={[styles.row, { backgroundColor: themeColors.cardBg, opacity: expired ? 0.5 : 1 }]}>
          <View style={styles.info}>
            <Text style={[styles.code, { color: themeColors.accentPrimary }]}>{item.code}</Text>
            <Text style={[styles.meta, { color: themeColors.textMuted }]}>
              {item.uses}{item.max_uses ? `/${item.max_uses}` : ''} uses
              {item.creator ? ` · by ${item.creator.display_name || item.creator.username}` : ''}
              {expired ? ' · Expired' : ''}
            </Text>
          </View>
          <Pressable onPress={() => handleShare(item)} hitSlop={8} style={styles.actionBtn}>
            <Ionicons name="share-outline" size={18} color={themeColors.textSecondary} />
          </Pressable>
          <Pressable onPress={() => handleDelete(item)} hitSlop={8} style={styles.actionBtn}>
            <Ionicons name="trash-outline" size={18} color={themeColors.danger} />
          </Pressable>
        </View>
      );
    },
    [themeColors],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.backBtn, { backgroundColor: themeColors.bgTertiary }]}> 
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Invites</Text>
          <Pressable onPress={() => createMutation.mutate()} hitSlop={8} style={[styles.createBtn, { backgroundColor: themeColors.bgTertiary }]}> 
            {createMutation.isPending ? (
              <ActivityIndicator size="small" color={themeColors.accentPrimary} />
            ) : (
              <Ionicons name="add-circle-outline" size={24} color={themeColors.accentPrimary} />
            )}
          </Pressable>
        </View>
        <FlatList
          data={invites}
          renderItem={renderInvite}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          refreshing={false}
          onRefresh={() => refetch()}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <Text style={[styles.empty, { color: themeColors.textMuted }]}>No invites</Text>
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
  backBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  createBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  list: { padding: spacing.md, gap: spacing.sm },
  row: { flexDirection: 'row', alignItems: 'center', padding: spacing.md, borderRadius: borderRadius.md, gap: spacing.md },
  info: { flex: 1 },
  code: { ...typography.bodyBold },
  meta: { ...typography.caption, marginTop: 2 },
  actionBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, justifyContent: 'center', alignItems: 'center' },
  loader: { marginTop: spacing.xxxxl },
  empty: { ...typography.body, textAlign: 'center', marginTop: spacing.xxxxl },
});
