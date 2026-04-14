/**
 * LoadingSpinner
 *
 * Centered activity indicator for async operations.
 * Requirements: 16.8
 */
import React from 'react';
import { View, ActivityIndicator, Text, StyleSheet, ViewStyle } from 'react-native';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface LoadingSpinnerProps {
  message?: string;
  size?: 'small' | 'large';
  fullScreen?: boolean;
  style?: ViewStyle;
}

export const LoadingSpinner = React.memo<LoadingSpinnerProps>(function LoadingSpinner({
  message,
  size = 'large',
  fullScreen = false,
  style,
}) {
  const { themeColors } = useTheme();

  return (
    <View
      style={[
        styles.container,
        fullScreen && { flex: 1, backgroundColor: themeColors.bgPrimary },
        style,
      ]}
      accessibilityRole="progressbar"
      accessibilityLabel={message || 'Loading'}
    >
      <ActivityIndicator size={size} color={themeColors.accentPrimary} />
      {message ? (
        <Text style={[styles.message, { color: themeColors.textSecondary }]}>
          {message}
        </Text>
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xxl,
  },
  message: {
    ...typography.bodySmall,
    marginTop: spacing.md,
    textAlign: 'center',
  },
});
