/**
 * MessageList Component
 *
 * Inverted FlashList for chat-style display with infinite scroll.
 * Computes message grouping (same author within 7 min) and passes
 * `isContinuation` to each MessageItem for collapsed headers.
 * Passes through all message action callbacks to MessageItem.
 * Uses @shopify/flash-list for superior scroll performance.
 * Requirements: 5.7, 5.8, 18.1
 */
import React, { memo, useCallback, useImperativeHandle, useMemo, useRef, forwardRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { FlashList, FlashListRef } from '@shopify/flash-list';
import { MessageItem, isSameGroup, type MessageData } from './MessageItem';
import { EmptyState } from '../shared/EmptyState';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface MessageListProps {
  messages: MessageData[];
  currentUserId?: string;
  isLoading?: boolean;
  isFetchingMore?: boolean;
  hasMore?: boolean;
  onLoadMore?: () => void;
  onRefresh?: () => void;
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
  /** Called on long-press to show the Discord-style action sheet */
  onMessageLongPress?: (message: MessageData) => void;
}

export interface MessageListHandle {
  scrollToBottom: (animated?: boolean) => void;
}

export const MessageList = memo(forwardRef<MessageListHandle, MessageListProps>(function MessageList({
  messages,
  currentUserId,
  isLoading,
  isFetchingMore,
  hasMore,
  onLoadMore,
  onRefresh,
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
  onMessageLongPress,
}, ref) {
  const { themeColors } = useTheme();
  const listRef = useRef<FlashListRef<MessageData>>(null);

  // Expose scrollToBottom to parent (offset 0 = bottom of inverted list)
  useImperativeHandle(ref, () => ({
    scrollToBottom: (animated = true) => {
      listRef.current?.scrollToOffset({ offset: 0, animated });
    },
  }));

    useEffect(() => {
      if (messages.length > 0) {
        listRef.current?.scrollToOffset({ offset: 0, animated: true });
      }
    }, [messages.length]);

  const dateSeparators = useMemo(() => {
    const map = new Map<string, string>();
    for (let i = 0; i < messages.length; i++) {
      const cur = messages[i];
      const next = messages[i + 1];
      const curDate = new Date(cur.created_at).toLocaleDateString(undefined, {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
        year: 'numeric',
      });
      if (!next) {
        // Oldest message — always show separator
        map.set(cur.id, curDate);
      } else {
        const nextDate = new Date(next.created_at).toDateString();
        const curDateStr = new Date(cur.created_at).toDateString();
        if (curDateStr !== nextDate) {
          map.set(cur.id, curDate);
        }
      }
    }
    return map;
  }, [messages]);

  const continuationIds = useMemo(() => {
    const set = new Set<string>();
    // messages are sorted newest to oldest because of inverted list
    for (let i = 0; i < messages.length; i++) {
      const cur = messages[i];
      // The older message is at i + 1
      const older = messages[i + 1];
      if (older && isSameGroup(older, cur)) {
        set.add(cur.id);
      }
    }
    return set;
  }, [messages]);

  const renderMessage = useCallback(
    ({ item }: { item: MessageData }) => {
      const dateLabel = dateSeparators.get(item.id);
      return (
        <>
          <MessageItem
            message={item}
            isContinuation={continuationIds.has(item.id)}
            currentUserId={currentUserId}
            onReply={onReply}
            onEdit={onEdit}
            onDelete={onDelete}
            onReaction={onReaction}
            onAddReaction={onAddReaction}
            onReactionDetail={onReactionDetail}
            onCreateThread={onCreateThread}
            onOpenThread={onOpenThread}
            onJumpToMessage={onJumpToMessage}
            onEditSubmit={onEditSubmit}
            onMention={onMention}
            onOpenProfile={onOpenProfile}
            onMessageLongPress={onMessageLongPress}
          />
          {/* Date separator (Feature 35) — rendered BELOW in inverted list = appears above visually */}
          {dateLabel && (
            <View style={styles.dateSeparator}>
              <View style={[styles.dateLine, { backgroundColor: themeColors.border }]} />
              <Text style={[styles.dateLabel, { color: themeColors.textMuted, backgroundColor: themeColors.bgPrimary }]}>
                {dateLabel}
              </Text>
              <View style={[styles.dateLine, { backgroundColor: themeColors.border }]} />
            </View>
          )}
        </>
      );
    },
    [continuationIds, dateSeparators, currentUserId, themeColors, onReply, onEdit, onDelete, onReaction, onAddReaction, onReactionDetail, onCreateThread, onOpenThread, onJumpToMessage, onEditSubmit, onMention, onOpenProfile, onMessageLongPress],
  );

  const renderFooter = useCallback(() => {
    if (!isFetchingMore) return null;
    return (
      <View style={styles.footer}>
        <ActivityIndicator size="small" color={themeColors.accentPrimary} />
        <Text style={[styles.loadingText, { color: themeColors.textMuted }]}>
          Loading older messages...
        </Text>
      </View>
    );
  }, [isFetchingMore, themeColors]);

  const handleEndReached = useCallback(() => {
    if (hasMore && !isFetchingMore) {
      onLoadMore?.();
    }
  }, [hasMore, isFetchingMore, onLoadMore]);

  if (isLoading && messages.length === 0) {
    return (
      <View style={styles.centeredContainer}>
        <ActivityIndicator size="large" color={themeColors.accentPrimary} />
      </View>
    );
  }

  if (messages.length === 0) {
    return (
      <EmptyState
        icon="chatbubble-ellipses-outline"
        title="No messages yet"
        message="Be the first to send a message!"
      />
    );
  }

  return (
    <FlashList
      ref={listRef}
      data={messages}
      renderItem={renderMessage}
      keyExtractor={(item) => item.id}
      {...{ inverted: true } as any}
      drawDistance={500}
      onEndReached={handleEndReached}
      onEndReachedThreshold={0.3}
      ListFooterComponent={renderFooter}
      refreshControl={
        onRefresh ? (
          <RefreshControl
            refreshing={false}
            onRefresh={onRefresh}
            tintColor={themeColors.accentPrimary}
            colors={[themeColors.accentPrimary]}
          />
        ) : undefined
      }
      keyboardDismissMode="interactive"
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={styles.listContent}
      showsVerticalScrollIndicator={false}
    />
  );
}));

const styles = StyleSheet.create({
  centeredContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  listContent: {
    paddingVertical: spacing.sm,
    flexGrow: 1,
  },
  footer: {
    paddingVertical: spacing.lg,
    alignItems: 'center',
    gap: spacing.xs,
  },
  loadingText: {
    ...typography.caption,
  },
  // Feature 35: Date separators
  dateSeparator: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  dateLine: {
    flex: 1,
    height: StyleSheet.hairlineWidth,
  },
  dateLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    paddingHorizontal: spacing.sm,
  },
});
