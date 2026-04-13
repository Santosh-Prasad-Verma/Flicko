/**
 * ErrorBoundary
 *
 * Catches React render errors and displays a recovery UI.
 * Requirements: 16.9, 21.4, 21.5
 */
import React, { Component, type ErrorInfo, type ReactNode } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET, colors } from '../../constants/Colors';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error for debugging — never log sensitive data
    console.error('[ErrorBoundary]', error.message, errorInfo.componentStack);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      // Note: ErrorBoundary is a class component and cannot use hooks.
      // We default to dark theme for error display. This is acceptable
      // since errors are rare and the focus is on recovery, not aesthetics.
      const theme = colors.dark;

      return (
        <View style={[styles.container, { backgroundColor: theme.bgPrimary }]}>
          <Text style={[styles.icon]}>⚠️</Text>
          <Text style={[styles.title, { color: theme.textPrimary }]}>
            Something went wrong
          </Text>
          <Text style={[styles.message, { color: theme.textSecondary }]}>
            {this.state.error?.message || 'An unexpected error occurred'}
          </Text>
          <Pressable
            onPress={this.handleRetry}
            style={[styles.retryButton, { backgroundColor: theme.accentPrimary }]}
            accessibilityRole="button"
            accessibilityLabel="Try again"
          >
            <Text style={styles.retryText}>Try Again</Text>
          </Pressable>
        </View>
      );
    }

    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xxl,
  },
  icon: {
    fontSize: 48,
    marginBottom: spacing.lg,
  },
  title: {
    ...typography.headingL,
    marginBottom: spacing.sm,
    textAlign: 'center',
  },
  message: {
    ...typography.body,
    textAlign: 'center',
    marginBottom: spacing.xxl,
  },
  retryButton: {
    paddingHorizontal: spacing.xxl,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  retryText: {
    ...typography.bodyBold,
    color: '#FFFFFF',
  },
});
