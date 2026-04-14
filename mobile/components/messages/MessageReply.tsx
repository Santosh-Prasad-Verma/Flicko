/**
 * MessageReply Component
 *
 * Displays a compact reply preview above a message, showing the
 * original author's avatar/name and a 2-line truncated content preview.
 * Tappable to scroll to the original message.
 *
 * Also used in the MessageInput to show the reply-to bar before sending.
 *
 * Requirements: Feature 6 (Message Reply System)
 */
import React, { memo } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';

interface MessageReplyProps {
  /** Author name of the replied-to message */
  authorName: string;
  /** Author avatar color (role color) */
  authorColor?: string;
  /** Content of the replied-to message */
  content: string;
  /** Called when tapped to jump to the original message */
  onPress?: () => void;
  /** Compact variant (used in message input) */
  compact?: boolean;
  /** Called when the close/cancel button is pressed (input mode) */
  onCancel?: () => void;
}

export const MessageReply = memo(function MessageReply({
  authorName,
  authorColor,
  content,
  onPress,
  compact = false,
  onCancel,
}: MessageReplyProps) {
  const { themeColors } = useTheme();
  const nameColor = authorColor || themeColors.accentPrimary;

  if (compact) {
    return (
      <View style={[styles.compactContainer, { backgroundColor: themeColors.bgTertiary }]}>
        <View style={[styles.compactIndicator, { backgroundColor: themeColors.accentPrimary }]} />
        <View style={styles.compactContent}>
          <Text style={[styles.compactLabel, { color: themeColors.accentPrimary }]}>
            Replying to{' '}
            <Text style={{ color: nameColor, fontFamily: 'gg-sans-bold' }}>{authorName}</Text>
          </Text>
          <Text
            style={[styles.compactPreview, { color: themeColors.textMuted }]}
            numberOfLines={1}
          >
            {content || 'Message deleted'}
          </Text>
        </View>
        {onCancel && (
          <Pressable onPress={onCancel} hitSlop={12} style={styles.cancelBtn}>
            <Ionicons name="close" size={18} color={themeColors.textMuted} />
          </Pressable>
        )}
      </View>
    );
  }

  return (
    <Pressable
      onPress={onPress}
      style={[styles.container, { borderLeftColor: nameColor }]}
      accessibilityLabel={`Reply to ${authorName}: ${content}`}
      accessibilityRole="button"
    >
      <Ionicons name="return-up-back" size={12} color={themeColors.textMuted} />
      <Text style={[styles.authorName, { color: nameColor }]} numberOfLines={1}>
        {authorName}
      </Text>
      <Text style={[styles.preview, { color: themeColors.textMuted }]} numberOfLines={2}>
        {content || 'Original message was deleted'}
      </Text>
    </Pressable>
  );
});

const styles = StyleSheet.create({
  // Inline reply preview (in message bubble)
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingLeft: spacing.sm,
    borderLeftWidth: 2,
    marginBottom: 4,
    paddingVertical: 2,
  },
  authorName: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
  },
  preview: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    flex: 1,
  },

  // Compact variant (message input bar)
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: borderRadius.sm,
    marginBottom: spacing.sm,
    overflow: 'hidden',
  },
  compactIndicator: {
    width: 4,
    alignSelf: 'stretch',
  },
  compactContent: {
    flex: 1,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
  },
  compactLabel: {
    ...typography.caption,
    fontFamily: 'gg-sans-semibold',
  },
  compactPreview: {
    ...typography.caption,
    marginTop: 2,
  },
  cancelBtn: {
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
  },
});
