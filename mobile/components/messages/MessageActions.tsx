/**
 * Message Actions Sheet
 *
 * Discord-style long-press action menu for messages.
 * Shows message preview (avatar, author, timestamp, content),
 * quick reaction row, and full action list.
 * Includes a polished delete confirmation modal with message details.
 *
 * Requirements: Feature 32 (Message Actions)
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Modal,
  Share,
  ScrollView,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  FadeInDown,
  FadeIn,
} from 'react-native-reanimated';
import * as Clipboard from 'expo-clipboard';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../ui/Avatar';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { SPRING_SNAPPY, SPRING_BOUNCY, PRESS_SCALE_CARD } from '../../constants/Animations';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export interface MessageActionItem {
  id: string;
  label: string;
  icon: keyof typeof Ionicons.glyphMap;
  color?: string;
  destructive?: boolean;
  visible?: boolean;
}

export interface MessageActionsProps {
  visible: boolean;
  messageId: string;
  messageContent: string;
  messageCreatedAt: string;
  authorName: string;
  authorAvatar?: string;
  authorColor?: string;
  isOwnMessage: boolean;
  isPinned: boolean;
  canManageMessages: boolean;
  onReply: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
  onPin?: () => void;
  onUnpin?: () => void;
  onReact?: (emoji: string) => void;
  onAddReaction?: () => void;
  onThread?: () => void;
  onForward?: () => void;
  onBookmark?: () => void;
  onCopyId?: () => void;
  onReport?: () => void;
  onClose: () => void;
}

/** Format timestamp for display */
function formatActionTime(dateStr: string): string {
  const d = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const timeStr = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;

  const isToday =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  if (isToday) return `Today at ${timeStr}`;

  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const isYesterday =
    d.getFullYear() === yesterday.getFullYear() &&
    d.getMonth() === yesterday.getMonth() &&
    d.getDate() === yesterday.getDate();
  if (isYesterday) return `Yesterday at ${timeStr}`;

  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${month}/${day}/${d.getFullYear()} ${timeStr}`;
}

/** Full date/time for delete confirmation */
function formatDeleteTimestamp(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleString(undefined, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

/** Quick reaction emoji with bounce on press */
const QuickReactionButton = memo(function QuickReactionButton({
  emoji,
  bgColor,
  onPress,
}: { emoji: string; bgColor: string; onPress: () => void }) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      onPressIn={() => { scale.value = withSpring(0.85, SPRING_SNAPPY); }}
      onPressOut={() => { scale.value = withSpring(1, SPRING_BOUNCY); }}
      onPress={onPress}
      style={[styles.quickReaction, { backgroundColor: bgColor }, animStyle]}
    >
      <Text style={styles.quickReactionEmoji}>{emoji}</Text>
    </AnimatedPressable>
  );
});

/** Action row with press scale feedback */
const ActionRowButton = memo(function ActionRowButton({
  action,
  dangerColor,
  textPrimaryColor,
  textSecondaryColor,
  onPress,
  isLast,
}: {
  action: MessageActionItem;
  dangerColor: string;
  textPrimaryColor: string;
  textSecondaryColor: string;
  onPress: () => void;
  isLast?: boolean;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      onPressIn={() => { scale.value = withSpring(PRESS_SCALE_CARD, SPRING_SNAPPY); }}
      onPressOut={() => { scale.value = withSpring(1, SPRING_SNAPPY); }}
      onPress={onPress}
      style={[styles.actionRow, isLast && styles.actionRowLast, animStyle]}
    >
      <Ionicons
        name={action.icon}
        size={20}
        color={action.destructive ? dangerColor : action.color || textSecondaryColor}
      />
      <Text
        style={[
          styles.actionLabel,
          { color: action.destructive ? dangerColor : action.color || textPrimaryColor },
        ]}
      >
        {action.label}
      </Text>
    </AnimatedPressable>
  );
});

/** ─── Delete Confirmation Modal ──────────────────────────────────────────── */
const DeleteConfirmation = memo(function DeleteConfirmation({
  visible,
  messageContent,
  messageCreatedAt,
  authorName,
  authorAvatar,
  authorColor,
  onConfirm,
  onCancel,
}: {
  visible: boolean;
  messageContent: string;
  messageCreatedAt: string;
  authorName: string;
  authorAvatar?: string;
  authorColor?: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const { themeColors: c } = useTheme();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={onCancel}
    >
      <Pressable style={styles.deleteOverlay} onPress={onCancel}>
        <Pressable
          style={[styles.deleteCard, { backgroundColor: c.bgSecondary }]}
          onPress={(e) => e.stopPropagation()}
        >
          {/* Title */}
          <Text style={[styles.deleteTitle, { color: c.danger }]}>Delete Message</Text>
          <Text style={[styles.deleteSubtitle, { color: c.textSecondary }]}>
            Are you sure you want to delete this message? This cannot be undone.
          </Text>

          {/* Message preview card */}
          <View style={[styles.deletePreviewCard, { backgroundColor: c.bgTertiary }]}>
            <View style={styles.deletePreviewHeader}>
              <Avatar
                name={authorName}
                imageUrl={authorAvatar}
                size={32}
              />
              <View style={styles.deletePreviewMeta}>
                <Text style={[styles.deletePreviewAuthor, { color: authorColor || c.textPrimary }]}>
                  {authorName}
                </Text>
                <Text style={[styles.deletePreviewTime, { color: c.textMuted }]}>
                  {formatDeleteTimestamp(messageCreatedAt)}
                </Text>
              </View>
            </View>
            <Text
              style={[styles.deletePreviewContent, { color: c.textPrimary }]}
              numberOfLines={4}
            >
              {messageContent}
            </Text>
          </View>

          {/* Buttons */}
          <View style={styles.deleteButtons}>
            <Pressable
              onPress={onCancel}
              style={[styles.deleteBtn, styles.deleteCancelBtn, { backgroundColor: c.bgTertiary }]}
            >
              <Text style={[styles.deleteBtnText, { color: c.textPrimary }]}>Cancel</Text>
            </Pressable>
            <Pressable
              onPress={onConfirm}
              style={[styles.deleteBtn, styles.deleteConfirmBtn, { backgroundColor: c.danger }]}
            >
              <Ionicons name="trash-outline" size={16} color="#fff" style={{ marginRight: 6 }} />
              <Text style={[styles.deleteBtnText, { color: '#fff' }]}>Delete</Text>
            </Pressable>
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
});

/** ─── Main MessageActions Component ──────────────────────────────────────── */
export const MessageActions = memo(function MessageActions({
  visible,
  messageId,
  messageContent,
  messageCreatedAt,
  authorName,
  authorAvatar,
  authorColor,
  isOwnMessage,
  isPinned,
  canManageMessages,
  onReply,
  onEdit,
  onDelete,
  onPin,
  onUnpin,
  onReact,
  onAddReaction,
  onThread,
  onForward,
  onBookmark,
  onCopyId,
  onReport,
  onClose,
}: MessageActionsProps) {
  const { themeColors: c } = useTheme();
  const [deleteConfirmVisible, setDeleteConfirmVisible] = useState(false);

  const handleCopy = useCallback(async () => {
    await Clipboard.setStringAsync(messageContent);
    onClose();
  }, [messageContent, onClose]);

  const handleShare = useCallback(async () => {
    try {
      await Share.share({ message: messageContent });
    } catch { }
    onClose();
  }, [messageContent, onClose]);

  const handleDeleteRequest = useCallback(() => {
    setDeleteConfirmVisible(true);
  }, []);

  const handleDeleteConfirm = useCallback(() => {
    setDeleteConfirmVisible(false);
    onDelete?.();
    onClose();
  }, [onDelete, onClose]);

  const handleDeleteCancel = useCallback(() => {
    setDeleteConfirmVisible(false);
  }, []);

  const handleQuickReaction = useCallback((emoji: string) => {
    onReact?.(emoji);
    onClose();
  }, [onReact, onClose]);

  const actions = ([
    { id: 'reply', label: 'Reply', icon: 'arrow-undo' as const, visible: true },
    { id: 'forward', label: 'Forward', icon: 'arrow-redo' as const, visible: true },
    { id: 'react', label: 'Add Reaction', icon: 'happy-outline' as const, visible: true },
    { id: 'thread', label: 'Create Thread', icon: 'chatbubbles-outline' as const, visible: true },
    { id: 'bookmark', label: 'Save Message', icon: 'bookmark-outline' as const, visible: true },
    { id: 'copy', label: 'Copy Text', icon: 'copy-outline' as const, visible: true },
    { id: 'copyId', label: 'Copy Message ID', icon: 'code-outline' as const, visible: true },
    { id: 'share', label: 'Share', icon: 'share-outline' as const, visible: true },
    { id: 'pin', label: isPinned ? 'Unpin Message' : 'Pin Message', icon: 'pin' as const, visible: canManageMessages },
    { id: 'edit', label: 'Edit Message', icon: 'create-outline' as const, visible: isOwnMessage },
    { id: 'delete', label: 'Delete Message', icon: 'trash-outline' as const, destructive: true, visible: isOwnMessage || canManageMessages },
    { id: 'report', label: 'Report Message', icon: 'flag-outline' as const, color: c.warning, visible: !isOwnMessage },
  ] satisfies MessageActionItem[]).filter((a) => a.visible !== false);

  const handleAction = (id: string) => {
    switch (id) {
      case 'reply': onReply(); onClose(); break;
      case 'forward': onForward?.(); onClose(); break;
      case 'react': onAddReaction?.(); onClose(); break;
      case 'thread': onThread?.(); onClose(); break;
      case 'bookmark': onBookmark?.(); onClose(); break;
      case 'copy': handleCopy(); break;
      case 'copyId': Clipboard.setStringAsync(messageId); onClose(); break;
      case 'share': handleShare(); break;
      case 'pin': isPinned ? onUnpin?.() : onPin?.(); onClose(); break;
      case 'edit': onEdit?.(); onClose(); break;
      case 'delete': handleDeleteRequest(); break;
      case 'report': onReport?.(); onClose(); break;
    }
  };

  if (!visible) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      statusBarTranslucent
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose}>
        <Pressable
          style={[styles.container, { backgroundColor: c.bgFloating }]}
          onPress={(e) => e.stopPropagation()}
        >
          {/* Drag handle */}
          <View style={styles.handleWrap}>
            <View style={[styles.handle, { backgroundColor: c.textMuted + '50' }]} />
          </View>

          {/* Message preview with avatar */}
          <View style={[styles.preview, { borderBottomColor: c.border }]}>
            <View style={styles.previewHeader}>
              <Avatar
                name={authorName}
                imageUrl={authorAvatar}
                size={28}
              />
              <Text style={[styles.previewAuthor, { color: authorColor || c.textPrimary }]} numberOfLines={1}>
                {authorName}
              </Text>
              <Text style={[styles.previewTimestamp, { color: c.textMuted }]}>
                {formatActionTime(messageCreatedAt)}
              </Text>
            </View>
            <Text style={[styles.previewText, { color: c.textSecondary }]} numberOfLines={2}>
              {messageContent}
            </Text>
          </View>

          {/* Quick reactions row */}
          <View style={styles.quickReactions}>
            {['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji, i) => (
              <Animated.View key={emoji} entering={FadeInDown.delay(i * 40).duration(200).springify()}>
                <QuickReactionButton
                  emoji={emoji}
                  bgColor={c.bgSecondary}
                  onPress={() => handleQuickReaction(emoji)}
                />
              </Animated.View>
            ))}
          </View>

          {/* Actions list */}
          <ScrollView style={styles.actionsScroll} bounces={false}>
            <View style={[styles.actionsContainer, { backgroundColor: c.bgSecondary, borderColor: c.border }]}> 
              {actions.map((action, i) => (
                <Animated.View key={action.id} entering={FadeInDown.delay(60 + i * 30).duration(200).springify()}>
                  {i > 0 && <View style={[styles.separator, { backgroundColor: c.border }]} />}
                  <ActionRowButton
                    action={action}
                    dangerColor={c.danger}
                    textPrimaryColor={c.textPrimary}
                    textSecondaryColor={c.textSecondary}
                    onPress={() => handleAction(action.id)}
                    isLast={i === actions.length - 1}
                  />
                </Animated.View>
              ))}
            </View>
          </ScrollView>
        </Pressable>
      </Pressable>

      {/* Delete confirmation overlay */}
      <DeleteConfirmation
        visible={deleteConfirmVisible}
        messageContent={messageContent}
        messageCreatedAt={messageCreatedAt}
        authorName={authorName}
        authorAvatar={authorAvatar}
        authorColor={authorColor}
        onConfirm={handleDeleteConfirm}
        onCancel={handleDeleteCancel}
      />
    </Modal>
  );
});

const styles = StyleSheet.create({
  /* ── Backdrop & container ─────────────────────── */
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'flex-end',
  },
  container: {
    borderTopLeftRadius: borderRadius.lg,
    borderTopRightRadius: borderRadius.lg,
    paddingBottom: spacing.lg,
    maxHeight: '72%',
    marginHorizontal: spacing.sm,
    marginBottom: spacing.sm,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.28,
    shadowRadius: 20,
    elevation: 8,
  },
  handleWrap: {
    alignItems: 'center',
    paddingTop: spacing.sm,
    paddingBottom: spacing.xs,
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
  },

  /* ── Message preview ──────────────────────────── */
  preview: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
  },
  previewHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: 6,
  },
  previewAuthor: {
    fontSize: 14,
    fontFamily: 'gg-sans-bold',
    flex: 1,
  },
  previewTimestamp: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
  },
  previewText: { ...typography.bodySmall },

  /* ── Quick reactions ──────────────────────────── */
  quickReactions: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  quickReaction: {
    width: 38,
    height: 38,
    borderRadius: borderRadius.sm,
    justifyContent: 'center',
    alignItems: 'center',
  },
  quickReactionEmoji: { fontSize: 19 },

  /* ── Actions list ─────────────────────────────── */
  actionsScroll: {
    paddingHorizontal: spacing.md,
  },
  actionsContainer: {
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    minHeight: 40,
    gap: spacing.sm,
  },
  actionRowLast: {
    // No extra style needed for now
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    marginHorizontal: spacing.lg,
  },
  actionLabel: { ...typography.bodySmall, fontFamily: 'gg-sans-medium', fontSize: 13.5 },

  /* ── Delete confirmation ──────────────────────── */
  deleteOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  deleteCard: {
    width: '100%',
    maxWidth: 400,
    borderRadius: borderRadius.xl,
    padding: spacing.xl,
  },
  deleteTitle: {
    fontSize: 20,
    fontFamily: 'gg-sans-bold',
    marginBottom: spacing.xs,
  },
  deleteSubtitle: {
    fontSize: 14,
    lineHeight: 20,
    marginBottom: spacing.lg,
  },
  deletePreviewCard: {
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    marginBottom: spacing.xl,
  },
  deletePreviewHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  deletePreviewMeta: {
    flex: 1,
  },
  deletePreviewAuthor: {
    fontSize: 14,
    fontFamily: 'gg-sans-bold',
  },
  deletePreviewTime: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
    marginTop: 1,
  },
  deletePreviewContent: {
    fontSize: 14,
    lineHeight: 20,
  },
  deleteButtons: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  deleteBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: borderRadius.md,
  },
  deleteCancelBtn: {},
  deleteConfirmBtn: {},
  deleteBtnText: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },
});
