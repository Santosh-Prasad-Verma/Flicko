/**
 * Stage Channel Screen
 *
 * Full-screen stage channel with speaker/audience separation,
 * hand raising, and invite-to-speak moderation.
 *
 * Route: /server/[serverId]/channel/[channelId]/stage
 * Note: ChannelList routes stage channels to /voice — this screen can also
 *       be used via the voice screen detect-and-redirect approach.
 * Requirements: Feature 9 (Stage Channels)
 */
import React, { useCallback, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  Alert,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../../services/supabase';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../../constants/Colors';
import { useAuthStore } from '@stores/authStore';
import { useVoiceStore } from '@stores/voiceStore';
import { useTheme } from '../../../../../hooks/useTheme';

interface StageParticipant {
  user_id: string;
  username: string;
  display_name?: string;
  avatar_url?: string;
  is_speaker: boolean;
  hand_raised: boolean;
  self_mute: boolean;
}

export default function StageChannelScreen() {
  const { serverId, channelId } = useLocalSearchParams<{
    serverId: string;
    channelId: string;
  }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  const queryClient = useQueryClient();
  const { channelId: connectedChannelId, muted } = useVoiceStore();
  const isConnected = connectedChannelId === channelId;

  const [topic, setTopic] = useState('');

  // Channel info
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: async () => {
      const { data, error } = await supabase.from('channels').select('*').eq('id', channelId).single();
      if (error) throw error;
      return data;
    },
    enabled: !!channelId,
  });

  // Participants from voice_states + stage metadata
  const { data: participants = [] } = useQuery({
    queryKey: ['stage-participants', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('voice_states')
        .select('*, user:profiles!user_id(id, username, display_name, avatar_url:avatar)')
        .eq('channel_id', channelId);
      if (error) throw error;
      return (data ?? []).map((vs: any) => ({
        user_id: vs.user_id,
        username: vs.user?.username ?? 'Unknown',
        display_name: vs.user?.display_name,
        avatar_url: vs.user?.avatar_url,
        is_speaker: !vs.suppress,
        hand_raised: false, // TODO: store hand_raised in voice_states
        self_mute: vs.self_mute,
      })) as StageParticipant[];
    },
    enabled: !!channelId,
    refetchInterval: 3000,
  });

  const speakers = useMemo(() => participants.filter((p) => p.is_speaker), [participants]);
  const audience = useMemo(() => participants.filter((p) => !p.is_speaker), [participants]);

  const currentUserParticipant = useMemo(
    () => participants.find((p) => p.user_id === user?.id),
    [participants, user],
  );
  const isSpeaker = currentUserParticipant?.is_speaker ?? false;

  // Join/Leave
  const handleJoin = useCallback(() => {
    useVoiceStore.getState().connect(channelId!, serverId!);
  }, [channelId, serverId]);

  const handleLeave = useCallback(() => {
    useVoiceStore.getState().disconnect();
  }, []);

  // Raise/lower hand
  const raiseHandMutation = useMutation({
    mutationFn: async () => {
      // Toggle hand raise via suppress field (temporary approach)
      // In a full implementation, a dedicated hand_raised column would be used
      await supabase
        .from('voice_states')
        .update({ suppress: true })
        .eq('channel_id', channelId)
        .eq('user_id', user?.id);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['stage-participants', channelId] }),
  });

  // Invite to speak (moderator action)
  const inviteToSpeakMutation = useMutation({
    mutationFn: async (targetUserId: string) => {
      await supabase
        .from('voice_states')
        .update({ suppress: false })
        .eq('channel_id', channelId)
        .eq('user_id', targetUserId);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['stage-participants', channelId] }),
  });

  // Move to audience (moderator action)
  const moveToAudienceMutation = useMutation({
    mutationFn: async (targetUserId: string) => {
      await supabase
        .from('voice_states')
        .update({ suppress: true })
        .eq('channel_id', channelId)
        .eq('user_id', targetUserId);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['stage-participants', channelId] }),
  });

  const handleParticipantPress = useCallback(
    (p: StageParticipant) => {
      if (p.user_id === user?.id) return;
      const actions: any[] = [
        { text: 'View Profile', onPress: () => router.push(`/profile/${p.user_id}` as any) },
      ];
      if (!p.is_speaker) {
        actions.push({
          text: 'Invite to Speak',
          onPress: () => inviteToSpeakMutation.mutate(p.user_id),
        });
      } else {
        actions.push({
          text: 'Move to Audience',
          onPress: () => moveToAudienceMutation.mutate(p.user_id),
        });
      }
      actions.push({ text: 'Cancel', style: 'cancel' });
      Alert.alert(p.display_name || p.username, undefined, actions);
    },
    [user, inviteToSpeakMutation, moveToAudienceMutation],
  );

  // ── Render ──

  const renderParticipant = (p: StageParticipant) => (
    <Pressable
      key={p.user_id}
      style={styles.participantCard}
      onPress={() => handleParticipantPress(p)}
    >
      <View style={[styles.participantAvatar, { backgroundColor: themeColors.bgTertiary }]}>
        <Text style={[styles.avatarLetter, { color: themeColors.textSecondary }]}>
          {(p.display_name || p.username)[0]?.toUpperCase()}
        </Text>
        {p.self_mute && (
          <View style={[styles.muteIndicator, { backgroundColor: themeColors.danger }]}>
            <Ionicons name="mic-off" size={10} color="#fff" />
          </View>
        )}
      </View>
      <Text style={[styles.participantName, { color: themeColors.textPrimary }]} numberOfLines={1}>
        {p.display_name || p.username}
      </Text>
    </Pressable>
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
          <View style={styles.headerInfo}>
            <View style={styles.channelNameRow}>
              <Ionicons name="radio-outline" size={16} color={themeColors.accentSecondary} />
              <Text style={[styles.channelName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {channel?.name || 'Stage'}
              </Text>
            </View>
            {channel?.topic && (
              <Text style={[styles.topicText, { color: themeColors.textMuted }]} numberOfLines={1}>
                {channel.topic}
              </Text>
            )}
          </View>
          <View style={[styles.liveBadge, { backgroundColor: themeColors.danger }]}>
            <Text style={styles.liveText}>LIVE</Text>
          </View>
        </View>

        <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
          {/* Speakers section */}
          <Text style={[styles.sectionTitle, { color: themeColors.textSecondary }]}>
            SPEAKERS — {speakers.length}
          </Text>
          <View style={styles.participantGrid}>
            {speakers.length === 0 ? (
              <Text style={[styles.emptySection, { color: themeColors.textMuted }]}>
                No speakers yet
              </Text>
            ) : (
              speakers.map(renderParticipant)
            )}
          </View>

          {/* Audience section */}
          <Text style={[styles.sectionTitle, { color: themeColors.textSecondary, marginTop: spacing.xl }]}>
            AUDIENCE — {audience.length}
          </Text>
          <View style={styles.participantGrid}>
            {audience.length === 0 ? (
              <Text style={[styles.emptySection, { color: themeColors.textMuted }]}>
                No audience members
              </Text>
            ) : (
              audience.map(renderParticipant)
            )}
          </View>
        </ScrollView>

        {/* Bottom controls */}
        <View
          style={[styles.controls, { backgroundColor: themeColors.bgSecondary, paddingBottom: insets.bottom + spacing.md }]}
        >
          {isConnected ? (
            <View style={styles.controlRow}>
              {/* Mute toggle */}
              <Pressable
                style={[styles.controlBtn, { backgroundColor: muted ? themeColors.danger : themeColors.bgTertiary }]}
                onPress={() => useVoiceStore.getState().toggleMute()}
              >
                <Ionicons name={muted ? 'mic-off' : 'mic'} size={22} color={themeColors.textPrimary} />
              </Pressable>

              {/* Raise hand / Lower hand (audience only) */}
              {!isSpeaker && (
                <Pressable
                  style={[styles.controlBtn, { backgroundColor: themeColors.warning }]}
                  onPress={() => raiseHandMutation.mutate()}
                >
                  <Ionicons name="hand-left" size={22} color="#000" />
                  <Text style={styles.handText}>Raise Hand</Text>
                </Pressable>
              )}

              {/* Leave */}
              <Pressable
                style={[styles.controlBtn, { backgroundColor: themeColors.danger }]}
                onPress={handleLeave}
              >
                <Ionicons name="exit-outline" size={22} color="#fff" />
                <Text style={[styles.leaveText]}>Leave</Text>
              </Pressable>
            </View>
          ) : (
            <Pressable
              style={[styles.joinBtn, { backgroundColor: themeColors.accentPrimary }]}
              onPress={handleJoin}
            >
              <Ionicons name="radio" size={20} color="#fff" />
              <Text style={styles.joinText}>Join Stage</Text>
            </Pressable>
          )}
        </View>
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
  backBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, justifyContent: 'center', alignItems: 'center' },
  headerInfo: { flex: 1, marginLeft: spacing.sm },
  channelNameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  channelName: { ...typography.headingS },
  topicText: { ...typography.caption, marginTop: 2 },
  liveBadge: { paddingHorizontal: spacing.sm, paddingVertical: 2, borderRadius: borderRadius.sm },
  liveText: { color: '#fff', ...typography.micro, fontFamily: 'gg-sans-bold' },
  content: { flex: 1 },
  contentInner: { padding: spacing.lg },
  sectionTitle: { ...typography.overline, marginBottom: spacing.md },
  participantGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md },
  emptySection: { ...typography.bodySmall, paddingVertical: spacing.lg },
  participantCard: { alignItems: 'center', width: 80 },
  participantAvatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  avatarLetter: { ...typography.headingM },
  muteIndicator: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 18,
    height: 18,
    borderRadius: 9,
    justifyContent: 'center',
    alignItems: 'center',
  },
  participantName: { ...typography.caption, textAlign: 'center' },
  controls: { borderTopWidth: 1, borderColor: 'rgba(255,255,255,0.1)', paddingTop: spacing.md, paddingHorizontal: spacing.lg },
  controlRow: { flexDirection: 'row', justifyContent: 'center', gap: spacing.md },
  controlBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.full,
    gap: spacing.xs,
  },
  handText: { color: '#000', ...typography.caption, fontFamily: 'gg-sans-semibold' },
  leaveText: { color: '#fff', ...typography.caption, fontFamily: 'gg-sans-semibold' },
  joinBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.lg,
    borderRadius: borderRadius.lg,
    gap: spacing.sm,
  },
  joinText: { color: '#fff', ...typography.bodyBold },
});
