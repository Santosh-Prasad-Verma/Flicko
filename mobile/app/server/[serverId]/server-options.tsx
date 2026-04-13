/**
 * Server Options Screen (Member View)
 *
 * Shown when a non-owner member taps the three-dot (⋮) button in a server.
 * Route: /server/[serverId]/server-options
 */
import React, { useCallback, useState, useEffect, useRef } from 'react';
import { notifyMemberLeave } from '@shared/services/botService';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Alert,
  ActivityIndicator,
  Modal as RNModal,
  Animated,
  Dimensions,
  TouchableWithoutFeedback,
} from 'react-native';
import { Image } from 'expo-image';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../../../services/supabase';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { Avatar } from '../../../components/ui/Avatar';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useTheme } from '../../../hooks/useTheme';

const { height: SCREEN_H } = Dimensions.get('window');

// ─── Leave Confirmation Sheet ──────────────────────────────────────────────
interface LeaveSheetProps {
  visible: boolean;
  serverName?: string;
  serverIcon?: string;
  isPending: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

function LeaveConfirmSheet({
  visible,
  serverName,
  serverIcon,
  isPending,
  onConfirm,
  onCancel,
}: LeaveSheetProps) {
  const { themeColors } = useTheme();
  const insets = useSafeAreaInsets();

  const slideAnim = useRef(new Animated.Value(SCREEN_H)).current;
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      slideAnim.setValue(SCREEN_H);
      fadeAnim.setValue(0);
      Animated.parallel([
        Animated.timing(fadeAnim, { toValue: 1, duration: 220, useNativeDriver: true }),
        Animated.spring(slideAnim, {
          toValue: 0,
          tension: 65,
          friction: 11,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      Animated.parallel([
        Animated.timing(fadeAnim, { toValue: 0, duration: 180, useNativeDriver: true }),
        Animated.timing(slideAnim, { toValue: SCREEN_H, duration: 200, useNativeDriver: true }),
      ]).start();
    }
  }, [visible]);

  return (
    <RNModal
      visible={visible}
      transparent
      animationType="none"
      statusBarTranslucent
      onRequestClose={onCancel}
    >
      <TouchableWithoutFeedback onPress={onCancel}>
        <Animated.View style={[styles.sheetBackdrop, { opacity: fadeAnim }]} />
      </TouchableWithoutFeedback>

      <Animated.View
        style={[
          styles.sheetPanel,
          {
            backgroundColor: themeColors.bgSecondary,
            paddingBottom: Math.max(insets.bottom, spacing.xl),
            transform: [{ translateY: slideAnim }],
          },
        ]}
      >
        <View style={styles.sheetHandle}>
          <View style={[styles.sheetHandleBar, { backgroundColor: themeColors.textMuted }]} />
        </View>

        <View style={[styles.sheetIconWrap, { borderColor: themeColors.border }]}>
          <Avatar
            name={serverName ?? '?'}
            imageUrl={serverIcon ?? undefined}
            size={80}
          />
        </View>

        <Text style={[styles.sheetTitle, { color: themeColors.textPrimary }]}>
          Leave Server
        </Text>

        <View style={[styles.sheetServerPill, { backgroundColor: themeColors.bgTertiary }]}>
          <Ionicons name="server-outline" size={14} color={themeColors.textMuted} />
          <Text
            style={[styles.sheetServerPillText, { color: themeColors.textSecondary }]}
            numberOfLines={1}
          >
            {serverName ?? 'this server'}
          </Text>
        </View>

        <View style={[styles.sheetWarningBox, { backgroundColor: themeColors.danger + '18', borderColor: themeColors.danger + '44' }]}>
          <Ionicons name="warning-outline" size={18} color={themeColors.danger} style={{ marginTop: 1 }} />
          <Text style={[styles.sheetWarningText, { color: themeColors.textSecondary }]}>
            You won't be able to rejoin{' '}
            <Text style={{ fontFamily: 'gg-sans-bold', color: themeColors.textPrimary }}>
              {serverName ?? 'this server'}
            </Text>{' '}
            unless someone sends you a new invite.
          </Text>
        </View>

        <Pressable
          style={({ pressed }) => [
            styles.sheetLeaveBtn,
            { backgroundColor: pressed ? '#c0392b' : themeColors.danger },
          ]}
          onPress={onConfirm}
          disabled={isPending}
        >
          {isPending ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="exit-outline" size={18} color="#fff" />
              <Text style={styles.sheetLeaveBtnText}>
                Leave {serverName ? `"${serverName}"` : 'Server'}
              </Text>
            </>
          )}
        </Pressable>

        <Pressable
          style={({ pressed }) => [
            styles.sheetCancelBtn,
            { backgroundColor: pressed ? themeColors.bgPrimary : themeColors.bgTertiary },
          ]}
          onPress={onCancel}
          disabled={isPending}
        >
          <Text style={[styles.sheetCancelBtnText, { color: themeColors.textPrimary }]}>
            Cancel
          </Text>
        </Pressable>
      </Animated.View>
    </RNModal>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────
export default function ServerOptionsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);
  const queryClient = useQueryClient();
  const [showLeaveModal, setShowLeaveModal] = useState(false);

  const cachedServer = queryClient.getQueryData<any>(['server', serverId]);

  const { data: server } = useQuery({
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
    initialData: cachedServer ?? undefined,
    staleTime: 30_000,
  });

  const leaveMutation = useMutation({
    mutationFn: async () => {
      if (!user?.id) throw new Error('Not logged in');
      await notifyMemberLeave(serverId);
      const { error } = await supabase
        .from('server_members')
        .delete()
        .eq('server_id', serverId)
        .eq('user_id', user.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      queryClient.invalidateQueries({ queryKey: ['server-membership', serverId, user?.id] });
      router.replace('/(tabs)' as any);
    },
    onError: (err: any) =>
      Alert.alert('Error', err.message || 'Failed to leave server'),
  });

  const handleConfirmLeave = useCallback(() => {
    setShowLeaveModal(false);
    setTimeout(() => leaveMutation.mutate(), 250);
  }, [leaveMutation]);

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgSecondary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: '',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="close" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />

      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Server identity card */}
        <View style={[styles.serverCard, { backgroundColor: themeColors.bgSecondary }]}>
          {server?.banner ? (
            <Image
              source={{ uri: server.banner }}
              style={styles.banner}
              contentFit="cover"
              transition={300}
              autoplay
              cachePolicy="disk"
            />
          ) : (
            <View style={[styles.banner, { backgroundColor: themeColors.accentPrimary + '44' }]} />
          )}
          <View style={styles.cardBody}>
            <Avatar
              name={server?.name ?? '?'}
              imageUrl={server?.icon ?? undefined}
              size={52}
            />
            <View style={styles.cardText}>
              <Text style={[styles.serverName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {server?.name ?? 'Loading…'}
              </Text>
              {server?.description ? (
                <Text
                  style={[styles.serverDesc, { color: themeColors.textMuted }]}
                  numberOfLines={2}
                >
                  {server.description}
                </Text>
              ) : null}
            </View>
          </View>
        </View>

        {/* Options */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>SERVER OPTIONS</Text>
        <View style={[styles.optionGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <Pressable
            style={({ pressed }) => [
              styles.optionRow,
              pressed && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => router.replace(`/server/${serverId}/members` as any)}
            accessibilityRole="button"
          >
            <View style={[styles.iconWrap, { backgroundColor: themeColors.accentPrimary + '22' }]}>
              <Ionicons name="people-outline" size={20} color={themeColors.accentPrimary} />
            </View>
            <View style={styles.optionText}>
              <Text style={[styles.optionTitle, { color: themeColors.textPrimary }]}>View Members</Text>
              <Text style={[styles.optionSub, { color: themeColors.textMuted }]}>See who's in this server</Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
          </Pressable>

          <View style={[styles.divider, { backgroundColor: themeColors.border }]} />

          <Pressable
            style={({ pressed }) => [
              styles.optionRow,
              pressed && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => router.replace(`/server/${serverId}/settings/invites` as any)}
            accessibilityRole="button"
          >
            <View style={[styles.iconWrap, { backgroundColor: '#5865F222' }]}>
              <Ionicons name="link-outline" size={20} color="#5865F2" />
            </View>
            <View style={styles.optionText}>
              <Text style={[styles.optionTitle, { color: themeColors.textPrimary }]}>Invite via Link</Text>
              <Text style={[styles.optionSub, { color: themeColors.textMuted }]}>Share an invite to this server</Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={themeColors.textMuted} />
          </Pressable>
        </View>

        {/* Danger zone */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>DANGER ZONE</Text>
        <View style={[styles.optionGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <Pressable
            style={({ pressed }) => [
              styles.optionRow,
              pressed && { backgroundColor: themeColors.bgTertiary },
            ]}
            onPress={() => setShowLeaveModal(true)}
            disabled={leaveMutation.isPending}
            accessibilityRole="button"
          >
            <View style={[styles.iconWrap, { backgroundColor: themeColors.danger + '22' }]}>
              {leaveMutation.isPending ? (
                <ActivityIndicator size="small" color={themeColors.danger} />
              ) : (
                <Ionicons name="exit-outline" size={20} color={themeColors.danger} />
              )}
            </View>
            <View style={styles.optionText}>
              <Text style={[styles.optionTitle, { color: themeColors.danger }]}>Leave Server</Text>
              <Text style={[styles.optionSub, { color: themeColors.textMuted }]}>You'll need an invite to rejoin</Text>
            </View>
            {!leaveMutation.isPending && (
              <Ionicons name="chevron-forward" size={18} color={themeColors.danger} />
            )}
          </Pressable>
        </View>
      </View>

      <LeaveConfirmSheet
        visible={showLeaveModal}
        serverName={server?.name}
        serverIcon={server?.icon}
        isPending={leaveMutation.isPending}
        onConfirm={handleConfirmLeave}
        onCancel={() => setShowLeaveModal(false)}
      />
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  serverCard: {
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.md,
    borderRadius: 16,
    overflow: 'hidden',
  },
  banner: { height: 70, width: '100%' },
  cardBody: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    gap: spacing.md,
  },
  cardText: { flex: 1 },
  serverName: { ...typography.headingM, fontFamily: 'gg-sans-bold' },
  serverDesc: { ...typography.bodySmall, marginTop: 2, lineHeight: 18 },
  sectionLabel: {
    ...typography.overline,
    fontSize: 11,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.xs,
  },
  optionGroup: {
    marginHorizontal: spacing.lg,
    borderRadius: 14,
    overflow: 'hidden',
  },
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    gap: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET + 8,
  },
  iconWrap: {
    width: 38,
    height: 38,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  optionText: { flex: 1 },
  optionTitle: { ...typography.body, fontFamily: 'gg-sans-semibold' },
  optionSub: { ...typography.caption, marginTop: 2 },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginLeft: spacing.md + 38 + spacing.md,
  },
  // ── Leave sheet ──
  sheetBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.65)',
  },
  sheetPanel: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingHorizontal: spacing.lg,
  },
  sheetHandle: {
    alignItems: 'center',
    paddingVertical: spacing.md,
  },
  sheetHandleBar: {
    width: 40,
    height: 4,
    borderRadius: 2,
    opacity: 0.35,
  },
  sheetIconWrap: {
    alignSelf: 'center',
    marginBottom: spacing.md,
    borderRadius: 50,
    padding: 4,
    borderWidth: 2,
  },
  sheetTitle: {
    ...typography.headingL,
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  sheetServerPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    alignSelf: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: 20,
    marginBottom: spacing.lg,
  },
  sheetServerPillText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
    maxWidth: 220,
  },
  sheetWarningBox: {
    flexDirection: 'row',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: 12,
    borderWidth: 1,
    marginBottom: spacing.xl,
    alignItems: 'flex-start',
  },
  sheetWarningText: {
    ...typography.bodySmall,
    flex: 1,
    lineHeight: 19,
  },
  sheetLeaveBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    borderRadius: 14,
    paddingVertical: 15,
    marginBottom: spacing.sm,
    minHeight: 52,
  },
  sheetLeaveBtnText: {
    color: '#fff',
    ...typography.body,
    fontFamily: 'gg-sans-bold',
    fontSize: 16,
  },
  sheetCancelBtn: {
    borderRadius: 14,
    paddingVertical: 15,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 52,
  },
  sheetCancelBtnText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
    fontSize: 16,
  },
});
