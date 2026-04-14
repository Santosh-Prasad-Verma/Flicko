/**
 * ServerIcon Component — Discord-Accurate Animated
 *
 * Features:
 * - Border radius morph: circle (24px) → squircle (16px) on hover/active (spring)
 * - Active pill indicator on the left (height animates)
 * - Press scale-down (0.92)
 * - Badge pop-in with spring
 * - Background color transition (blurple when active)
 *
 * Requirements: 4.1, 4.6
 */
import React, { useCallback, useEffect, useMemo } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Image } from 'expo-image';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  interpolate,
  interpolateColor,
  Extrapolation,
} from 'react-native-reanimated';
import {
  spacing,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

// Animated version of expo-image so we can animate borderRadius directly on the
// image — avoids putting overflow:hidden on a parent Animated.View which blocks
// GIF / animated WebP frame-rendering on Android.
const AnimatedImage = Animated.createAnimatedComponent(Image);
import {
  SPRING_SNAPPY,
  SPRING_BOUNCY,
  PRESS_SCALE_ICON,
  ICON_RADIUS_DEFAULT,
  ICON_RADIUS_ACTIVE,
  ENTER_POP,
} from '../../constants/Animations';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

interface ServerIconProps {
  name: string;
  iconUrl?: string | null;
  size?: number;
  unreadCount?: number;
  isActive?: boolean;
  hasUnread?: boolean;
  onPress?: () => void;
  onLongPress?: () => void;
}

export const ServerIcon = React.memo<ServerIconProps>(function ServerIcon({
  name,
  iconUrl,
  size = 48,
  unreadCount = 0,
  isActive = false,
  hasUnread = false,
  onPress,
  onLongPress,
}) {
  const { themeColors } = useTheme();

  // Animated values
  const activeProgress = useSharedValue(isActive ? 1 : 0);
  const pressed = useSharedValue(0);
  const hovered = useSharedValue(0);

  // Animate when active state changes
  useEffect(() => {
    activeProgress.value = withSpring(isActive ? 1 : 0, SPRING_SNAPPY);
  }, [isActive]);

  const initials = useMemo(() => {
    return name
      .split(/\s+/)
      .map((w) => w[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();
  }, [name]);

  // Icon container: morph border-radius + bg color + scale
  const iconAnimatedStyle = useAnimatedStyle(() => {
    const combined = Math.max(activeProgress.value, hovered.value);
    const radius = interpolate(
      combined,
      [0, 1],
      [ICON_RADIUS_DEFAULT, ICON_RADIUS_ACTIVE],
      Extrapolation.CLAMP,
    );
    const scale = interpolate(
      pressed.value,
      [0, 1],
      [1, PRESS_SCALE_ICON],
      Extrapolation.CLAMP,
    );
    const bgColor = interpolateColor(
      combined,
      [0, 1],
      [themeColors.bgTertiary, themeColors.accentPrimary],
    );

    return {
      borderRadius: radius,
      transform: [{ scale }],
      backgroundColor: bgColor,
    };
  });

  // Animated border-radius applied directly on the image — avoids overflow:hidden
  // on a parent Animated.View which breaks GIF / animated-WebP on Android.
  const imageRadiusStyle = useAnimatedStyle(() => {
    const combined = Math.max(activeProgress.value, hovered.value);
    return {
      borderRadius: interpolate(
        combined,
        [0, 1],
        [ICON_RADIUS_DEFAULT, ICON_RADIUS_ACTIVE],
        Extrapolation.CLAMP,
      ),
    };
  });

  // Left pill indicator (Discord's signature)
  const pillAnimatedStyle = useAnimatedStyle(() => {
    const pillHeight = isActive
      ? 40
      : hasUnread || unreadCount > 0
        ? 8
        : 0;
    const targetHeight = interpolate(
      hovered.value,
      [0, 1],
      [pillHeight, isActive ? 40 : 20],
      Extrapolation.CLAMP,
    );

    return {
      height: withSpring(targetHeight, SPRING_SNAPPY),
      opacity: withSpring(pillHeight > 0 || hovered.value > 0 ? 1 : 0, SPRING_SNAPPY),
    };
  });

  const onPressIn = useCallback(() => {
    pressed.value = withSpring(1, SPRING_BOUNCY);
    hovered.value = withSpring(1, SPRING_SNAPPY);
  }, []);

  const onPressOut = useCallback(() => {
    pressed.value = withSpring(0, SPRING_BOUNCY);
    if (!isActive) {
      hovered.value = withSpring(0, SPRING_SNAPPY);
    }
  }, [isActive]);

  const actualSize = Math.max(size, MINIMUM_TOUCH_TARGET);

  return (
    <View style={styles.wrapper}>
      {/* Pill indicator */}
      <Animated.View
        style={[
          styles.pill,
          { backgroundColor: themeColors.textPrimary },
          pillAnimatedStyle,
        ]}
      />

      <AnimatedPressable
        onPress={onPress}
        onLongPress={onLongPress}
        onPressIn={onPressIn}
        onPressOut={onPressOut}
        accessibilityRole="button"
        accessibilityLabel={`${name}${unreadCount > 0 ? `, ${unreadCount} unread` : ''}`}
        style={styles.iconPressable}
      >
        <Animated.View
          style={[
            {
              width: actualSize,
              height: actualSize,
              justifyContent: 'center',
              alignItems: 'center',
              // NOTE: no overflow:hidden here — it blocks GIF/WebP animation on Android.
              // Border-radius clipping is handled by the AnimatedImage's own style.
            },
            iconAnimatedStyle,
          ]}
        >
          {iconUrl ? (
            <AnimatedImage
              source={{ uri: iconUrl }}
              style={[{ width: size, height: size }, imageRadiusStyle]}
              contentFit="cover"
              transition={200}
              cachePolicy="disk"
              autoplay={true}
            />
          ) : (
            <Text
              style={[
                styles.initials,
                { color: '#FFFFFF' },
                { fontSize: size * 0.35 },
              ]}
            >
              {initials}
            </Text>
          )}
        </Animated.View>

        {/* Badge — pops in with spring */}
        {unreadCount > 0 ? (
          <Animated.View
            entering={ENTER_POP}
            style={[styles.badge, { backgroundColor: themeColors.danger }]}
          >
            <Text style={styles.badgeText}>
              {unreadCount > 99 ? '99+' : unreadCount}
            </Text>
          </Animated.View>
        ) : null}
      </AnimatedPressable>
    </View>
  );
});

const styles = StyleSheet.create({
  wrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  pill: {
    width: 4,
    borderTopRightRadius: 4,
    borderBottomRightRadius: 4,
    marginRight: 8,
  },
  iconPressable: {
    position: 'relative',
    alignItems: 'center',
  },
  initials: {
    fontFamily: 'gg-sans-bold',
  },
  badge: {
    position: 'absolute',
    bottom: -2,
    right: -4,
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    ...typography.micro,
    color: '#FFFFFF',
    fontFamily: 'gg-sans-bold',
  },
});
