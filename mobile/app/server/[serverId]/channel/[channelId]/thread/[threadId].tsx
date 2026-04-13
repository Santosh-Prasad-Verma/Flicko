/**
 * Thread Message View Screen
 *
 * Displays a thread's messages with its own input.
 * Route: /server/[serverId]/channel/[channelId]/thread/[threadId]
 */
import React, { useCallback, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../../../services/supabase';
import { MessageList } from '../../../../../../components/messages/MessageList';
import { MessageInput } from '../../../../../../components/messages/MessageInput';
import { EmojiPicker } from '../../../../../../components/messages/EmojiPicker';
import { ReactionDetailModal } from '../../../../../../components/messages/ReactionDetailModal';
import { MessageActions } from '../../../../../../components/messages/MessageActions';
import type { MessageData } from '../../../../../../components/messages/MessageItem';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../../../constants/Colors';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { useTheme } from '../../../../../../hooks/useTheme';
import {
  useThread,
  useThreadMessages,
  useSendThreadMessage,
} from '@hooks/useThreads';

export default function ThreadScreen() {
  const { serverId, channelId, threadId } = useLocalSearchParams<{
    serverId: string;
    channelId: string;
    threadId: string;
  }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: AuthStore) => s.user);

  const [emojiVisible, setEmojiVisible] = useState(false);
  const [emojiTargetMessageId, setEmojiTargetMessageId] = useState<string | null>(null);
  const [reactionDetailVisible, setReactionDetailVisible] = useState(false);
  const [reactionDetailMessageId, setReactionDetailMessageId] = useState<string | null>(null);
  const [reactionDetailEmoji, setReactionDetailEmoji] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<MessageData | null>(null);

  // Thread info
  const { data: thread } = useThread(threadId ?? '');

  // Thread messages
  const {
    data: messagesData,
    isLoading,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    refetch,
  } = useThreadMessages(threadId ?? '');

  const messages: MessageData[] = useMemo(() => {
    if (!messagesData?.pages) return [];
    return messagesData.pages.flat() as MessageData[];
  }, [messagesData]);

  // Send message in thread
  const sendThreadMessage = useSendThreadMessage();

  // Edit message
  const editMutation = useMutation({
    mutationFn: async ({ messageId, content }: { messageId: string; content: string }) => {
      const { error } = await supabase
        .from('messages')
        .update({ content, edited: true, updated_at: new Date().toISOString() })
        .eq('id', messageId)
        .eq('author_id', user?.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thread-messages', threadId] });
    },
    onError: (err) => {
      Alert.alert('Edit Failed', err.message);
    },
  });

  // Delete message
  const deleteMutation = useMutation({
    mutationFn: async (messageId: string) => {
      const { error } = await supabase.from('messages').delete().eq('id', messageId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thread-messages', threadId] });
    },
  });

  // Reaction toggle
  const reactionMutation = useMutation({
    mutationFn: async ({ messageId, emoji }: { messageId: string; emoji: string }) => {
      const { data: existing } = await supabase
        .from('reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', user?.id)
        .eq('emoji', emoji)
        .maybeSingle();

      if (existing) {
        const { error } = await supabase.from('reactions').delete().eq('id', existing.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('reactions')
          .insert({ message_id: messageId, user_id: user?.id, emoji });
        if (error && !error.message.includes('duplicate key')) throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thread-messages', threadId] });
    },
  });

  const handleEditSubmit = useCallback(
    (messageId: string, content: string) => editMutation.mutate({ messageId, content }),
    [editMutation],
  );

  const handleReaction = useCallback(
    (messageId: string, emoji: string) => reactionMutation.mutate({ messageId, emoji }),
    [reactionMutation],
  );

  const handleAddReaction = useCallback((messageId: string) => {
    setEmojiTargetMessageId(messageId);
    setEmojiVisible(true);
  }, []);

  const handleEmojiSelect = useCallback(
    (emoji: string) => {
      if (emojiTargetMessageId) {
        reactionMutation.mutate({ messageId: emojiTargetMessageId, emoji });
        setEmojiTargetMessageId(null);
      }
      setEmojiVisible(false);
    },
    [emojiTargetMessageId, reactionMutation],
  );

  const handleReactionDetail = useCallback((messageId: string, emoji: string) => {
    setReactionDetailMessageId(messageId);
    setReactionDetailEmoji(emoji);
    setReactionDetailVisible(true);
  }, []);

  const handleMessageLongPress = useCallback((msg: MessageData) => {
    setActionMessage(msg);
  }, []);

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            {
              paddingTop: insets.top + spacing.sm,
              backgroundColor: themeColors.bgSecondary,
              borderBottomColor: themeColors.border,
            },
          ]}
        >
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={styles.backButton}
            accessibilityRole="button"
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <Text style={[styles.headerLabel, { color: themeColors.textMuted }]}>Thread</Text>
            <Text style={[styles.threadName, { color: themeColors.textPrimary }]} numberOfLines={1}>
              {thread?.name || 'Thread'}
            </Text>
          </View>
          <View style={styles.messageCount}>
            <Ionicons name="chatbubble" size={14} color={themeColors.textMuted} />
            <Text style={[styles.countText, { color: themeColors.textMuted }]}>
              {thread?.message_count ?? 0}
            </Text>
          </View>
        </View>

        {/* Messages */}
        <KeyboardAvoidingView
          style={styles.flex}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          keyboardVerticalOffset={0}
        >
          <MessageList
            messages={messages}
            currentUserId={user?.id}
            isLoading={isLoading}
            isFetchingMore={isFetchingNextPage}
            hasMore={!!hasNextPage}
            onLoadMore={() => fetchNextPage()}
            onRefresh={() => refetch()}
            onReply={() => {}} // No nested replies in threads
            onDelete={(id) => deleteMutation.mutate(id)}
            onReaction={handleReaction}
            onAddReaction={handleAddReaction}
            onReactionDetail={handleReactionDetail}
            onEditSubmit={handleEditSubmit}
            onJumpToMessage={() => {}}
            onMessageLongPress={handleMessageLongPress}
          />
          <MessageInput
            onSend={(content, attachmentUrls, options) =>
              sendThreadMessage.mutate({
                threadId: threadId!,
                channelId: channelId!,
                content,
                options,
              })
            }
            placeholder="Reply in thread..."
            disabled={sendThreadMessage.isPending}
            onEmojiPress={() => {
              setEmojiTargetMessageId(null);
              setEmojiVisible(true);
            }}
          />
          <View style={{ height: insets.bottom }} />
        </KeyboardAvoidingView>

        {/* Emoji picker */}
        <EmojiPicker
          visible={emojiVisible}
          onSelect={handleEmojiSelect}
          onClose={() => {
            setEmojiVisible(false);
            setEmojiTargetMessageId(null);
          }}
        />

        {/* Discord-style message action sheet */}
        <MessageActions
          visible={!!actionMessage}
          messageId={actionMessage?.id ?? ''}
          messageContent={actionMessage?.content ?? ''}
          messageCreatedAt={actionMessage?.created_at ?? ''}
          authorName={actionMessage?.author?.display_name || actionMessage?.author?.username || 'Unknown'}
          authorAvatar={actionMessage?.author?.avatar_url}
          authorColor={actionMessage?.author?.role_color}
          isOwnMessage={actionMessage?.author_id === user?.id}
          isPinned={false}
          canManageMessages={false}
          onReply={() => {}}
          onDelete={() => {
            if (actionMessage) deleteMutation.mutate(actionMessage.id);
          }}
          onReact={(emoji) => {
            if (actionMessage && emoji) {
              reactionMutation.mutate({ messageId: actionMessage.id, emoji });
            }
          }}
          onAddReaction={() => {
            if (actionMessage) handleAddReaction(actionMessage.id);
          }}
          onClose={() => setActionMessage(null)}
        />

        {/* Reaction detail */}
        <ReactionDetailModal
          visible={reactionDetailVisible}
          messageId={reactionDetailMessageId}
          emoji={reactionDetailEmoji}
          onClose={() => {
            setReactionDetailVisible(false);
            setReactionDetailMessageId(null);
            setReactionDetailEmoji(null);
          }}
          onUserPress={(userId) => {
            setReactionDetailVisible(false);
            router.push(`/profile/${userId}` as any);
          }}
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
  },
  backButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerInfo: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  headerLabel: {
    ...typography.caption,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  threadName: {
    ...typography.headingS,
    marginTop: 2,
  },
  messageCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: spacing.sm,
  },
  countText: {
    ...typography.caption,
  },
});
