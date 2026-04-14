/**
 * Button Component — Discord-style with spring press animation
 *
 * Primary interactive element with haptic feedback, spring scale animation,
 * loading states, and accessibility built-in. All sizes meet the 44×44pt
 * minimum touch target requirement.
 *
 * Requirements: 16.4
 */
import React, { useCallback, useMemo } from 'react';
import {
  Pressable,
  Text,
  StyleSheet,
  ActivityIndicator,
  ViewStyle,
  TextStyle,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import { SPRING_SNAPPY, PRESS_SCALE_BUTTON } from '../../constants/Animations';
import { useTheme } from '@/hooks/useTheme';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  disabled?: boolean;
  loading?: boolean;
  /** Full-width button */
  fullWidth?: boolean;
  style?: ViewStyle;
  textStyle?: TextStyle;
  accessibilityLabel?: string;
  accessibilityHint?: string;
}

export const Button = React.memo<ButtonProps>(function Button({
  title,
  onPress,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  fullWidth = false,
  style,
  textStyle,
  accessibilityLabel,
  accessibilityHint,
}) {
  const { themeColors } = useTheme();
  const isDisabled = disabled || loading;

  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = useCallback(() => {
    if (!isDisabled) {
      scale.value = withSpring(PRESS_SCALE_BUTTON, SPRING_SNAPPY);
    }
  }, [isDisabled]);

  const handlePressOut = useCallback(() => {
    scale.value = withSpring(1, SPRING_SNAPPY);
  }, []);

  const handlePress = useCallback(() => {
    if (isDisabled) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onPress();
  }, [isDisabled, onPress]);

  const containerStyle = useMemo((): ViewStyle => {
    const base: ViewStyle = {
      ...sizeStyles[size],
      borderRadius: borderRadius.md,
      alignItems: 'center',
      justifyContent: 'center',
      flexDirection: 'row',
      minHeight: MINIMUM_TOUCH_TARGET,
    };

    if (fullWidth) base.width = '100%';

    switch (variant) {
      case 'primary':
        base.backgroundColor = themeColors.accentPrimary;
        break;
      case 'secondary':
        base.backgroundColor = themeColors.bgTertiary;
        break;
      case 'danger':
        base.backgroundColor = themeColors.danger;
        break;
      case 'ghost':
        base.backgroundColor = 'transparent';
        break;
    }

    if (isDisabled) base.opacity = 0.5;

    return base;
  }, [variant, size, fullWidth, isDisabled, themeColors]);

  const labelStyle = useMemo((): TextStyle => {
    const base: TextStyle = {
      ...sizeTextStyles[size],
      color: variant === 'ghost' ? themeColors.accentPrimary : '#FFFFFF',
    };
    return base;
  }, [variant, size, themeColors]);

  return (
    <AnimatedPressable
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      onPress={handlePress}
      disabled={isDisabled}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? title}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: isDisabled, busy: loading }}
      style={[containerStyle, animStyle, style]}
    >
      {loading ? (
        <ActivityIndicator
          color={variant === 'ghost' ? themeColors.accentPrimary : '#FFFFFF'}
          size="small"
          style={styles.loader}
        />
      ) : null}
      <Text style={[labelStyle, textStyle]} numberOfLines={1}>{title}</Text>
    </AnimatedPressable>
  );
});

const sizeStyles: Record<ButtonSize, ViewStyle> = {
  sm: { paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  md: { paddingHorizontal: spacing.xl, paddingVertical: spacing.md },
  lg: { paddingHorizontal: spacing.xxl, paddingVertical: spacing.lg },
};

const sizeTextStyles: Record<ButtonSize, TextStyle> = {
  sm: { fontSize: 14, fontFamily: 'gg-sans-semibold', lineHeight: 20 },
  md: { fontSize: 16, fontFamily: 'gg-sans-semibold', lineHeight: 22 },
  lg: { fontSize: 16, fontFamily: 'gg-sans-bold', lineHeight: 22 },
};

const styles = StyleSheet.create({
  loader: {
    marginRight: spacing.sm,
  },
});
