/**
 * Voice Controls Component
 *
 * Connected voice channel control bar shown at the bottom of screens
 * when the user is in a voice channel. Integrates with voiceStore
 * and voiceService for real WebRTC state management.
 *
 * Features:
 * - Mute/deafen/disconnect buttons
 * - Video toggle
 * - Screen share toggle
 * - Connection quality indicator
 * - Channel name + connection state display
 * - Participant count
 */
import React, { useCallback, useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useVoiceStore } from '@stores/voiceStore';
import {
  toggleMute,
  toggleDeafen,
  toggleVideo,
  toggleScreenShare,
  leaveVoiceChannel,
  onConnectionStateChange,
  getConnectionState,
  type VoiceConnectionState,
} from '../../services/voiceService';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { router } from 'expo-router';

export interface VoiceControlsProps {
  /** Override channel name display */
  channelName?: string;
  /** Callback after disconnecting */
  onDisconnect?: () => void;
  /** Show expanded controls (video, screenshare) */
  expanded?: boolean;
}

const CONNECTION_COLORS: Record<VoiceConnectionState, string> = {
  disconnected: '#72767d',
  connecting: '#faa61a',
  connected: '#43b581',
  reconnecting: '#faa61a',
  failed: '#f04747',
};

const CONNECTION_LABELS: Record<VoiceConnectionState, string> = {
  disconnected: 'Disconnected',
  connecting: 'Connecting...',
  connected: 'Voice Connected',
  reconnecting: 'Reconnecting...',
  failed: 'Connection Failed',
};

export function VoiceControls({ channelName: channelNameOverride, onDisconnect, expanded = false }: VoiceControlsProps) {
  const { themeColors } = useTheme();
  const store = useVoiceStore();
  const [connState, setConnState] = useState<VoiceConnectionState>(getConnectionState());

  const displayChannelName = channelNameOverride ?? store.channelName;
  const isConnected = store.channelId !== null;

  useEffect(() => {
    const unsub = onConnectionStateChange(setConnState);
    return unsub;
  }, []);

  const handleMute = useCallback(async () => {
    try {
      await toggleMute();
    } catch (err) {
      console.warn('[VoiceControls] Mute failed:', err);
    }
  }, []);

  const handleDeafen = useCallback(async () => {
    try {
      await toggleDeafen();
    } catch (err) {
      console.warn('[VoiceControls] Deafen failed:', err);
    }
  }, []);

  const handleVideo = useCallback(async () => {
    try {
      await toggleVideo();
    } catch (err) {
      console.warn('[VoiceControls] Video toggle failed:', err);
    }
  }, []);

  const handleScreenShare = useCallback(async () => {
    try {
      await toggleScreenShare();
    } catch (err) {
      console.warn('[VoiceControls] Screen share failed:', err);
    }
  }, []);

  const handleDisconnect = useCallback(async () => {
    try {
      await leaveVoiceChannel();
      onDisconnect?.();
    } catch (err) {
      console.warn('[VoiceControls] Disconnect failed:', err);
    }
  }, [onDisconnect]);

  const handlePress = useCallback(() => {
    if (store.serverId && store.channelId) {
      router.push(`/server/${store.serverId}/channel/${store.channelId}/voice` as any);
    }
  }, [store.serverId, store.channelId]);

  if (!isConnected) return null;

  const statusColor = CONNECTION_COLORS[connState];
  const statusLabel = CONNECTION_LABELS[connState];
  const participantCount = store.participants.length;

  return (
    <Pressable
      onPress={handlePress}
      style={[styles.container, { backgroundColor: themeColors.bgSecondary, borderTopColor: themeColors.border }]}
    >
      {/* Left: Status info */}
      <View style={styles.info}>
        <View style={styles.statusRow}>
          <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
          <Text style={[styles.statusText, { color: statusColor }]}>
            {statusLabel}
          </Text>
        </View>
        {displayChannelName && (
          <View style={styles.channelRow}>
            <Ionicons name="volume-high" size={12} color={themeColors.textMuted} />
            <Text style={[styles.channelName, { color: themeColors.textMuted }]} numberOfLines={1}>
              {displayChannelName}
              {participantCount > 0 ? ` · ${participantCount}` : ''}
            </Text>
          </View>
        )}
      </View>

      {/* Right: Controls */}
      <View style={styles.controls}>
        {expanded && (
          <>
            {/* Video toggle */}
            <Pressable
              style={[
                styles.controlBtn,
                store.video && { backgroundColor: themeColors.accentPrimary + '33' },
              ]}
              onPress={handleVideo}
              accessibilityLabel={store.video ? 'Turn off camera' : 'Turn on camera'}
              accessibilityRole="button"
            >
              <Ionicons
                name={store.video ? 'videocam' : 'videocam-off'}
                size={18}
                color={store.video ? themeColors.accentPrimary : themeColors.textSecondary}
              />
            </Pressable>

            {/* Screen share toggle */}
            <Pressable
              style={[
                styles.controlBtn,
                store.streaming && { backgroundColor: themeColors.accentPrimary + '33' },
              ]}
              onPress={handleScreenShare}
              accessibilityLabel={store.streaming ? 'Stop sharing' : 'Share screen'}
              accessibilityRole="button"
            >
              <Ionicons
                name={store.streaming ? 'tv' : 'tv-outline'}
                size={18}
                color={store.streaming ? themeColors.accentPrimary : themeColors.textSecondary}
              />
            </Pressable>
          </>
        )}

        {/* Mute */}
        <Pressable
          style={[
            styles.controlBtn,
            store.muted && { backgroundColor: themeColors.danger + '33' },
          ]}
          onPress={handleMute}
          accessibilityLabel={store.muted ? 'Unmute' : 'Mute'}
          accessibilityRole="button"
        >
          <Ionicons
            name={store.muted ? 'mic-off' : 'mic'}
            size={20}
            color={store.muted ? themeColors.danger : themeColors.textPrimary}
          />
        </Pressable>

        {/* Deafen */}
        <Pressable
          style={[
            styles.controlBtn,
            store.deafened && { backgroundColor: themeColors.danger + '33' },
          ]}
          onPress={handleDeafen}
          accessibilityLabel={store.deafened ? 'Undeafen' : 'Deafen'}
          accessibilityRole="button"
        >
          <Ionicons
            name={store.deafened ? 'volume-mute' : 'volume-high'}
            size={20}
            color={store.deafened ? themeColors.danger : themeColors.textPrimary}
          />
        </Pressable>

        {/* Disconnect */}
        <Pressable
          style={[styles.controlBtn, styles.disconnectBtn]}
          onPress={handleDisconnect}
          accessibilityLabel="Disconnect from voice"
          accessibilityRole="button"
        >
          <Ionicons name="call" size={18} color={themeColors.danger} style={{ transform: [{ rotate: '135deg' }] }} />
        </Pressable>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderTopWidth: 1,
  },
  info: {
    flex: 1,
    gap: 2,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  channelName: {
    ...typography.caption,
  },
  controls: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  controlBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  disconnectBtn: {
    backgroundColor: 'rgba(240, 71, 71, 0.15)',
  },
});
