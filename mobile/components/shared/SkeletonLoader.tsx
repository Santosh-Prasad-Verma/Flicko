/**
 * SkeletonLoader Components
 *
 * Animated placeholder loaders with pulsing opacity effect using
 * Reanimated. Variants for messages, profiles, servers, and channels.
 *
 * Requirements: Feature 32 (UI Animations & Polish)
 */
import React, { memo, useEffect } from 'react';
import { View, StyleSheet, ViewStyle } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius } from '../../constants/Colors';

// ── Base Skeleton ─────────────────────────────────────────────────────────

interface SkeletonProps {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: ViewStyle;
}

export const Skeleton = memo(function Skeleton({
  width = '100%',
  height = 16,
  borderRadius: radius = 4,
  style,
}: SkeletonProps) {
  const { themeColors } = useTheme();
  const opacity = useSharedValue(0.3);

  useEffect(() => {
    opacity.value = withRepeat(
      withTiming(1, { duration: 1000, easing: Easing.inOut(Easing.ease) }),
      -1, // infinite
      true, // reverse
    );
  }, [opacity]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        {
          width: width as any,
          height,
          borderRadius: radius,
          backgroundColor: themeColors.bgTertiary,
        },
        animatedStyle,
        style,
      ]}
    />
  );
});

// ── Message Skeleton ──────────────────────────────────────────────────────

export const MessageSkeleton = memo(function MessageSkeleton() {
  return (
    <View style={styles.messageContainer}>
      <Skeleton width={40} height={40} borderRadius={20} />
      <View style={styles.messageBody}>
        <View style={styles.messageHeader}>
          <Skeleton width={120} height={14} />
          <Skeleton width={60} height={10} />
        </View>
        <Skeleton width="90%" height={14} style={{ marginTop: 6 }} />
        <Skeleton width="60%" height={14} style={{ marginTop: 4 }} />
      </View>
    </View>
  );
});

export const MessageListSkeleton = memo(function MessageListSkeleton({
  count = 8,
}: {
  count?: number;
}) {
  return (
    <View style={styles.messageList}>
      {Array.from({ length: count }, (_, i) => (
        <MessageSkeleton key={i} />
      ))}
    </View>
  );
});

// ── Profile Skeleton ──────────────────────────────────────────────────────

export const ProfileSkeleton = memo(function ProfileSkeleton() {
  return (
    <View style={styles.profileContainer}>
      {/* Banner */}
      <Skeleton width="100%" height={120} borderRadius={0} />
      {/* Avatar */}
      <View style={styles.profileAvatarWrap}>
        <Skeleton width={80} height={80} borderRadius={40} />
      </View>
      {/* Name */}
      <View style={styles.profileInfo}>
        <Skeleton width={160} height={20} />
        <Skeleton width={100} height={14} style={{ marginTop: 8 }} />
        <Skeleton width="90%" height={14} style={{ marginTop: 16 }} />
        <Skeleton width="70%" height={14} style={{ marginTop: 4 }} />
      </View>
    </View>
  );
});

// ── Server Skeleton ───────────────────────────────────────────────────────

export const ServerSkeleton = memo(function ServerSkeleton() {
  return (
    <View style={styles.serverCard}>
      <Skeleton width="100%" height={100} borderRadius={borderRadius.md} />
      <View style={styles.serverInfo}>
        <Skeleton width={48} height={48} borderRadius={24} />
        <View style={{ flex: 1, gap: 6 }}>
          <Skeleton width={140} height={16} />
          <Skeleton width={80} height={12} />
        </View>
      </View>
    </View>
  );
});

// ── Channel List Skeleton ─────────────────────────────────────────────────

export const ChannelListSkeleton = memo(function ChannelListSkeleton({
  count = 6,
}: {
  count?: number;
}) {
  return (
    <View style={styles.channelList}>
      {/* Category header */}
      <Skeleton width={100} height={12} style={{ marginBottom: spacing.sm, marginLeft: spacing.md }} />
      {Array.from({ length: count }, (_, i) => (
        <View key={i} style={styles.channelItem}>
          <Skeleton width={20} height={20} borderRadius={4} />
          <Skeleton width={`${50 + Math.random() * 40}%`} height={14} />
        </View>
      ))}
    </View>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  // Message
  messageContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 12,
  },
  messageBody: {
    flex: 1,
  },
  messageHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  messageList: {
    flex: 1,
    paddingTop: spacing.md,
  },

  // Profile
  profileContainer: {
    overflow: 'hidden',
  },
  profileAvatarWrap: {
    marginTop: -40,
    marginLeft: 16,
    borderRadius: 44,
    borderWidth: 4,
    borderColor: 'transparent',
  },
  profileInfo: {
    paddingHorizontal: 16,
    paddingTop: 12,
  },

  // Server
  serverCard: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    gap: spacing.md,
  },
  serverInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },

  // Channel
  channelList: {
    paddingTop: spacing.md,
  },
  channelItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
});
