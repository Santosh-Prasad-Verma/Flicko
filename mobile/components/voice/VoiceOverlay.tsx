/**
 * VoiceOverlay
 *
 * Persistent mini-bar shown at the bottom of the screen when the user
 * is connected to a voice channel.  Shows channel name, duration, and
 * quick mute / disconnect controls.  Tapping the bar navigates to the
 * full VoiceChannelScreen.
 *
 * Requirements: Feature 17 (Voice overlay)
 */
import React, { memo, useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, { SlideInDown, SlideOutDown } from 'react-native-reanimated';
import { useVoiceStore } from '@stores/voiceStore';
import { updateVoiceState, leaveVoiceChannel } from '@services/voiceService';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius } from '../../constants/Colors';

interface VoiceOverlayProps {
  onPress: () => void;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

export const VoiceOverlay = memo(function VoiceOverlay({ onPress }: VoiceOverlayProps) {
  const { themeColors } = useTheme();
  const { channelId, channelName, muted, connectionState, disconnect, toggleMute } =
    useVoiceStore();
  const [elapsed, setElapsed] = useState(0);

  // Timer
  useEffect(() => {
    if (!channelId) {
      setElapsed(0);
      return;
    }
    const timer = setInterval(() => {
      setElapsed((e) => e + 1);
    }, 1000);
    return () => clearInterval(timer);
  }, [channelId]);

  if (!channelId || connectionState === 'disconnected') return null;

  const handleMute = async () => {
    toggleMute();
    await updateVoiceState({ self_mute: !muted });
  };

  const handleDisconnect = async () => {
    await leaveVoiceChannel();
    disconnect();
  };

  return (
    <Animated.View
      entering={SlideInDown.springify().damping(18)}
      exiting={SlideOutDown.springify().damping(18)}
      style={[styles.container, { backgroundColor: '#2ECC71' }]}
    >
      <Pressable onPress={onPress} style={styles.infoSection}>
        <Ionicons name="volume-high" size={16} color="#FFFFFF" />
        <View style={styles.textContainer}>
          <Text style={styles.channelName} numberOfLines={1}>
            {channelName ?? 'Voice Connected'}
          </Text>
          <Text style={styles.duration}>{formatDuration(elapsed)}</Text>
        </View>
      </Pressable>

      <View style={styles.controls}>
        <Pressable onPress={handleMute} hitSlop={10} style={styles.iconBtn}>
          <Ionicons
            name={muted ? 'mic-off' : 'mic'}
            size={20}
            color="#FFFFFF"
          />
        </Pressable>
        <Pressable onPress={handleDisconnect} hitSlop={10} style={styles.disconnectBtn}>
          <Ionicons
            name="call"
            size={18}
            color="#FFFFFF"
            style={{ transform: [{ rotate: '135deg' }] }}
          />
        </Pressable>
      </View>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 2,
    marginHorizontal: spacing.sm,
    marginBottom: spacing.xs,
    borderRadius: borderRadius.md,
  },
  infoSection: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  textContainer: {
    flex: 1,
  },
  channelName: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  duration: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  iconBtn: {
    padding: 6,
  },
  disconnectBtn: {
    backgroundColor: 'rgba(0,0,0,0.25)',
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
