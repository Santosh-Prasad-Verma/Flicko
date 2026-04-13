/**
 * Card Component
 *
 * Content container with consistent padding, background, border radius
 * and optional shadow elevation. Supports press interactions.
 *
 * Requirements: 16.4
 */
import React, { useMemo, useCallback } from 'react';
import { View, Pressable, StyleSheet, ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated';
import {
  spacing,
  borderRadius,
  shadows,
} from '../../constants/Colors';
import { SPRING_SNAPPY, PRESS_SCALE_CARD } from '../../constants/Animations';
import { useTheme } from '../../hooks/useTheme';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

interface CardProps {
  children: React.ReactNode;
  onPress?: () => void;
  style?: ViewStyle;
  elevation?: 'none' | 'subtle' | 'medium' | 'heavy';
  accessibilityLabel?: string;
}

export const Card = React.memo<CardProps>(function Card({
  children,
  onPress,
  style,
  elevation = 'subtle',
  accessibilityLabel,
}) {
  const { themeColors } = useTheme();

  const containerStyle = useMemo((): ViewStyle => {
    const base: ViewStyle = {
      backgroundColor: themeColors.cardBg,
      borderRadius: borderRadius.lg,
      padding: spacing.lg,
      borderWidth: 1,
      borderColor: themeColors.border,
      ...(elevation !== 'none' ? shadows[elevation] : {}),
    };
    return base;
  }, [themeColors, elevation]);

  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));
  const handlePressIn = useCallback(() => {
    scale.value = withSpring(PRESS_SCALE_CARD, SPRING_SNAPPY);
  }, []);
  const handlePressOut = useCallback(() => {
    scale.value = withSpring(1, SPRING_SNAPPY);
  }, []);

  if (onPress) {
    return (
      <AnimatedPressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={accessibilityLabel}
        style={[containerStyle, animStyle, style]}
      >
        {children}
      </AnimatedPressable>
    );
  }

  return (
    <View style={[containerStyle, style]} accessibilityLabel={accessibilityLabel}>
      {children}
    </View>
  );
});

const styles = StyleSheet.create({});
