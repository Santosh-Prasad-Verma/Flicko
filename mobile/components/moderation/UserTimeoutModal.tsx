/**
 * User Timeout Modal (Feature 9)
 *
 * Moderator picker for timeout durations.
 * Shows duration options: 60s, 5m, 10m, 1h, 1d, 1w.
 * Displays timeout status banner for timed-out users.
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  FlatList,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface TimeoutOption {
  label: string;
  seconds: number;
}

const TIMEOUT_OPTIONS: TimeoutOption[] = [
  { label: '60 seconds', seconds: 60 },
  { label: '5 minutes', seconds: 300 },
  { label: '10 minutes', seconds: 600 },
  { label: '1 hour', seconds: 3600 },
  { label: '1 day', seconds: 86400 },
  { label: '1 week', seconds: 604800 },
];

interface UserTimeoutModalProps {
  visible: boolean;
  username: string;
  userId: string;
  onTimeout: (userId: string, durationSeconds: number) => void;
  onRemoveTimeout?: (userId: string) => void;
  onClose: () => void;
  isTimedOut?: boolean;
  timeoutUntil?: string | null;
}

export const UserTimeoutModal = memo(function UserTimeoutModal({
  visible,
  username,
  userId,
  onTimeout,
  onRemoveTimeout,
  onClose,
  isTimedOut = false,
  timeoutUntil,
}: UserTimeoutModalProps) {
  const { themeColors } = useTheme();

  const handleSelect = useCallback(
    (seconds: number) => {
      onTimeout(userId, seconds);
      onClose();
    },
    [userId, onTimeout, onClose],
  );

  const formatTimeoutRemaining = (until: string) => {
    const diff = new Date(until).getTime() - Date.now();
    if (diff <= 0) return 'Expired';
    const mins = Math.floor(diff / 60000);
    const hours = Math.floor(mins / 60);
    const days = Math.floor(hours / 24);
    if (days > 0) return `${days}d ${hours % 24}h remaining`;
    if (hours > 0) return `${hours}h ${mins % 60}m remaining`;
    return `${mins}m remaining`;
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.overlay} onPress={onClose}>
        <Pressable style={[styles.sheet, { backgroundColor: themeColors.bgSecondary }]}>
          <Text style={[styles.title, { color: themeColors.textPrimary }]}>
            Timeout {username}
          </Text>
          <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
            Prevents the user from sending messages, reacting, or joining voice channels.
          </Text>

          {isTimedOut && timeoutUntil && (
            <View style={[styles.currentTimeout, { backgroundColor: themeColors.warning + '20' }]}>
              <Ionicons name="time" size={16} color={themeColors.warning} />
              <Text style={[styles.currentTimeoutText, { color: themeColors.warning }]}>
                Currently timed out — {formatTimeoutRemaining(timeoutUntil)}
              </Text>
            </View>
          )}

          {TIMEOUT_OPTIONS.map((opt) => (
            <Pressable
              key={opt.seconds}
              style={({ pressed }) => [
                styles.optionRow,
                { backgroundColor: pressed ? themeColors.bgTertiary : 'transparent' },
              ]}
              onPress={() => handleSelect(opt.seconds)}
            >
              <Ionicons name="time-outline" size={18} color={themeColors.textSecondary} />
              <Text style={[styles.optionLabel, { color: themeColors.textPrimary }]}>
                {opt.label}
              </Text>
            </Pressable>
          ))}

          {isTimedOut && onRemoveTimeout && (
            <Pressable
              style={({ pressed }) => [
                styles.optionRow,
                { backgroundColor: pressed ? themeColors.bgTertiary : 'transparent' },
              ]}
              onPress={() => { onRemoveTimeout(userId); onClose(); }}
            >
              <Ionicons name="close-circle-outline" size={18} color={themeColors.danger} />
              <Text style={[styles.optionLabel, { color: themeColors.danger }]}>
                Remove Timeout
              </Text>
            </Pressable>
          )}

          <Pressable onPress={onClose} style={[styles.cancelBtn, { backgroundColor: themeColors.bgTertiary }]}>
            <Text style={[styles.cancelText, { color: themeColors.textPrimary }]}>Cancel</Text>
          </Pressable>
        </Pressable>
      </Pressable>
    </Modal>
  );
});

/** Timeout banner shown when a user is timed out (Feature 9) */
export const TimeoutBanner = memo(function TimeoutBanner({
  timeoutUntil,
}: {
  timeoutUntil: string;
}) {
  const { themeColors } = useTheme();
  const diff = new Date(timeoutUntil).getTime() - Date.now();
  if (diff <= 0) return null;

  const date = new Date(timeoutUntil);
  const formatted = date.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });

  return (
    <View style={[styles.banner, { backgroundColor: themeColors.warning + '15' }]}>
      <Ionicons name="time" size={16} color={themeColors.warning} />
      <Text style={[styles.bannerText, { color: themeColors.warning }]}>
        You are timed out until {formatted}
      </Text>
    </View>
  );
});

/** Timeout indicator icon next to username (Feature 9) */
export const TimeoutIndicator = memo(function TimeoutIndicator() {
  const { themeColors } = useTheme();
  return (
    <Text style={{ fontSize: 11, color: themeColors.warning, marginLeft: 2 }}>⏱</Text>
  );
});

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  sheet: {
    width: '100%',
    maxWidth: 400,
    borderRadius: 16,
    padding: spacing.lg,
  },
  title: {
    ...typography.headingM,
    marginBottom: spacing.xs,
  },
  subtitle: {
    ...typography.bodySmall,
    marginBottom: spacing.md,
  },
  currentTimeout: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: 8,
    marginBottom: spacing.md,
  },
  currentTimeoutText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  optionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: 8,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  optionLabel: {
    ...typography.body,
    fontFamily: 'gg-sans-medium',
  },
  cancelBtn: {
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: 8,
    marginTop: spacing.md,
  },
  cancelText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  bannerText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-medium',
    flex: 1,
  },
});
