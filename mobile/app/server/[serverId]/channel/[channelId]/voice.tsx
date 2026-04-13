/**
 * Voice Channel Screen
 *
 * Full-screen voice channel view showing participants, controls,
 * and connection state. Uses LiveKit SFU when available.
 *
 * Route: /server/[serverId]/channel/[channelId]/voice
 */
import React, { useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  ActivityIndicator,
  Image,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../../services/supabase';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../../constants/Colors';
import { useAuthStore } from '@stores/authStore';
import { useVoiceStore, type VoiceParticipant } from '@stores/voiceStore';
import { useActivityStore } from '@stores/activityStore';
import voiceService from '../../../../../services/voiceService';
import { ActivityPicker } from '../../../../../components/voice/ActivityPicker';
import { ActivitySession } from '../../../../../components/voice/ActivitySession';
import { useTheme } from '../../../../../hooks/useTheme';

export default function VoiceChannelScreen() {
  const { serverId, channelId } = useLocalSearchParams<{
    serverId: string;
    channelId: string;
  }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: any) => s.user);

  const {
    channelId: connectedChannelId,
    connectionState,
    muted,
    deafened,
    video,
    streaming,
    participants,
  } = useVoiceStore();

  const isConnected = connectedChannelId === channelId;

  // Fetch channel info
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channels')
        .select('*')
        .eq('id', channelId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!channelId,
  });

  // Fetch voice states from DB for users in this channel
  const { data: voiceStates } = useQuery({
    queryKey: ['voice-states', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('voice_states')
        .select('*, user:profiles!user_id(id, username, display_name, avatar_url:avatar)')
        .eq('channel_id', channelId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!channelId,
    refetchInterval: 5000, // Refresh every 5s
  });

  // Merge store participants with DB voice states
  const displayParticipants = useMemo(() => {
    if (!voiceStates?.length) return participants;

    const merged: VoiceParticipant[] = voiceStates.map((vs: any) => {
      const storeP = participants.find((p) => p.userId === vs.user_id);
      const displayName = vs.user?.display_name || vs.user?.username || 'Unknown';
      return {
        userId: vs.user_id,
        username: vs.user?.username || 'Unknown',
        displayName,
        avatarUrl: vs.user?.avatar_url ?? null,
        muted: storeP?.muted ?? vs.self_mute ?? vs.is_self_muted ?? false,
        deafened: storeP?.deafened ?? vs.self_deaf ?? vs.is_self_deafened ?? false,
        video: storeP?.video ?? vs.is_video ?? false,
        streaming: storeP?.streaming ?? vs.is_streaming ?? false,
        speaking: storeP?.speaking ?? false,
      };
    });
    return merged;
  }, [voiceStates, participants]);

  // Handle connect/disconnect
  const handleConnect = async () => {
    if (!channelId || !serverId) return;
    try {
      await voiceService.joinVoiceChannel(channelId, channel?.name || 'Voice', serverId);
    } catch (err: any) {
      console.error('[VoiceScreen] Join failed:', err);
    }
  };

  const handleDisconnect = async () => {
    try {
      await voiceService.leaveVoiceChannel();
    } catch (err: any) {
      console.error('[VoiceScreen] Leave failed:', err);
    }
    router.back();
  };

  const renderParticipant = ({ item }: { item: VoiceParticipant }) => {
    const isMe = item.userId === user?.id;
    return (
      <View style={[styles.participantCard, { backgroundColor: themeColors.bgSecondary }]}>
        {/* Avatar circle */}
        <View
          style={[
            styles.avatarCircle,
            {
              borderColor: item.speaking ? themeColors.success : 'transparent',
              backgroundColor: themeColors.bgTertiary,
            },
          ]}
        >
          {item.avatarUrl ? (
            <Image
              source={{ uri: item.avatarUrl }}
              style={{ width: '100%', height: '100%', borderRadius: 32 }}
              resizeMode="cover"
            />
          ) : (
            <Text style={[styles.avatarText, { color: themeColors.textPrimary }]}>
              {(item.displayName || item.username || '?')[0].toUpperCase()}
            </Text>
          )}
          {item.speaking && <View style={[styles.speakingDot, { backgroundColor: themeColors.success }]} />}
        </View>

        {/* Name */}
        <Text
          style={[styles.participantName, { color: themeColors.textPrimary }]}
          numberOfLines={1}
        >
          {item.displayName || item.username}
          {isMe ? ' (You)' : ''}
        </Text>

        {/* Status icons */}
        <View style={styles.statusIcons}>
          {item.muted && (
            <Ionicons name="mic-off" size={14} color={themeColors.danger} />
          )}
          {item.deafened && (
            <Ionicons name="volume-mute" size={14} color={themeColors.danger} />
          )}
          {item.video && (
            <Ionicons name="videocam" size={14} color={themeColors.success} />
          )}
          {item.streaming && (
            <Ionicons name="desktop-outline" size={14} color={themeColors.accentPrimary} />
          )}
        </View>
      </View>
    );
  };

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
            style={styles.backButton}
          >
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <View style={styles.channelNameRow}>
              <Ionicons name="volume-high" size={16} color={themeColors.textMuted} />
              <Text style={[styles.channelName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {channel?.name || 'Voice Channel'}
              </Text>
            </View>
            <Text style={[styles.connectionStatus, { color: getStatusColor(connectionState, themeColors) }]}>
              {isConnected ? connectionState : 'Not connected'}
            </Text>
          </View>
          <View style={styles.participantCount}>
            <Ionicons name="people" size={16} color={themeColors.textMuted} />
            <Text style={[styles.countText, { color: themeColors.textMuted }]}>
              {displayParticipants.length}
            </Text>
          </View>
        </View>

        {/* Participants grid */}
        <FlatList
          data={displayParticipants}
          keyExtractor={(item) => item.userId}
          renderItem={renderParticipant}
          numColumns={2}
          contentContainerStyle={styles.participantGrid}
          columnWrapperStyle={styles.participantRow}
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Ionicons name="volume-high-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                No one is in this voice channel
              </Text>
            </View>
          }
        />

        {/* Controls */}
        <View
          style={[
            styles.controlsBar,
            { backgroundColor: themeColors.bgSecondary, paddingBottom: insets.bottom + spacing.md },
          ]}
        >
          {!isConnected ? (
            <Pressable
              style={[styles.connectButton, { backgroundColor: themeColors.success }]}
              onPress={handleConnect}
            >
              {connectionState === 'connecting' ? (
                <ActivityIndicator color="#FFFFFF" size="small" />
              ) : (
                <>
                  <Ionicons name="call" size={20} color="#FFFFFF" />
                  <Text style={styles.connectButtonText}>Join Voice</Text>
                </>
              )}
            </Pressable>
          ) : (
            <View style={styles.controlRow}>
              {/* Mute */}
              <Pressable
                style={[
                  styles.controlButton,
                  { backgroundColor: muted ? themeColors.danger : themeColors.bgTertiary },
                ]}
                onPress={() => voiceService.toggleMute()}
              >
                <Ionicons
                  name={muted ? 'mic-off' : 'mic'}
                  size={22}
                  color="#FFFFFF"
                />
              </Pressable>

              {/* Deafen */}
              <Pressable
                style={[
                  styles.controlButton,
                  { backgroundColor: deafened ? themeColors.danger : themeColors.bgTertiary },
                ]}
                onPress={() => voiceService.toggleDeafen()}
              >
                <Ionicons
                  name={deafened ? 'volume-mute' : 'volume-high'}
                  size={22}
                  color="#FFFFFF"
                />
              </Pressable>

              {/* Video */}
              <Pressable
                style={[
                  styles.controlButton,
                  { backgroundColor: video ? themeColors.success : themeColors.bgTertiary },
                ]}
                onPress={() => voiceService.toggleVideo()}
              >
                <Ionicons
                  name={video ? 'videocam' : 'videocam-outline'}
                  size={22}
                  color="#FFFFFF"
                />
              </Pressable>

              {/* Screen share */}
              <Pressable
                style={[
                  styles.controlButton,
                  { backgroundColor: streaming ? themeColors.accentPrimary : themeColors.bgTertiary },
                ]}
                onPress={() => voiceService.toggleScreenShare()}
              >
                <Ionicons name="desktop-outline" size={22} color="#FFFFFF" />
              </Pressable>

              {/* Activities */}
              <Pressable
                style={[styles.controlButton, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => useActivityStore.getState().openPicker()}
              >
                <Ionicons name="game-controller-outline" size={22} color="#FFFFFF" />
              </Pressable>

              {/* Disconnect */}
              <Pressable
                style={[styles.controlButton, { backgroundColor: themeColors.danger }]}
                onPress={handleDisconnect}
              >
                <Ionicons name="call" size={22} color="#FFFFFF" />
              </Pressable>
            </View>
          )}
        </View>

        <ActivityPicker channelId={channelId as string} serverId={serverId as string} />
        {useActivityStore((s) => s.currentSession) && (
          <ActivitySession channelId={channelId as string} serverId={serverId as string} />
        )}
      </View>
    </>
  );
}

function getStatusColor(state: string, themeColors: any): string {
  switch (state) {
    case 'connected':
      return themeColors.success;
    case 'connecting':
    case 'reconnecting':
      return themeColors.warning;
    case 'failed':
      return themeColors.danger;
    default:
      return themeColors.textMuted;
  }
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
  backButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerInfo: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  channelNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  channelName: {
    ...typography.headingS,
  },
  connectionStatus: {
    ...typography.caption,
    marginTop: 2,
    textTransform: 'capitalize',
  },
  participantCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  countText: {
    ...typography.bodyS,
  },
  participantGrid: {
    padding: spacing.md,
    flexGrow: 1,
  },
  participantRow: {
    gap: spacing.md,
    marginBottom: spacing.md,
  },
  participantCard: {
    flex: 1,
    borderRadius: 12,
    padding: spacing.lg,
    alignItems: 'center',
    gap: spacing.sm,
  },
  avatarCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
  },
  avatarText: {
    ...typography.headingM,
  },
  speakingDot: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  participantName: {
    ...typography.bodyS,
    textAlign: 'center',
  },
  statusIcons: {
    flexDirection: 'row',
    gap: 6,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 80,
    gap: spacing.md,
  },
  emptyText: {
    ...typography.bodyM,
    textAlign: 'center',
  },
  controlsBar: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
  },
  connectButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: 14,
    borderRadius: 24,
  },
  connectButtonText: {
    ...typography.headingS,
    color: '#FFFFFF',
  },
  controlRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  controlButton: {
    width: 52,
    height: 52,
    borderRadius: 26,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
