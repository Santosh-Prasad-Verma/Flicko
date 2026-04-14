/**
 * UnreadBadge Component
 *
 * Displays unread/mention count badges on channels and servers.
 * Red badge for unread messages, blue (accent) badge for @ mentions.
 *
 * Requirements: Feature 31 (Read States / Unread Tracking)
 */
import React from 'react';
import { View, Text, StyleSheet, ViewStyle } from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { useReadStateStore, type ReadStateStore } from '@stores/readStateStore';
import { useTheme } from '@/hooks/useTheme';

type BadgeSize = 'small' | 'medium' | 'large';

interface UnreadBadgeProps {
  channelId: string;
  /** Override unread count (skip store lookup) */
  count?: number;
  /** Override mention count */
  mentionCount?: number;
  /** Visual size variant */
  size?: BadgeSize;
  /** Show dot-only (no number) */
  dot?: boolean;
  /** Additional style */
  style?: ViewStyle;
}

const SIZE_MAP: Record<BadgeSize, { minWidth: number; height: number; fontSize: number; padding: number }> = {
  small: { minWidth: 16, height: 16, fontSize: 10, padding: 3 },
  medium: { minWidth: 20, height: 20, fontSize: 11, padding: 4 },
  large: { minWidth: 24, height: 24, fontSize: 13, padding: 5 },
};

export const UnreadBadge = React.memo(function UnreadBadge({
  channelId,
  count: overrideCount,
  mentionCount: overrideMentions,
  size = 'medium',
  dot = false,
  style,
}: UnreadBadgeProps) {
  const { themeColors } = useTheme();
  const storeUnread = useReadStateStore((s: ReadStateStore) => s.getUnreadCount(channelId));
  const storeMentions = useReadStateStore((s: ReadStateStore) => s.getMentionCount(channelId));

  const unreadCount = overrideCount ?? storeUnread;
  const mentionCountVal = overrideMentions ?? storeMentions;

  if (unreadCount <= 0 && mentionCountVal <= 0) return null;

  const hasMentions = mentionCountVal > 0;
  const displayCount = hasMentions ? mentionCountVal : unreadCount;
  const sizeConfig = SIZE_MAP[size];

  const backgroundColor = hasMentions ? themeColors.accentPrimary : themeColors.badgeRed;
  const displayText = displayCount > 99 ? '99+' : String(displayCount);

  if (dot) {
    return (
      <Animated.View
        entering={FadeIn.duration(200)}
        exiting={FadeOut.duration(200)}
        style={[
          styles.dot,
          {
            backgroundColor,
            width: sizeConfig.height * 0.5,
            height: sizeConfig.height * 0.5,
          },
          style,
        ]}
      />
    );
  }

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(200)}
      style={[
        styles.badge,
        {
          backgroundColor,
          minWidth: sizeConfig.minWidth,
          height: sizeConfig.height,
          paddingHorizontal: sizeConfig.padding,
          borderRadius: sizeConfig.height / 2,
        },
        style,
      ]}
    >
      <Text
        style={[
          styles.text,
          { fontSize: sizeConfig.fontSize },
        ]}
        numberOfLines={1}
      >
        {displayText}
      </Text>
    </Animated.View>
  );
});

/** Standalone dot indicator (no channel binding) */
export const UnreadDot = React.memo(function UnreadDot({
  visible,
  color,
  size = 8,
  style,
}: {
  visible: boolean;
  color?: string;
  size?: number;
  style?: ViewStyle;
}) {
  const { themeColors } = useTheme();
  const dotColor = color ?? themeColors.badgeRed;
  
  if (!visible) return null;

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(200)}
      style={[
        styles.dot,
        {
          backgroundColor: dotColor,
          width: size,
          height: size,
          borderRadius: size / 2,
        },
        style,
      ]}
    />
  );
});

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    color: '#FFFFFF',
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
  },
  dot: {
    borderRadius: 999,
  },
});
