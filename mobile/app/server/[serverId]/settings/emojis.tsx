/**
 * Emoji Settings Screen
 *
 * Upload and manage custom server emojis with role restrictions,
 * usage stats, and Flicko Plus cross-server gating.
 * Route: /server/[serverId]/settings/emojis
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  ActivityIndicator,
  Switch,
} from 'react-native';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { Image } from 'expo-image';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import { EmojiUpload } from '../../../../components/servers/EmojiUpload';
import { useSubscriptionStore } from '@stores/subscriptionStore';

interface ServerEmoji {
  id: string;
  server_id: string;
  name: string;
  image_url: string;
  animated: boolean;
  creator_id: string;
  created_at: string;
  usage_count?: number;
  allowed_roles?: string[];
  creator?: { username: string };
}

interface ServerRole {
  id: string;
  name: string;
  color: string | null;
}

export default function EmojisScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const { limits, isNitro } = useSubscriptionStore();

  const [showUpload, setShowUpload] = useState(false);
  const [selectedEmoji, setSelectedEmoji] = useState<ServerEmoji | null>(null);

  const { data: emojis = [], isLoading } = useQuery({
    queryKey: ['server-emojis', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('server_emojis')
        .select('*, creator:profiles!creator_id(username)')
        .eq('server_id', serverId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data ?? []) as ServerEmoji[];
    },
    enabled: !!serverId,
  });

  // Fetch server roles for restriction picker
  const { data: roles = [] } = useQuery({
    queryKey: ['server-roles', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('server_roles')
        .select('id, name, color')
        .eq('server_id', serverId)
        .order('position', { ascending: false });
      if (error) throw error;
      return (data ?? []) as ServerRole[];
    },
    enabled: !!serverId,
  });

  const deleteMutation = useMutation({
    mutationFn: async (emojiId: string) => {
      const { error } = await supabase.from('server_emojis').delete().eq('id', emojiId);
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-emojis', serverId] }),
  });

  const updateRolesMutation = useMutation({
    mutationFn: async ({ emojiId, allowedRoles }: { emojiId: string; allowedRoles: string[] }) => {
      const { error } = await supabase
        .from('server_emojis')
        .update({ allowed_roles: allowedRoles })
        .eq('id', emojiId);
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-emojis', serverId] }),
  });

  const handleDelete = useCallback((emoji: ServerEmoji) => {
    Alert.alert('Delete Emoji', `Delete :${emoji.name}:?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteMutation.mutate(emoji.id) },
    ]);
  }, [deleteMutation]);

  const handleToggleRole = useCallback((emoji: ServerEmoji, roleId: string) => {
    const current = emoji.allowed_roles ?? [];
    const updated = current.includes(roleId)
      ? current.filter((r) => r !== roleId)
      : [...current, roleId];
    updateRolesMutation.mutate({ emojiId: emoji.id, allowedRoles: updated });
  }, [updateRolesMutation]);

  const totalStatic = emojis.filter((e) => !e.animated).length;
  const totalAnimated = emojis.filter((e) => e.animated).length;
  const emojiLimit = limits.emojiUploadLimit;
  const canUploadMore = emojis.length < emojiLimit;

  const renderEmoji = useCallback(
    ({ item, index }: { item: ServerEmoji; index: number }) => (
      <Animated.View entering={FadeInDown.delay(index * 30).duration(200)}>
        <Pressable
          onPress={() => setSelectedEmoji(selectedEmoji?.id === item.id ? null : item)}
          style={[styles.emojiRow, { backgroundColor: themeColors.bgSecondary }]}
        >
          <Image
            source={{ uri: item.image_url }}
            style={styles.emojiImage}
            contentFit="contain"
            transition={200}
          />
          <View style={styles.emojiInfo}>
            <Text style={[styles.emojiName, { color: themeColors.textPrimary }]}>:{item.name}:</Text>
            <View style={styles.emojiMetaRow}>
              <Text style={[styles.emojiMeta, { color: themeColors.textMuted }]}>
                {item.animated ? 'Animated' : 'Static'}
                {item.creator ? ` · by ${item.creator.username}` : ''}
              </Text>
              {/* Usage count badge */}
              <View style={[styles.usageBadge, { backgroundColor: themeColors.bgTertiary }]}>
                <Ionicons name="bar-chart-outline" size={10} color={themeColors.textMuted} />
                <Text style={[styles.usageText, { color: themeColors.textMuted }]}>
                  {item.usage_count ?? 0}
                </Text>
              </View>
              {/* Role restricted indicator */}
              {(item.allowed_roles?.length ?? 0) > 0 && (
                <View style={[styles.restrictedBadge, { backgroundColor: '#FAA61A20' }]}>
                  <Ionicons name="lock-closed" size={10} color="#FAA61A" />
                  <Text style={[styles.restrictedText, { color: '#FAA61A' }]}>
                    {item.allowed_roles!.length} role{item.allowed_roles!.length !== 1 ? 's' : ''}
                  </Text>
                </View>
              )}
            </View>
          </View>
          <Pressable onPress={() => handleDelete(item)} hitSlop={8} style={styles.deleteBtn}>
            <Ionicons name="trash-outline" size={16} color={themeColors.danger} />
          </Pressable>
        </Pressable>

        {/* Expanded role restriction panel */}
        {selectedEmoji?.id === item.id && (
          <Animated.View
            entering={FadeIn.duration(150)}
            style={[styles.rolePanel, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Text style={[styles.rolePanelTitle, { color: themeColors.textMuted }]}>
              ROLE RESTRICTIONS
            </Text>
            <Text style={[styles.rolePanelHint, { color: themeColors.textMuted }]}>
              {(item.allowed_roles?.length ?? 0) === 0
                ? 'Everyone can use this emoji'
                : 'Only selected roles can use this emoji'}
            </Text>
            {roles.map((role) => {
              const isAllowed = item.allowed_roles?.includes(role.id) ?? false;
              return (
                <View key={role.id} style={styles.roleRow}>
                  <View
                    style={[styles.roleColor, { backgroundColor: role.color || themeColors.textMuted }]}
                  />
                  <Text style={[styles.roleName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                    {role.name}
                  </Text>
                  <Switch
                    value={isAllowed}
                    onValueChange={() => handleToggleRole(item, role.id)}
                    trackColor={{ false: themeColors.bgSecondary, true: themeColors.accentPrimary + '60' }}
                    thumbColor={isAllowed ? themeColors.accentPrimary : themeColors.textMuted}
                  />
                </View>
              );
            })}
            {roles.length === 0 && (
              <Text style={[styles.noRoles, { color: themeColors.textMuted }]}>
                No roles configured for this server
              </Text>
            )}
          </Animated.View>
        )}
      </Animated.View>
    ),
    [themeColors, handleDelete, selectedEmoji, roles, handleToggleRole],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Emoji ({emojis.length})
          </Text>
          <Pressable
            onPress={() => {
              if (!canUploadMore) {
                Alert.alert(
                  'Emoji Limit Reached',
                  `You've reached the ${emojiLimit} emoji limit. ${!isNitro ? 'Upgrade to Flicko Plus for more slots!' : 'Server boosts can increase the limit.'}`,
                );
                return;
              }
              setShowUpload(true);
            }}
            hitSlop={8}
            style={styles.addBtn}
          >
            <Ionicons name="add" size={24} color={canUploadMore ? themeColors.accentPrimary : themeColors.textMuted} />
          </Pressable>
        </View>

        {/* Stats bar */}
        <View style={[styles.statsBar, { backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>{totalStatic}</Text>
            <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>Static</Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: themeColors.border }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>{totalAnimated}</Text>
            <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>Animated</Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: themeColors.border }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: themeColors.textPrimary }]}>
              {emojis.length}/{emojiLimit}
            </Text>
            <Text style={[styles.statLabel, { color: themeColors.textMuted }]}>Slots</Text>
          </View>
          {!isNitro && (
            <>
              <View style={[styles.statDivider, { backgroundColor: themeColors.border }]} />
              <Pressable
                onPress={() => router.push('/flicko-plus')}
                style={[styles.flickoBadge, { backgroundColor: '#5865F220' }]}
              >
                <Text style={styles.flickoIcon}>🚀</Text>
                <Text style={[styles.flickoText, { color: '#5865F2' }]}>Get Flicko Plus</Text>
              </Pressable>
            </>
          )}
        </View>

        {/* Cross-server emoji info */}
        {!isNitro && (
          <Animated.View
            entering={FadeIn.duration(200)}
            style={[styles.crossServerBanner, { backgroundColor: '#5865F210', borderColor: '#5865F240' }]}
          >
            <Ionicons name="globe-outline" size={16} color="#5865F2" />
            <Text style={[styles.crossServerText, { color: themeColors.textMuted }]}>
              Flicko Plus subscribers can use custom emojis across all servers
            </Text>
          </Animated.View>
        )}

        {isLoading ? (
          <View style={styles.centered}>
            <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          </View>
        ) : emojis.length === 0 ? (
          <View style={styles.centered}>
            <Ionicons name="happy-outline" size={48} color={themeColors.textMuted} />
            <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>No custom emojis</Text>
            <Text style={[styles.emptyDesc, { color: themeColors.textMuted }]}>
              Upload custom emojis for your server
            </Text>
            <Pressable
              onPress={() => setShowUpload(true)}
              style={[styles.uploadBtn, { backgroundColor: themeColors.accentPrimary }]}
            >
              <Ionicons name="cloud-upload-outline" size={18} color="#fff" />
              <Text style={styles.uploadBtnText}>Upload Emoji</Text>
            </Pressable>
          </View>
        ) : (
          <FlatList
            data={emojis}
            renderItem={renderEmoji}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{ padding: spacing.md, paddingBottom: insets.bottom + 40 }}
          />
        )}

        {/* Enhanced Emoji Upload Flow */}
        <EmojiUpload
          visible={showUpload}
          onClose={() => setShowUpload(false)}
          serverId={serverId || ''}
          onUploadComplete={() => {
            queryClient.invalidateQueries({ queryKey: ['server-emojis', serverId] });
          }}
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
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  addBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  emptyTitle: { fontSize: 18, fontFamily: 'gg-sans-semibold', marginTop: spacing.md },
  emptyDesc: { fontSize: 14, marginTop: spacing.xs, textAlign: 'center' },
  uploadBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    marginTop: spacing.lg,
  },
  uploadBtnText: { color: '#fff', fontFamily: 'gg-sans-semibold', fontSize: 15 },
  emojiRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.xs,
  },
  emojiImage: { width: 40, height: 40 },
  emojiInfo: { flex: 1, marginLeft: spacing.md },
  emojiName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  emojiMeta: { fontSize: 12, marginTop: 2 },
  emojiMetaRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, marginTop: 2, flexWrap: 'wrap' },
  deleteBtn: { padding: 8 },
  // Usage & Restriction badges
  usageBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.sm,
  },
  usageText: { fontSize: 10, fontFamily: 'gg-sans-semibold' },
  restrictedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.sm,
  },
  restrictedText: { fontSize: 10, fontFamily: 'gg-sans-semibold' },
  // Role panel
  rolePanel: {
    marginHorizontal: spacing.xs,
    marginBottom: spacing.sm,
    padding: spacing.md,
    borderRadius: borderRadius.md,
  },
  rolePanelTitle: { fontSize: 11, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, marginBottom: spacing.xs },
  rolePanelHint: { fontSize: 12, marginBottom: spacing.sm },
  roleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.xs,
    gap: spacing.sm,
  },
  roleColor: { width: 12, height: 12, borderRadius: 6 },
  roleName: { flex: 1, fontSize: 14 },
  noRoles: { fontSize: 12, fontStyle: 'italic', paddingVertical: spacing.xs },
  // Stats bar
  statsBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    gap: spacing.sm,
  },
  statItem: { alignItems: 'center', flex: 1 },
  statValue: { fontSize: 16, fontFamily: 'gg-sans-bold' },
  statLabel: { fontSize: 10, marginTop: 2 },
  statDivider: { width: 1, height: 24 },
  flickoBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
  },
  flickoIcon: { fontSize: 14 },
  flickoText: { fontSize: 12, fontFamily: 'gg-sans-bold' },
  // Cross-server banner
  crossServerBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginHorizontal: spacing.md,
    marginTop: spacing.sm,
    padding: spacing.sm,
    borderRadius: borderRadius.md,
    borderWidth: 1,
  },
  crossServerText: { fontSize: 12, flex: 1 },
  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: spacing.lg,
    paddingBottom: 40,
  },
  modalTitle: { ...typography.headingS, marginBottom: spacing.lg },
  imagePicker: {
    width: 128,
    height: 128,
    borderRadius: borderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    overflow: 'hidden',
  },
  imagePreview: { width: 128, height: 128 },
  imagePickerText: { fontSize: 12, marginTop: spacing.xs },
  hint: { fontSize: 12, textAlign: 'center', marginTop: spacing.sm },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
    marginTop: spacing.lg,
  },
  input: {
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  modalBtn: {
    flex: 1,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
