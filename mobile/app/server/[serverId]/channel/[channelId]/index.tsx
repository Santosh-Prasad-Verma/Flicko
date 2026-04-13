/**
 * Channel Message View Screen
 *
 * Full chat screen for a channel with real-time messages.
 * Now includes: editing, reactions, reply previews, threads, voice controls.
 *
 * Route: /server/[serverId]/channel/[channelId]
 * Requirements: 4.4, 5.1, 5.2, 5.3, 5.4, 5.10
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../../services/supabase';
import { MessageList, type MessageListHandle } from '../../../../../components/messages/MessageList';
import { MessageInput } from '../../../../../components/messages/MessageInput';
import { TypingIndicator } from '../../../../../components/messages/TypingIndicator';
import { EmojiPicker } from '../../../../../components/messages/EmojiPicker';
import { ReactionDetailModal } from '../../../../../components/messages/ReactionDetailModal';
import { CreateThreadModal } from '../../../../../components/messages/CreateThreadModal';
import { GifPicker } from '../../../../../components/messages/GifPicker';
import { MessageActions } from '../../../../../components/messages/MessageActions';
import { VoiceControls } from '../../../../../components/voice/VoiceControls';
import { usePublishMessage } from '@hooks/useForum';
import type { MessageData } from '../../../../../components/messages/MessageItem';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../../constants/Colors';
import { useAuthStore } from '@stores/authStore';
import { useVoiceStore } from '@stores/voiceStore';
import { useUploadStore, type UploadItem } from '@stores/uploadStore';
import { useTyping } from '../../../../../hooks/useTyping';
import { useTheme } from '../../../../../hooks/useTheme';

const PAGE_SIZE = 50;

export default function ChannelScreen() {
  const { serverId, channelId } = useLocalSearchParams<{
    serverId: string;
    channelId: string;
  }>();
  const insets = useSafeAreaInsets();
  const { theme, themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);
  const voiceChannelId = useVoiceStore((s) => s.channelId);
  const messageListRef = useRef<MessageListHandle>(null);

  // UI state
  const [replyTo, setReplyTo] = useState<{
    id: string;
    authorName: string;
    content: string;
  } | null>(null);
  const [emojiVisible, setEmojiVisible] = useState(false);
  const [emojiTargetMessageId, setEmojiTargetMessageId] = useState<string | null>(null);
  const [reactionDetailVisible, setReactionDetailVisible] = useState(false);
  const [reactionDetailMessageId, setReactionDetailMessageId] = useState<string | null>(null);
  const [reactionDetailEmoji, setReactionDetailEmoji] = useState<string | null>(null);
  const [createThreadVisible, setCreateThreadVisible] = useState(false);
  const [threadParentMessage, setThreadParentMessage] = useState<MessageData | null>(null);
  const [actionMessage, setActionMessage] = useState<MessageData | null>(null);

  // Fetch channel info
  const { data: channel } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('channels')
        .select('*')
        .eq('id', channelId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!channelId,
  });

  // Fetch messages with infinite scroll + reply_to data
  const {
    data: messagesData,
    isLoading,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    refetch,
  } = useInfiniteQuery({
    queryKey: ['messages', channelId],
    queryFn: async ({ pageParam }: { pageParam: string | undefined }) => {
      let query = supabase
        .from('messages')
        .select(`
          *,
          author:profiles!author_id(id, username, display_name, avatar_url:avatar),
          reactions(emoji, user_id),
          attachments(url, mime_type, filename, size, width, height)
        `)
        .eq('channel_id', channelId!)
        .is('thread_id', null)
        .order('created_at', { ascending: false })
        .limit(PAGE_SIZE);

      if (pageParam) {
        query = query.lt('created_at', pageParam);
      }

      const { data, error } = await query;
      if (error) throw error;

      // Process reactions: aggregate by emoji
      const processed = (data ?? []).map((msg: any) => {
        const reactionMap = new Map<string, { count: number; me: boolean; users: string[] }>();
        for (const r of msg.reactions ?? []) {
          const existing = reactionMap.get(r.emoji);
          if (existing) {
            existing.count++;
            existing.users.push(r.user_id);
            if (r.user_id === user?.id) existing.me = true;
          } else {
            reactionMap.set(r.emoji, {
              count: 1,
              me: r.user_id === user?.id,
              users: [r.user_id],
            });
          }
        }
        return {
          ...msg,
          reactions: Array.from(reactionMap.entries()).map(([emoji, data]) => ({
            emoji,
            count: data.count,
            me: data.me,
            users: data.users,
          })),
        };
      });

      return processed;
    },
    enabled: !!channelId,
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => {
      if (lastPage.length < PAGE_SIZE) return undefined;
      return lastPage[lastPage.length - 1]?.created_at;
    },
  });

  // Fetch reply-to references for messages that have reply_to_id
  const messages: MessageData[] = useMemo(() => {
    if (!messagesData?.pages) return [];
    const allMessages = messagesData.pages.flat();

    // Build a map of message ID → message for quick lookups
    const messageMap = new Map(allMessages.map((m) => [m.id, m]));

    // Attach reply_to references
    return allMessages.map((msg) => {
      if (msg.reply_to_id) {
        const parentMsg = messageMap.get(msg.reply_to_id);
        if (parentMsg) {
          return {
            ...msg,
            reply_to: {
              id: parentMsg.id,
              content: parentMsg.content,
              author: parentMsg.author,
            },
          };
        }
      }
      return msg;
    });
  }, [messagesData]);

  // Real-time subscription for INSERT/UPDATE/DELETE
  useEffect(() => {
    if (!channelId) return;

    const subscription = supabase
      .channel(`messages:${channelId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
        },
      )
      // Also listen for reaction changes
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'reactions',
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  }, [channelId, queryClient]);

  // --- Mutations ---

  // Send message
  const sendMutation = useMutation({
    mutationFn: async ({ content, options }: { content: string, options?: { isSilent?: boolean; isTts?: boolean; replyMention?: boolean } }) => {
      // Read pending attachments BEFORE any async operation to avoid
      // race condition with MessageInput clearing the store after onSend
      const uploadStore = useUploadStore.getState();
      const completedUploads = uploadStore.getPendingAttachments(channelId!)
        .filter((u: UploadItem) => u.status === 'completed' && u.remoteUrl);

      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;
      if (!token) throw new Error('Not authenticated');

      const API_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8080';
      const payload = {
        content,
        type: replyTo ? 'reply' : 'default',
        reply_to_id: replyTo?.id ?? null,
        is_silent: options?.isSilent || false,
      };

      const res = await fetch(`${API_URL}/api/v1/channels/${channelId}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(errText || 'Failed to send message');
      }

      const { id: messageId } = await res.json();

      // Save attachments to database
      if (completedUploads.length > 0) {
        const attachments = completedUploads.map((u: UploadItem) => ({
          message_id: messageId,
          url: u.remoteUrl!,
          mime_type: u.contentType,
          filename: u.filename,
          size: u.size,
          width: u.width,
          height: u.height,
          alt_text: u.altText || null,
        }));

        await supabase.from('attachments').insert(attachments);
      }
    },
    onSuccess: () => {
      setReplyTo(null);
      if (channelId) useUploadStore.getState().clearChannelUploads(channelId);
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
      // Auto-scroll to bottom after sending (like Discord)
      setTimeout(() => messageListRef.current?.scrollToBottom(), 100);
    },
    onError: (err: any) => {
      Alert.alert('Send Failed', err.message ?? 'Could not send message. Please try again.');
    },
  });

  // Edit message
  const editMutation = useMutation({
    mutationFn: async ({ messageId, content }: { messageId: string; content: string }) => {
      // Only update content — the DB trigger handles setting edited=true, edited_at, updated_at
      const { error } = await supabase
        .from('messages')
        .update({ content })
        .eq('id', messageId)
        .eq('author_id', user?.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
    onError: (err) => {
      Alert.alert('Edit Failed', err.message);
    },
  });

  // Delete message
  const deleteMutation = useMutation({
    mutationFn: async (messageId: string) => {
      const { error } = await supabase
        .from('messages')
        .delete()
        .eq('id', messageId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  // Add/toggle reaction
  const reactionMutation = useMutation({
    mutationFn: async ({ messageId, emoji }: { messageId: string; emoji: string }) => {
      // Check if user already reacted with this emoji
      const { data: existing } = await supabase
        .from('reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', user?.id)
        .eq('emoji', emoji)
        .maybeSingle();

      if (existing) {
        // Remove reaction
        const { error } = await supabase
          .from('reactions')
          .delete()
          .eq('id', existing.id);
        if (error) throw error;
      } else {
        // Add reaction
        const { error } = await supabase
          .from('reactions')
          .insert({ message_id: messageId, user_id: user?.id, emoji });
        if (error && !error.message.includes('duplicate key')) throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  // Create thread
  const createThreadMutation = useMutation({
    mutationFn: async ({ name, autoArchiveDuration }: { name: string; autoArchiveDuration: number }) => {
      if (!threadParentMessage || !serverId || !channelId) throw new Error('Missing context');

      const archiveAt = new Date(
        Date.now() + autoArchiveDuration * 60 * 1000
      ).toISOString();

      const { data: thread, error } = await supabase
        .from('threads')
        .insert({
          server_id: serverId,
          parent_channel_id: channelId,
          parent_message_id: threadParentMessage.id,
          name,
          creator_id: user?.id,
          type: 'public',
          auto_archive_duration: `${autoArchiveDuration} minutes`,
          archive_at: archiveAt,
        })
        .select('*')
        .single();

      if (error) throw error;

      // Auto-join creator
      await supabase.from('thread_members').insert({
        thread_id: thread.id,
        user_id: user?.id,
      });

      return thread;
    },
    onSuccess: (thread) => {
      setCreateThreadVisible(false);
      setThreadParentMessage(null);
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
      // Navigate to thread
      router.push(`/server/${serverId}/channel/${channelId}/thread/${thread.id}` as any);
    },
    onError: (err) => {
      Alert.alert('Failed to create thread', err.message);
    },
  });

  // --- Handlers ---

  // Announcement publish
  const publishMessage = usePublishMessage();
  const isAnnouncement = channel?.type === 'announcement';

  const handlePublish = useCallback(
    (messageId: string) => {
      Alert.alert(
        'Publish Message',
        'This will cross-post this message to all servers following this channel.',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Publish',
            onPress: () => {
              publishMessage.mutate(messageId, {
                onSuccess: () => Alert.alert('Published', 'Message published to followers.'),
                onError: (err) => Alert.alert('Failed', err.message),
              });
            },
          },
        ],
      );
    },
    [publishMessage],
  );

  const handleReply = useCallback((msg: MessageData) => {
    setReplyTo({
      id: msg.id,
      authorName: msg.author?.display_name || msg.author?.username || 'Unknown',
      content: msg.content,
    });
  }, []);

  const handleEditSubmit = useCallback(
    (messageId: string, content: string) => {
      editMutation.mutate({ messageId, content });
    },
    [editMutation]
  );

  const handleReaction = useCallback(
    (messageId: string, emoji: string) => {
      reactionMutation.mutate({ messageId, emoji });
    },
    [reactionMutation]
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
    [emojiTargetMessageId, reactionMutation]
  );

  const handleReactionDetail = useCallback((messageId: string, emoji: string) => {
    setReactionDetailMessageId(messageId);
    setReactionDetailEmoji(emoji);
    setReactionDetailVisible(true);
  }, []);

  const handleCreateThread = useCallback((msg: MessageData) => {
    setThreadParentMessage(msg);
    setCreateThreadVisible(true);
  }, []);

  const handleMessageLongPress = useCallback((msg: MessageData) => {
    setActionMessage(msg);
  }, []);

  const handleOpenThread = useCallback(
    (threadId: string) => {
      router.push(`/server/${serverId}/channel/${channelId}/thread/${threadId}` as any);
    },
    [serverId, channelId]
  );

  const handleJumpToMessage = useCallback(
    (messageId: string) => {
      // In a real implementation, this would scroll the FlatList to the message
      // For now, we just ensure the message is visible by refetching if needed
      console.log('[ChannelScreen] Jump to message:', messageId);
    },
    []
  );

  // Typing indicator
  const { typingUsers, startTyping } = useTyping(
    channelId ?? null,
    user?.id ?? null,
    user?.username ?? null,
  );
  const typingUsernames = typingUsers.map((u) => u.username);

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
              backgroundColor: theme === 'dark' ? '#36393F' : themeColors.bgSecondary,
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
            <View style={styles.channelNameRow}>
              <Ionicons
                name={
                  channel?.type === 'voice' ? 'volume-high' :
                  channel?.type === 'announcement' ? 'megaphone-outline' :
                  'chatbubble-outline'
                }
                size={16}
                color={themeColors.textMuted}
              />
              <Text style={[styles.channelName, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {channel?.name || 'Channel'}
              </Text>
            </View>
            {channel?.topic ? (
              <Text style={[styles.topic, { color: themeColors.textMuted }]} numberOfLines={1}>
                {channel.topic}
              </Text>
            ) : null}
          </View>
          <View style={styles.headerActionsRow}>
            <Ionicons name="notifications-outline" size={16} color={themeColors.textSecondary} />
            <Ionicons name="people-outline" size={16} color={themeColors.textSecondary} />
            <View
              style={[
                styles.searchPill,
                { backgroundColor: theme === 'dark' ? '#202225' : themeColors.bgTertiary },
              ]}
            >
              <Text style={[styles.searchText, { color: themeColors.textMuted }]}>Search</Text>
              <Ionicons name="search" size={12} color={themeColors.textMuted} />
            </View>
            <Ionicons name="help-circle-outline" size={16} color={themeColors.textSecondary} />
          </View>
        </View>

        {/* Messages */}
        <KeyboardAvoidingView
          style={styles.flex}
          behavior="padding"
          keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
        >
          <MessageList
            ref={messageListRef}
            messages={messages}
            currentUserId={user?.id}
            isLoading={isLoading}
            isFetchingMore={isFetchingNextPage}
            hasMore={!!hasNextPage}
            onLoadMore={() => fetchNextPage()}
            onRefresh={() => refetch()}
            onReply={handleReply}
            onDelete={(id) => deleteMutation.mutate(id)}
            onReaction={handleReaction}
            onAddReaction={handleAddReaction}
            onReactionDetail={handleReactionDetail}
            onCreateThread={handleCreateThread}
            onOpenThread={handleOpenThread}
            onJumpToMessage={handleJumpToMessage}
            onEditSubmit={handleEditSubmit}
            onMessageLongPress={handleMessageLongPress}
          />
          <TypingIndicator usernames={typingUsernames} />
          <MessageInput
            onSend={(content, attachmentUrls, options) => sendMutation.mutate({ content, options })}
            channelId={channelId}
            replyTo={replyTo}
            onCancelReply={() => setReplyTo(null)}
            placeholder={`Message #${channel?.name || 'channel'}`}
            disabled={sendMutation.isPending}
            onTextChange={() => startTyping()}
            onEmojiPress={() => {
              setEmojiTargetMessageId(null);
              setEmojiVisible(true);
            }}
          />

          {/* Voice controls bar (shown if connected to a voice channel) */}
          {voiceChannelId && <VoiceControls />}

          <View style={{ height: insets.bottom }} />
        </KeyboardAvoidingView>

        {/* Emoji picker modal */}
        <EmojiPicker
          visible={emojiVisible}
          onSelect={handleEmojiSelect}
          onGifSelect={(gif) => {
            // Send GIF directly
            sendMutation.mutate({ content: gif.url });
          }}
          serverId={serverId}
          onClose={() => {
            setEmojiVisible(false);
            setEmojiTargetMessageId(null);
          }}
        />

        {/* Reaction detail modal */}
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

        {/* Create thread modal */}
        <CreateThreadModal
          visible={createThreadVisible}
          onClose={() => {
            setCreateThreadVisible(false);
            setThreadParentMessage(null);
          }}
          onSubmit={(name, autoArchiveDuration) => {
            createThreadMutation.mutate({ name, autoArchiveDuration });
          }}
          parentMessagePreview={threadParentMessage?.content}
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
          onReply={() => {
            if (actionMessage) handleReply(actionMessage);
          }}
          onEdit={() => {
            // Trigger inline edit via the message item
          }}
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
          onThread={() => {
            if (actionMessage) handleCreateThread(actionMessage);
          }}
          onClose={() => setActionMessage(null)}
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
    paddingBottom: spacing.sm,
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
  channelNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  channelName: {
    ...typography.headingS,
  },
  topic: {
    ...typography.caption,
    marginTop: 2,
  },
  headerActionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  searchPill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minWidth: 86,
    height: 22,
    borderRadius: 4,
    paddingHorizontal: 6,
  },
  searchText: {
    ...typography.micro,
  },
  headerAction: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
