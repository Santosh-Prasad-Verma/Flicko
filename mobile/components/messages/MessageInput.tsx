/**
 * MessageInput Component
 *
 * Auto-growing text input with send button and haptic feedback.
 * Shows character count near limit (4000 chars).
 * Supports slowmode countdown timer.
 * Enhanced with attachment, GIF, and poll buttons.
 * Requirements: 5.4, 15.1, Rich-Media Features
 */
import React, { memo, useState, useCallback, useRef } from 'react';
import {
  View,
  TextInput,
  StyleSheet,
  Pressable,
  Text,
  Platform,
  Alert,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withSequence,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';
import { useSlowmodeTimer } from '../../hooks/useSlowmodeTimer';
import { AttachmentPreview } from './AttachmentPreview';
import { useUploadStore, type UploadItem } from '@stores/uploadStore';
import { pickImage, takePhoto, uploadFilesForMessage } from '@services/fileUploadService';
import { SPRING_SNAPPY, SPRING_BOUNCY } from '../../constants/Animations';
import { useInteractionStore } from '@stores/interactionStore';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const MAX_LENGTH = 4000;
const CHAR_WARNING_THRESHOLD = 3800;

function formatCooldown(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

interface MessageInputProps {
  onSend: (content: string, attachmentUrls?: string[], options?: { isSilent?: boolean; isTts?: boolean; replyMention?: boolean }) => void;
  channelId?: string;
  replyTo?: { id: string; authorName: string; content: string } | null;
  onCancelReply?: () => void;
  placeholder?: string;
  disabled?: boolean;
  onTextChange?: (text: string) => void;
  onEmojiPress?: () => void;
  onGifPress?: () => void;
  onPollPress?: () => void;
  /** Slowmode: remaining seconds until user can send again (0 = can send) */
  slowmodeRemaining?: number;
  /** Slowmode: total cooldown seconds (for display) */
  slowmodeSeconds?: number;
}

export const MessageInput = memo(function MessageInput({
  onSend,
  channelId,
  replyTo,
  onCancelReply,
  placeholder = 'Type a message...',
  disabled = false,
  onTextChange,
  onEmojiPress,
  onGifPress,
  onPollPress,
  slowmodeRemaining: propRemaining = 0,
  slowmodeSeconds = 0,
}: MessageInputProps) {
  const { themeColors } = useTheme();
  const { remainingSeconds, checkSlowmode } = useSlowmodeTimer(channelId || null);
  const slowmodeRemaining = Math.max(propRemaining, remainingSeconds);
  const [text, setText] = useState('');
  const [replyMention, setReplyMention] = useState(true); // Feature 7: Reply Ping Toggle (ON by default)
  const inputRef = useRef<TextInput>(null);
  const uploadStore = useUploadStore();

  // Send button animation
  const sendScale = useSharedValue(1);
  const sendAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: sendScale.value }],
  }));

  const inSlowmode = slowmodeRemaining > 0;
  const overLimit = text.length > MAX_LENGTH;
  const showCharCount = text.length >= CHAR_WARNING_THRESHOLD;
  const pendingUploads = channelId ? uploadStore.getPendingAttachments(channelId) : [];
  const hasPending = pendingUploads.length > 0;
  const openPalette = useInteractionStore((s) => s.openPalette);

  const handleAttach = useCallback(async () => {
    if (!channelId) return;
    try {
      const files = await pickImage({ allowsMultipleSelection: true });
      if (!files.length) return;
      await uploadFilesForMessage(files, channelId);
    } catch (err: any) {
      Alert.alert('Upload Error', err.message ?? 'Failed to pick files');
    }
  }, [channelId]);

  const handleCamera = useCallback(async () => {
    if (!channelId) return;
    try {
      const photo = await takePhoto();
      if (!photo) return;
      await uploadFilesForMessage([photo], channelId);
    } catch (err: any) {
      Alert.alert('Camera Error', err.message ?? 'Failed to take photo');
    }
  }, [channelId]);

  const handleSend = useCallback(() => {
    let trimmed = text.trim();
    if ((!trimmed && !hasPending) || disabled || inSlowmode) return;

    // Feature 3: Detect @silent prefix
    const isSilent = trimmed.startsWith('@silent ') || trimmed === '@silent';
    if (isSilent) trimmed = trimmed.replace(/^@silent\s*/, '');

    // Feature 4: Detect /tts prefix
    const isTts = trimmed.startsWith('/tts ') || trimmed === '/tts';
    if (isTts) trimmed = trimmed.replace(/^\/tts\s*/, '');

    if (!trimmed && !hasPending) return;

    // Bounce animation on send
    sendScale.value = withSequence(
      withSpring(0.85, SPRING_SNAPPY),
      withSpring(1.1, SPRING_BOUNCY),
      withSpring(1, SPRING_SNAPPY),
    );

    // Collect completed upload URLs
    const urls = pendingUploads
      .filter((u) => u.status === 'completed' && u.remoteUrl)
      .map((u) => u.remoteUrl!);

    onSend(trimmed, urls.length > 0 ? urls : undefined, {
      isSilent,
      isTts,
      replyMention: replyTo ? replyMention : undefined,
    });
    setText('');
    setReplyMention(true); // Reset reply ping toggle
    if (channelId) uploadStore.clearChannelUploads(channelId);
      
      // Feature: trigger DB check for slowmode directly after send
      if (typeof checkSlowmode === 'function') {
        setTimeout(() => checkSlowmode(), 500); // short delay to let DB see the insert
      }
  }, [text, disabled, inSlowmode, onSend, hasPending, pendingUploads, channelId, uploadStore, replyMention, replyTo, checkSlowmode]);

  return (
    <View style={[styles.wrapper, { backgroundColor: themeColors.bgPrimary, borderTopColor: 'transparent' }]}> 
      {/* Reply indicator with ping toggle (Feature 7) */}
      {replyTo && (
        <View style={[styles.replyBar, { backgroundColor: themeColors.bgTertiary }]}>
          <View style={styles.replyContent}>
            <Text style={[styles.replyLabel, { color: themeColors.accentPrimary }]}>
              Replying to {replyTo.authorName}
            </Text>
            <Text style={[styles.replyPreview, { color: themeColors.textMuted }]} numberOfLines={1}>
              {replyTo.content}
            </Text>
          </View>
          {/* Reply Ping Toggle (Feature 7) */}
          <Pressable
            onPress={() => setReplyMention((v) => !v)}
            hitSlop={12}
            style={[styles.pingToggle, { backgroundColor: replyMention ? themeColors.accentPrimary + '30' : themeColors.bgSecondary }]}
            accessibilityLabel={replyMention ? 'Ping enabled, tap to disable' : 'Ping disabled, tap to enable'}
          >
            <Ionicons
              name={replyMention ? 'notifications' : 'notifications-off'}
              size={14}
              color={replyMention ? themeColors.accentPrimary : themeColors.textMuted}
            />
            <Text style={[styles.pingToggleText, { color: replyMention ? themeColors.accentPrimary : themeColors.textMuted }]}>
              {replyMention ? 'ON' : 'OFF'}
            </Text>
          </Pressable>
          <Pressable onPress={onCancelReply} hitSlop={12} accessibilityLabel="Cancel reply">
            <Ionicons name="close" size={18} color={themeColors.textMuted} />
          </Pressable>
        </View>
      )}

      {/* Attachment previews */}
      {hasPending && channelId && (
        <AttachmentPreview channelId={channelId} />
      )}

      {/* Combined input row with all action icons inside */}
      <View style={[styles.inputRow, { backgroundColor: themeColors.inputBg }]}> 
        {/* Left action icons */}
        <Pressable onPress={handleAttach} hitSlop={8} style={styles.inlineAction}>
          <Ionicons name="add" size={24} color={themeColors.textSecondary} style={styles.addCircle} />
        </Pressable>

        <TextInput
          ref={inputRef}
          value={text}
          onChangeText={(v) => {
            setText(v);
            onTextChange?.(v);
            if (v.trim() === '/') {
               openPalette?.();
            }
          }}
          placeholder={placeholder}
          placeholderTextColor={themeColors.textMuted}
          multiline
          maxLength={MAX_LENGTH}
          style={[
            styles.input,
            {
              color: themeColors.textPrimary,
            },
          ]}
          selectionColor={themeColors.accentPrimary}
          cursorColor={themeColors.accentPrimary}
          editable={!disabled}
          returnKeyType="default"
          blurOnSubmit={false}
          accessibilityLabel="Message input"
        />

        {/* Right side icons — camera, emoji always visible; send replaces them when text present */}
        {(text.trim() || hasPending) ? (
          <AnimatedPressable
            onPress={handleSend}
            disabled={(!text.trim() && !hasPending) || overLimit || disabled || inSlowmode}
            style={[
              styles.sendButton,
              sendAnimStyle,
            ]}
            accessibilityRole="button"
            accessibilityLabel={inSlowmode ? `Slowmode: wait ${slowmodeRemaining} seconds` : 'Send message'}
          >
            {inSlowmode ? (
              <Text style={[styles.slowmodeCountdown, { color: themeColors.warning }]}>
                {formatCooldown(slowmodeRemaining)}
              </Text>
            ) : (
              <Ionicons name="send" size={16} color={themeColors.accentPrimary} />
            )}
          </AnimatedPressable>
        ) : (
          <>
              {onGifPress && (
                <Pressable onPress={onGifPress} hitSlop={8} style={styles.inlineAction}>
                  <Ionicons name="image-outline" size={22} color={themeColors.textSecondary} />
                </Pressable>
              )}
            {onEmojiPress && (
              <Pressable onPress={onEmojiPress} hitSlop={8} style={styles.inlineAction}>
                <Ionicons name="happy-outline" size={22} color={themeColors.textSecondary} />
              </Pressable>
            )}
          </>
        )}
      </View>

      {/* Char count + slowmode below the input */}
      {(showCharCount || (slowmodeSeconds > 0 && !inSlowmode)) && (
        <View style={styles.statusBar}>
          {showCharCount && (
            <Text
              style={[
                styles.charCount,
                { color: overLimit ? themeColors.danger : themeColors.textMuted },
              ]}
            >
              {text.length}/{MAX_LENGTH}
            </Text>
          )}
          {slowmodeSeconds > 0 && !inSlowmode && (
            <View style={styles.slowmodeIndicator}>
              <Ionicons name="time-outline" size={12} color={themeColors.textMuted} />
              <Text style={[styles.slowmodeText, { color: themeColors.textMuted }]}>
                Slowmode: {formatCooldown(slowmodeSeconds)}
              </Text>
            </View>
          )}
        </View>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  wrapper: {
    borderTopWidth: 0,
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    paddingBottom: spacing.sm,
  },
  replyBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 8,
    marginBottom: spacing.sm,
  },
  replyContent: {
    flex: 1,
  },
  replyLabel: {
    ...typography.caption,
    fontFamily: 'gg-sans-bold',
  },
  replyPreview: {
    ...typography.caption,
    marginTop: 2,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    borderRadius: 20,
    paddingHorizontal: 10,
    paddingVertical: 6,
    minHeight: 44,
  },
  input: {
    flex: 1,
    maxHeight: 120,
    minHeight: 36,
    paddingHorizontal: 8,
    paddingVertical: 6,
    fontSize: 15,
    lineHeight: 20,
  },
  inlineAction: {
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 2,
  },
  addCircle: {
    backgroundColor: '#3b3d40',
    borderRadius: 13,
    overflow: 'hidden',
    width: 26,
    height: 26,
    textAlign: 'center',
    lineHeight: 26,
  },
  sendButton: {
    width: 32,
    height: 32,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 4,
  },
  charCount: {
    ...typography.caption,
    textAlign: 'right',
  },
  statusBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    marginTop: 4,
    paddingHorizontal: 4,
    gap: spacing.md,
  },
  slowmodeCountdown: {
    ...typography.micro,
    fontFamily: 'gg-sans-bold',
  },
  slowmodeIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  slowmodeText: {
    ...typography.micro,
  },
  // Feature 7: Reply Ping Toggle
  pingToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    marginRight: 4,
  },
  pingToggleText: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
  },
});
