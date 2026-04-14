/**
 * VoiceVideoControls — Bottom control bar (mic/cam/screen/etc)
 */
import React, { useCallback } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { useTheme } from '@/hooks/useTheme';
import { Ionicons } from '@expo/vector-icons';

interface VoiceVideoControlsProps {
  muted: boolean;
  deafened: boolean;
  videoEnabled: boolean;
  screenSharing: boolean;
  cameraFacing: 'front' | 'back';
  connectionState: string;
  elapsedTime: number;

  onToggleMic: () => void;
  onToggleDeafen: () => void;
  onToggleCamera: () => void;
  onFlipCamera: () => void;
  onToggleScreenShare: () => void;
  onGoLive: () => void;
  onDisconnect: () => void;
  onOpenSettings: () => void;
}

export function VoiceVideoControls({
  muted,
  deafened,
  videoEnabled,
  screenSharing,
  cameraFacing: _cameraFacing,
  connectionState,
  elapsedTime,
  onToggleMic,
  onToggleDeafen,
  onToggleCamera,
  onFlipCamera,
  onToggleScreenShare,
  onGoLive,
  onDisconnect,
  onOpenSettings: _onOpenSettings,
}: VoiceVideoControlsProps) {
  const { themeColors } = useTheme();

  const formatTime = useCallback((seconds: number) => {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }, []);

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}
    >
      {/* Timer + connection state */}
      <View style={styles.statusRow}>
        <View
          style={[
            styles.connectionDot,
            {
              backgroundColor:
                connectionState === 'connected'
                  ? '#43b581'
                  : connectionState === 'reconnecting'
                    ? '#faa61a'
                    : '#ed4245',
            },
          ]}
        />
        <Text style={[styles.timerText, { color: themeColors.textSecondary }]}>
          {formatTime(elapsedTime)}
        </Text>
      </View>

      {/* Main Controls Row */}
      <View style={styles.controlsRow}>
        <ControlButton
          icon={muted ? 'mic-off' : 'mic'}
          label={muted ? 'Unmute' : 'Mute'}
          active={!muted}
          danger={muted}
          onPress={onToggleMic}
          colors={themeColors}
        />

        <ControlButton
          icon={deafened ? 'volume-mute' : 'volume-high'}
          label={deafened ? 'Undeafen' : 'Deafen'}
          active={!deafened}
          danger={deafened}
          onPress={onToggleDeafen}
          colors={themeColors}
        />

        <ControlButton
          icon={videoEnabled ? 'videocam' : 'videocam-off'}
          label={videoEnabled ? 'Camera Off' : 'Camera On'}
          active={videoEnabled}
          onPress={onToggleCamera}
          colors={themeColors}
        />

        {videoEnabled && (
          <ControlButton
            icon="camera-reverse-outline"
            label="Flip"
            active
            onPress={onFlipCamera}
            colors={themeColors}
          />
        )}

        <ControlButton
          icon="desktop-outline"
          label={screenSharing ? 'Stop Share' : 'Share Screen'}
          active={screenSharing}
          accent={screenSharing}
          onPress={onToggleScreenShare}
          colors={themeColors}
        />

        <ControlButton
          icon="radio-outline"
          label="Go Live"
          active={false}
          accent
          onPress={onGoLive}
          colors={themeColors}
        />

        {/* Disconnect */}
        <Pressable onPress={onDisconnect} style={styles.disconnectButton} hitSlop={8}>
          <Ionicons
            name="call"
            size={22}
            color="#fff"
            style={{ transform: [{ rotate: '135deg' }] }}
          />
        </Pressable>
      </View>
    </Animated.View>
  );
}

// ── Individual Control Button ──

interface ControlButtonProps {
  icon: string;
  label: string;
  active: boolean;
  danger?: boolean;
  accent?: boolean;
  onPress: () => void;
  colors: any;
}

function ControlButton({ icon, label, active, danger, accent, onPress, colors }: ControlButtonProps) {
  const bgColor = danger
    ? 'rgba(237,66,69,0.15)'
    : accent
      ? 'rgba(88,101,242,0.15)'
      : active
        ? 'rgba(67,181,129,0.15)'
        : colors.bgTertiary;

  const iconColor = danger
    ? '#ed4245'
    : accent
      ? '#5865f2'
      : active
        ? '#43b581'
        : colors.textSecondary;

  return (
    <Pressable onPress={onPress} style={[styles.controlButton, { backgroundColor: bgColor }]} hitSlop={4}>
      <Ionicons name={icon as any} size={20} color={iconColor} />
      <Text style={[styles.controlLabel, { color: colors.textSecondary }]} numberOfLines={1}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    gap: 8,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  connectionDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  timerText: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    flexWrap: 'wrap',
  },
  controlButton: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
    width: 52,
    height: 52,
    borderRadius: 26,
  },
  controlLabel: {
    fontSize: 8,
    fontFamily: 'gg-sans-medium',
  },
  disconnectButton: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: '#ed4245',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
