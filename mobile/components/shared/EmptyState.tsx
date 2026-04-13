/**
 * EmptyState
 *
 * Displays a helpful message when a list or view has no content.
 * Requirements: 16.9
 */
import React from 'react';
import { View, Text, StyleSheet, ViewStyle } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { Button } from '../ui/Button';

interface EmptyStateProps {
  icon?: keyof typeof Ionicons.glyphMap;
  title: string;
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
  style?: ViewStyle;
}

export const EmptyState = React.memo<EmptyStateProps>(function EmptyState({
  icon = 'file-tray-outline',
  title,
  message,
  actionLabel,
  onAction,
  style,
}) {
  const { themeColors } = useTheme();

  return (
    <View style={[styles.container, style]}>
      <Ionicons
        name={icon}
        size={64}
        color={themeColors.textMuted}
        style={styles.icon}
      />
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>
        {title}
      </Text>
      {message ? (
        <Text style={[styles.message, { color: themeColors.textSecondary }]}>
          {message}
        </Text>
      ) : null}
      {actionLabel && onAction ? (
        <Button
          title={actionLabel}
          onPress={onAction}
          variant="primary"
          size="md"
          style={styles.action}
        />
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xxxl,
  },
  icon: {
    marginBottom: spacing.lg,
  },
  title: {
    ...typography.headingM,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  message: {
    ...typography.body,
    textAlign: 'center',
    marginBottom: spacing.xl,
  },
  action: {
    marginTop: spacing.md,
  },
});
