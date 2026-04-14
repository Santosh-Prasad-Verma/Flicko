/**
 * MessageItem Component
 *
 * Renders a single message with avatar, author, timestamp, content, reactions,
 * reply preview, inline editing, and context menu actions.
 *
 * Supports message grouping:
 * - First message in a group: avatar (40×40), username, timestamp, 16px top padding
 * - Continuation message (same author, <7 min): no avatar/name/time, 2px top padding
 *
 * Enhanced system messages with per-type icons and colors.
 * Markdown rendering via MarkdownText component.
 *
 * Features:
 * - Long-press context menu: Reply, Edit, Delete, Add Reaction, Create Thread, Copy
 * - Avatar tap → open user profile sheet; avatar long-press → quick actions
 * - Username tap → insert @mention in input
 * - Inline editing mode with save/cancel
 * - Reply-to preview bar (shows parent message snippet, tappable to scroll)
 * - Reaction bar with toggle support and add-reaction button
 * - (edited) timestamp indicator
 * - Rich system message display (join, leave, pin, boost)
 *
 * Requirements: 5.5, 5.6, 5.9, 25.1, 27
 */
import React, { memo, useCallback, useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withSequence,
  withTiming,
  FadeIn,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { Avatar } from '../ui/Avatar';
import { MarkdownText } from './MarkdownText';
import { AttachmentList } from './AttachmentList';
import { spacing, typography, borderRadius, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';
import { SPRING_SNAPPY, SPRING_BOUNCY, PRESS_SCALE_CARD, TIMING_FAST } from '../../constants/Animations';
import { MessageComponents, EphemeralBanner } from './MessageComponents';
import type { ActionRow } from '@stores/interactionStore';
import { useSettingsStore } from '@stores/settingsStore';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

// ─── Layout constants (spec) ───────────────────────────────────────────────────
/** Avatar circle diameter */
const AVATAR_SIZE = 40;
/** Left margin of avatar from screen edge */
const SCREEN_PADDING = 16;
/** Gap between avatar right edge and text column */
const AVATAR_TEXT_GAP = 16;
/** Total left offset of content column from screen edge: 16 + 40 + 16 = 72 */
const CONTENT_LEFT = SCREEN_PADDING + AVATAR_SIZE + AVATAR_TEXT_GAP; // 72
/** Maximum gap in minutes to group messages from the same author */
const GROUP_GAP_MINUTES = 7;

export interface MessageData {
  id: string;
  content: string;
  author_id: string | null;
  created_at: string;
  edited?: boolean;
  edited_at?: string | null;
  updated_at?: string | null;
  type?: 'default' | 'reply' | 'system' | 'forwarded';
  system_type?: 'join' | 'leave' | 'pin' | 'boost' | 'member_join' | 'member_boost' | 'pin_add' | 'thread_create' | 'channel_name_change' | 'group_add' | 'group_remove' | 'group_icon_change';
  reply_to_id?: string | null;
  thread_id?: string | null;
  reactions?: { emoji: string; count: number; me: boolean; users?: string[] }[];
  author?: {
    id: string;
    username?: string;
    display_name?: string;
    avatar_url?: string;
    role_color?: string;
    role_icon?: string;
  };
  reply_to?: {
    id: string;
    content: string;
    author?: {
      username?: string;
      display_name?: string;
    };
  } | null;
  thread?: {
    id: string;
    name: string;
    message_count: number;
  } | null;
  components?: ActionRow[];
  flags?: number; // 64 = ephemeral
  server_id?: string;
  // Feature 2: Message Forwarding
  forwarded_from_id?: string | null;
  forwarded_from_server?: string | null;
  forwarded_from_channel?: string | null;
  forwarded_author?: {
    username?: string;
    display_name?: string;
    avatar_url?: string;
  } | null;
  // Feature 3: Silent Messages
  is_silent?: boolean;
  // Feature 4: TTS
  is_tts?: boolean;
  // Feature 7: Reply Ping Toggle
  reply_mention?: boolean;
  // Feature 11: Image Alt Text
  attachments?: any[];
  // Feature 27: Role Icons
  role_icon?: string;
}

interface MessageItemProps {
  message: MessageData;
  /** When true the message is a continuation of the previous group (same author, <7 min). */
  isContinuation?: boolean;
  currentUserId?: string;
  onReply?: (message: MessageData) => void;
  onEdit?: (message: MessageData) => void;
  onDelete?: (messageId: string) => void;
  onReaction?: (messageId: string, emoji: string) => void;
  onAddReaction?: (messageId: string) => void;
  onReactionDetail?: (messageId: string, emoji: string) => void;
  onCreateThread?: (message: MessageData) => void;
  onOpenThread?: (threadId: string) => void;
  onJumpToMessage?: (messageId: string) => void;
  onEditSubmit?: (messageId: string, content: string) => void;
  onMention?: (userId: string, username: string) => void;
  onOpenProfile?: (userId: string) => void;
  onForward?: (message: MessageData) => void;
  /** Called on long-press to show the Discord-style action sheet */
  onMessageLongPress?: (message: MessageData) => void;
}

const QUICK_REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

// ─── Helpers ───────────────────────────────────────────────────────────────────

/** Returns true when two messages belong to the same visual group. */
export function isSameGroup(prev: MessageData, cur: MessageData): boolean {
  if (prev.author_id !== cur.author_id) return false;
  if (prev.type === 'system' || cur.type === 'system') return false;
  const diffMs = Math.abs(
    new Date(cur.created_at).getTime() - new Date(prev.created_at).getTime(),
  );
  return diffMs < GROUP_GAP_MINUTES * 60_000;
}

/**
 * Formats a timestamp per spec:
 *   <1 min  → "Just now"
 *   <1 h    → "X minutes ago"
 *   Today   → "Today at 12:34 PM"
 *   Yesterday → "Yesterday at 12:34 PM"
 *   Older   → "01/15/2026 12:34 PM"
 */
function formatTime(dateStr: string): string {
  const d = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffMins = Math.floor(diffMs / 60000);

  const timeStr = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins} minute${diffMins === 1 ? '' : 's'} ago`;

  // Check same calendar day
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

/** Full timestamp for continuation hover tooltip. */
function formatFullTimestamp(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
  });
}

// ─── System message helpers ────────────────────────────────────────────────────

// System message icon configurations - colors are semantic and remain fixed across themes
const SYSTEM_ICONS: Record<string, { name: keyof typeof Ionicons.glyphMap; color: string }> = {
  join: { name: 'arrow-forward-circle', color: '#2ECC71' }, // Green for positive actions
  member_join: { name: 'arrow-forward-circle', color: '#2ECC71' },
  leave: { name: 'arrow-back-circle', color: '#FF4757' }, // Red for negative actions
  pin: { name: 'pin', color: '#6C5CE7' }, // Purple for pin actions
  pin_add: { name: 'pin', color: '#6C5CE7' },
  boost: { name: 'rocket', color: '#FF6B81' }, // Pink for boost actions
  member_boost: { name: 'rocket', color: '#FF6B81' },
  thread_create: { name: 'chatbubbles-outline', color: '#00B4D8' }, // Blue for thread actions
  channel_name_change: { name: 'pencil', color: '#FFA500' }, // Orange for edit actions
  group_add: { name: 'person-add', color: '#2ECC71' }, // Green for add actions
  group_remove: { name: 'person-remove', color: '#FF4757' }, // Red for remove actions
  group_icon_change: { name: 'image', color: '#9B59B6' }, // Purple for icon changes
};

// Random join messages for variety (Feature 40: System Messages Enhanced)
const JOIN_MESSAGES = [
  'joined the server. Welcome!',
  'just slid into the server.',
  'just showed up. Hold my beer.',
  'hopped into the server.',
  'appeared. Everyone look busy!',
  'is here — the party can start now.',
  'just landed!',
  'arrived. Wave hello! 👋',
];

function getJoinMessage(): string {
  return JOIN_MESSAGES[Math.floor(Math.random() * JOIN_MESSAGES.length)];
}

// ─── Component ─────────────────────────────────────────────────────────────────

export const MessageItem = memo(function MessageItem({
  message,
  isContinuation = false,
  currentUserId,
  onReply,
  onEdit,
  onDelete,
  onReaction,
  onAddReaction,
  onReactionDetail,
  onCreateThread,
  onOpenThread,
  onJumpToMessage,
  onEditSubmit,
  onMention,
  onOpenProfile,
  onForward,
  onMessageLongPress,
}: MessageItemProps) {
  const { themeColors } = useTheme();
  const messageDisplay = useSettingsStore((s) => s.messageDisplay);
  const fontSize = useSettingsStore((s) => s.fontSize);
  const isOwn = message.author_id === currentUserId;
  const authorName =
    message.author?.display_name || message.author?.username || 'Unknown';
  const authorColor = message.author?.role_color || themeColors.textPrimary;

  // Inline editing state
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(message.content);
  const [showContinuationTime, setShowContinuationTime] = useState(false);
  const editInputRef = useRef<TextInput>(null);

  // Animation: press scale for message container
  const msgScale = useSharedValue(1);
  const msgAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: msgScale.value }],
  }));
  const handlePressIn = useCallback(() => {
    msgScale.value = withSpring(PRESS_SCALE_CARD, SPRING_SNAPPY);
  }, []);
  const handlePressOut = useCallback(() => {
    msgScale.value = withSpring(1, SPRING_SNAPPY);
  }, []);

  const handleStartEdit = useCallback(() => {
    setEditText(message.content);
    setIsEditing(true);
    setTimeout(() => editInputRef.current?.focus(), 100);
  }, [message.content]);

  const handleSaveEdit = useCallback(() => {
    const trimmed = editText.trim();
    if (trimmed && trimmed !== message.content) {
      onEditSubmit?.(message.id, trimmed);
    }
    setIsEditing(false);
  }, [editText, message.content, message.id, onEditSubmit]);

  const handleCancelEdit = useCallback(() => {
    setEditText(message.content);
    setIsEditing(false);
  }, [message.content]);

  // Avatar interactions
  const handleAvatarPress = useCallback(() => {
    onOpenProfile?.(message.author_id);
  }, [message.author_id, onOpenProfile]);

  // Username tap → insert @mention
  const handleUsernamePress = useCallback(() => {
    const uname = message.author?.username || message.author?.display_name || 'Unknown';
    onMention?.(message.author_id, uname);
  }, [message.author_id, message.author, onMention]);

  const handleLongPress = useCallback(() => {
    // For continuation messages, toggle full timestamp tooltip
    if (isContinuation) {
      setShowContinuationTime((v) => !v);
    }
    // Delegate to parent to show Discord-style action sheet
    onMessageLongPress?.(message);
  }, [message, isContinuation, onMessageLongPress]);

  // ── System messages ────────────────────────────────────────────────────────
  if (message.type === 'system') {
    const sysType = message.system_type || 'join';
    const iconCfg = SYSTEM_ICONS[sysType] || SYSTEM_ICONS.join;
    const timeStr = formatTime(message.created_at);

    // Try to extract the username portion from the content (text before the verb)
    // e.g. "Username joined the server." → bold "Username"
    const usernameEnd = message.content.indexOf(' ');
    const sysUsername = usernameEnd > 0 ? message.content.slice(0, usernameEnd) : '';
    const sysRest = usernameEnd > 0 ? message.content.slice(usernameEnd) : message.content;

    return (
      <View style={styles.systemMessage}>
        <View style={styles.systemRow}>
          <Ionicons name={iconCfg.name} size={16} color={iconCfg.color} />
          <Text style={[styles.systemBodyText, { color: themeColors.textMuted }]}>
            {sysUsername ? (
              <Text
                style={[styles.systemUsername, { color: themeColors.textPrimary }]}
                onPress={() => {
                  if (message.author_id) onOpenProfile?.(message.author_id);
                }}
              >
                {sysUsername}
              </Text>
            ) : null}
            {sysRest}
          </Text>
          <Text style={[styles.systemTimestamp, { color: themeColors.textMuted }]}>
            {timeStr}
          </Text>
        </View>
      </View>
    );
  }

  // ── Compact Mode (Feature 34) ──────────────────────────────────────────────
  if (messageDisplay === 'compact') {
    return (
      <AnimatedPressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        onLongPress={handleLongPress}
        style={[styles.compactContainer, msgAnimStyle]}
        accessibilityRole="text"
        accessibilityLabel={`${authorName} said ${message.content}`}
      >
        <Text style={[styles.compactTimestamp, { color: themeColors.textMuted }]}>
          {formatTime(message.created_at)}
        </Text>
        <Pressable onPress={handleUsernamePress}>
          <Text style={[styles.compactAuthor, { color: authorColor }]}>{authorName}</Text>
        </Pressable>
        {message.is_silent && (
          <Text style={{ fontSize: 12, marginHorizontal: 2 }}>🔕</Text>
        )}
        <View style={styles.compactContent}>
          <MarkdownText content={message.content} color={themeColors.textPrimary} fontSize={fontSize} />
          {message.edited && (
            <Text style={[styles.edited, { color: themeColors.textMuted }]}> (edited)</Text>
          )}
        </View>
      </AnimatedPressable>
    );
  }

  // ── Continuation message (same author, <7 min) ────────────────────────────
  if (isContinuation) {
    return (
      <AnimatedPressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        onLongPress={handleLongPress}
        style={[
          styles.continuationContainer,
          isEditing && { backgroundColor: themeColors.bgTertiary },
          msgAnimStyle,
        ]}
        accessibilityRole="text"
        accessibilityLabel={`${authorName} said ${message.content}`}
      >
        {/* Timestamp tooltip area (left of content, shown on long-press) */}
        {showContinuationTime && (
          <View style={[styles.continuationTooltip, { backgroundColor: themeColors.bgTertiary }]}>
            <Text style={[styles.continuationTooltipText, { color: themeColors.textPrimary }]}>
              {formatFullTimestamp(message.created_at)}
            </Text>
          </View>
        )}
        <View style={styles.continuationBody}>
          {isEditing ? (
            <View style={styles.editContainer}>
              <TextInput
                ref={editInputRef}
                value={editText}
                onChangeText={setEditText}
                multiline
                maxLength={2000}
                style={[
                  styles.editInput,
                  {
                    color: themeColors.textPrimary,
                    backgroundColor: themeColors.bgPrimary,
                    borderColor: themeColors.accentPrimary,
                  },
                ]}
                autoFocus
              />
              <View style={styles.editActions}>
                <Text style={[styles.editHint, { color: themeColors.textMuted }]}>
                  escape to cancel · enter to save
                </Text>
                <View style={styles.editButtons}>
                  <Pressable onPress={handleCancelEdit} style={styles.editBtn}>
                    <Text style={{ color: themeColors.danger, fontSize: 13 }}>Cancel</Text>
                  </Pressable>
                  <Pressable
                    onPress={handleSaveEdit}
                    style={[styles.editBtn, { backgroundColor: themeColors.accentPrimary, borderRadius: borderRadius.sm }]}
                  >
                    <Text style={{ color: themeColors.textPrimary, fontSize: 13, fontFamily: 'gg-sans-semibold' }}>Save</Text>
                  </Pressable>
                </View>
              </View>
            </View>
          ) : (
            <>
              <MarkdownText content={message.content} color={themeColors.textPrimary} fontSize={fontSize} />
              <AttachmentList attachments={message.attachments || []} onLongPress={handleLongPress} />
            </>
          )}
          {message.edited && (
            <Text style={[styles.edited, { color: themeColors.textMuted }]}> (edited)</Text>
          )}

          {/* Interactive message components (buttons, selects) */}
          {message.components && message.components.length > 0 && (
            <MessageComponents
              components={message.components}
              guildId={message.server_id ?? ''}
              channelId={''}
              messageId={message.id}
            />
          )}
          {(message.flags ?? 0) & 64 ? <EphemeralBanner themeColors={themeColors} /> : null}

          {/* Thread indicator */}
          {message.thread && (
            <Pressable
              onPress={() => onOpenThread?.(message.thread!.id)}
              style={[styles.threadBar, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons name="chatbubbles-outline" size={14} color={themeColors.accentPrimary} />
              <Text style={[styles.threadText, { color: themeColors.accentPrimary }]}>
                {message.thread.name}
              </Text>
              <Text style={[styles.threadCount, { color: themeColors.textMuted }]}>
                {message.thread.message_count} {message.thread.message_count === 1 ? 'message' : 'messages'}
              </Text>
              <Ionicons name="chevron-forward" size={14} color={themeColors.textMuted} />
            </Pressable>
          )}

          {/* Reactions */}
          {message.reactions && message.reactions.length > 0 && (
            <View style={styles.reactionsRow}>
              {message.reactions.map((r) => (
                <Pressable
                  key={r.emoji}
                  onPress={() => onReaction?.(message.id, r.emoji)}
                  onLongPress={() => onReactionDetail?.(message.id, r.emoji)}
                  style={[
                    styles.reactionChip,
                    {
                      backgroundColor: r.me ? themeColors.accentPrimary + '30' : themeColors.bgTertiary,
                      borderColor: r.me ? themeColors.accentPrimary : 'transparent',
                    },
                  ]}
                  accessibilityLabel={`${r.emoji} reaction, ${r.count} ${r.count === 1 ? 'person' : 'people'}`}
                >
                  <Text style={styles.reactionEmoji}>{r.emoji}</Text>
                  <Text style={[styles.reactionCount, { color: r.me ? themeColors.accentPrimary : themeColors.textSecondary }]}>
                    {r.count}
                  </Text>
                </Pressable>
              ))}
              <Pressable
                onPress={() => onAddReaction?.(message.id)}
                style={[styles.addReactionBtn, { backgroundColor: themeColors.bgTertiary, borderColor: themeColors.border }]}
                accessibilityLabel="Add reaction"
              >
                <Ionicons name="happy-outline" size={14} color={themeColors.textMuted} />
              </Pressable>
            </View>
          )}
        </View>
      </AnimatedPressable>
    );
  }

  // ── First message in group (full header with avatar) ───────────────────────
  return (
    <AnimatedPressable
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      onLongPress={handleLongPress}
      style={[
        styles.container,
        isEditing && { backgroundColor: themeColors.bgTertiary },
        msgAnimStyle,
      ]}
      accessibilityRole="text"
      accessibilityLabel={`${authorName} said ${message.content}`}
    >
      {/* Avatar: 40×40 circle, tap → profile, long-press → quick actions */}
      <Pressable
        onPress={handleAvatarPress}
        onLongPress={() => {
          if (message.author_id) onOpenProfile?.(message.author_id);
        }}
        style={styles.avatarWrap}
      >
        <Avatar
          name={authorName}
          imageUrl={message.author?.avatar_url}
          size={AVATAR_SIZE}
        />
      </Pressable>

      <View style={styles.body}>
        {/* Forwarded message label (Feature 2) */}
        {message.type === 'forwarded' && message.forwarded_from_channel && (
          <View style={styles.forwardedLabel}>
            <Ionicons name="arrow-redo" size={12} color={themeColors.textMuted} />
            <Text style={[styles.forwardedText, { color: themeColors.textMuted }]}>
              Forwarded from {message.forwarded_from_server ? `${message.forwarded_from_server} · ` : ''}#{message.forwarded_from_channel}
            </Text>
          </View>
        )}

        {/* Reply-to preview */}
        {message.reply_to && (
          <Pressable
            onPress={() => onJumpToMessage?.(message.reply_to!.id)}
            style={[styles.replyPreview, { borderLeftColor: themeColors.accentPrimary }]}
          >
            <Ionicons name="return-up-back" size={12} color={themeColors.textMuted} />
            <Text style={[styles.replyAuthor, { color: themeColors.accentPrimary }]} numberOfLines={1}>
              {message.reply_to.author?.display_name || message.reply_to.author?.username || 'Unknown'}
            </Text>
            <Text style={[styles.replyText, { color: themeColors.textMuted }]} numberOfLines={1}>
              {message.reply_to.content}
            </Text>
          </Pressable>
        )}

        {/* Header: author (tappable for @mention) + role icon + timestamp + silent icon + edited */}
        <View style={styles.headerRow}>
          <Pressable onPress={handleUsernamePress}>
            <Text style={[styles.author, { color: authorColor }]}>
              {authorName}
            </Text>
          </Pressable>
          {/* Role icon (Feature 27) */}
          {message.author?.role_icon && (
            <Image
              source={{ uri: message.author.role_icon }}
              style={styles.roleIcon}
            />
          )}
          <Text style={[styles.timestamp, { color: themeColors.textMuted }]}>
            {formatTime(message.created_at)}
          </Text>
          {/* Silent message icon (Feature 3) */}
          {message.is_silent && (
            <Text style={[styles.silentIcon, { color: themeColors.textMuted }]}>🔕</Text>
          )}
          {message.edited && (
            <Text style={[styles.edited, { color: themeColors.textMuted }]}>
              (edited)
            </Text>
          )}
        </View>

        {/* Content or inline edit */}
        {isEditing ? (
          <View style={styles.editContainer}>
            <TextInput
              ref={editInputRef}
              value={editText}
              onChangeText={setEditText}
              multiline
              maxLength={2000}
              style={[
                styles.editInput,
                {
                  color: themeColors.textPrimary,
                  backgroundColor: themeColors.bgPrimary,
                  borderColor: themeColors.accentPrimary,
                },
              ]}
              autoFocus
            />
            <View style={styles.editActions}>
              <Text style={[styles.editHint, { color: themeColors.textMuted }]}>
                escape to cancel · enter to save
              </Text>
              <View style={styles.editButtons}>
                <Pressable onPress={handleCancelEdit} style={styles.editBtn}>
                  <Text style={{ color: themeColors.danger, fontSize: 13 }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={handleSaveEdit}
                  style={[styles.editBtn, { backgroundColor: themeColors.accentPrimary, borderRadius: borderRadius.sm }]}
                >
                  <Text style={{ color: themeColors.textPrimary, fontSize: 13, fontFamily: 'gg-sans-semibold' }}>Save</Text>
                </Pressable>
              </View>
            </View>
          </View>
        ) : (
          <>
            <MarkdownText content={message.content} color={themeColors.textPrimary} fontSize={fontSize} />
            <AttachmentList attachments={message.attachments || []} onLongPress={handleLongPress} />
          </>
        )}

        {/* Interactive message components (buttons, selects) */}
        {message.components && message.components.length > 0 && (
          <MessageComponents
            components={message.components}
            guildId={message.server_id ?? ''}
            channelId={''}
            messageId={message.id}
          />
        )}
        {(message.flags ?? 0) & 64 ? <EphemeralBanner themeColors={themeColors} /> : null}

        {/* Thread indicator */}
        {message.thread && (
          <Pressable
            onPress={() => onOpenThread?.(message.thread!.id)}
            style={[styles.threadBar, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Ionicons name="chatbubbles-outline" size={14} color={themeColors.accentPrimary} />
            <Text style={[styles.threadText, { color: themeColors.accentPrimary }]}>
              {message.thread.name}
            </Text>
            <Text style={[styles.threadCount, { color: themeColors.textMuted }]}>
              {message.thread.message_count} {message.thread.message_count === 1 ? 'message' : 'messages'}
            </Text>
            <Ionicons name="chevron-forward" size={14} color={themeColors.textMuted} />
          </Pressable>
        )}

        {/* Reactions */}
        {message.reactions && message.reactions.length > 0 && (
          <View style={styles.reactionsRow}>
            {message.reactions.map((r) => (
              <Pressable
                key={r.emoji}
                onPress={() => onReaction?.(message.id, r.emoji)}
                onLongPress={() => onReactionDetail?.(message.id, r.emoji)}
                style={[
                  styles.reactionChip,
                  {
                    backgroundColor: r.me
                      ? themeColors.accentPrimary + '30'
                      : themeColors.bgTertiary,
                    borderColor: r.me
                      ? themeColors.accentPrimary
                      : 'transparent',
                  },
                ]}
                accessibilityLabel={`${r.emoji} reaction, ${r.count} ${r.count === 1 ? 'person' : 'people'}`}
              >
                <Text style={styles.reactionEmoji}>{r.emoji}</Text>
                <Text
                  style={[
                    styles.reactionCount,
                    { color: r.me ? themeColors.accentPrimary : themeColors.textSecondary },
                  ]}
                >
                  {r.count}
                </Text>
              </Pressable>
            ))}

            {/* Add reaction button */}
            <Pressable
              onPress={() => onAddReaction?.(message.id)}
              style={[styles.addReactionBtn, { backgroundColor: themeColors.bgTertiary, borderColor: themeColors.border }]}
              accessibilityLabel="Add reaction"
            >
              <Ionicons name="happy-outline" size={14} color={themeColors.textMuted} />
            </Pressable>
          </View>
        )}
      </View>
    </AnimatedPressable>
  );
});

// ─── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  // Compact mode (Feature 34)
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingHorizontal: SCREEN_PADDING,
    paddingVertical: 2,
    gap: 6,
  },
  compactTimestamp: {
    fontSize: 11,
    fontFamily: 'gg-sans',
    minWidth: 44,
    paddingTop: 2,
  },
  compactAuthor: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    paddingTop: 1,
  },
  compactContent: {
    flex: 1,
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
  },
  // First message in group — full header
  container: {
    flexDirection: 'row',
    paddingLeft: SCREEN_PADDING,
    paddingRight: SCREEN_PADDING,
    paddingTop: 16,
    paddingBottom: 0,
  },
  avatarWrap: {
    width: AVATAR_SIZE,
    alignSelf: 'flex-start',
  },
  body: {
    flex: 1,
    marginLeft: AVATAR_TEXT_GAP,
  },
  // Continuation message — tight padding, no avatar column
  continuationContainer: {
    paddingLeft: CONTENT_LEFT,
    paddingRight: SCREEN_PADDING,
    paddingTop: 2,
    paddingBottom: 0,
  },
  continuationBody: {
    flex: 1,
  },
  continuationTooltip: {
    position: 'absolute',
    left: -CONTENT_LEFT + 4,
    top: 0,
    paddingHorizontal: 6,
    paddingVertical: 3,
    borderRadius: 4,
    zIndex: 10,
  },
  continuationTooltipText: {
    fontSize: 12,
    fontFamily: 'gg-sans-medium',
  },
  // Reply preview
  replyPreview: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingLeft: spacing.sm,
    borderLeftWidth: 2,
    marginBottom: 6,
    paddingVertical: 3,
    opacity: 0.85,
  },
  replyAuthor: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
  },
  replyText: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    flex: 1,
  },
  // Header
  headerRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 8, // 8px between username and timestamp
  },
  author: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
    lineHeight: 20,
  },
  timestamp: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
  },
  edited: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
    fontStyle: 'italic',
  },
  // Content
  content: {
    fontSize: 15,
    fontFamily: 'gg-sans',
    lineHeight: 20,
    marginTop: 2,
  },
  // Inline edit
  editContainer: {
    marginTop: 4,
  },
  editInput: {
    fontSize: 15,
    fontFamily: 'gg-sans',
    lineHeight: 20,
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
    maxHeight: 120,
    minHeight: 40,
  },
  editActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 4,
  },
  editHint: {
    ...typography.micro,
    flex: 1,
  },
  editButtons: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  editBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: 4,
  },
  // Thread indicator
  threadBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
    borderRadius: 8,
    marginTop: 8,
    borderLeftWidth: 2,
  },
  threadText: {
    fontSize: 13,
    fontFamily: 'gg-sans-semibold',
  },
  threadCount: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    flex: 1,
  },
  // Reactions
  reactionsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
    marginTop: 6,
  },
  reactionChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 100,        // fully rounded pill
    borderWidth: 1.5,
    gap: 4,
    minHeight: 28,
  },
  reactionEmoji: {
    fontSize: 15,
    lineHeight: 18,
  },
  reactionCount: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    lineHeight: 16,
    letterSpacing: 0.2,
  },
  addReactionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    width: 32,
    height: 28,
    borderRadius: 100,
    borderWidth: 1.5,
    borderStyle: 'dashed',
  },
  // System messages
  systemMessage: {
    paddingVertical: spacing.sm,
    paddingHorizontal: SCREEN_PADDING,
  },
  systemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  systemBodyText: {
    fontSize: 15,
    fontFamily: 'gg-sans',
    flex: 1,
  },
  systemUsername: {
    fontFamily: 'gg-sans-semibold',
  },
  systemTimestamp: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
  },
  // Feature 2: Forwarded message label
  forwardedLabel: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  forwardedText: {
    fontSize: 11,
    fontFamily: 'gg-sans-medium',
    fontStyle: 'italic',
  },
  // Feature 3: Silent message icon
  silentIcon: {
    fontSize: 11,
    marginLeft: 2,
  },
  // Feature 27: Role icon
  roleIcon: {
    width: 16,
    height: 16,
    borderRadius: 8,
    marginLeft: 2,
  },
});
