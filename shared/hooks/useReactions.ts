import { useMutation, useQueryClient } from '@tanstack/react-query';
import { addReaction, removeReaction } from '@/services/messageService';
import type { Message } from '@shared/types/models';

/**
 * Hook for managing message reactions
 * 
 * Provides optimistic updates for adding/removing reactions
 */
export function useReactions(messageId: string, channelId: string) {
  const queryClient = useQueryClient();

  const addReactionMutation = useMutation({
    mutationFn: (emoji: string) => addReaction(messageId, emoji),
    onMutate: async (emoji: string) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['messages', channelId] });

      // Snapshot previous value
      const previousMessages = queryClient.getQueryData<Message[]>(['messages', channelId]);

      // Optimistically update
      queryClient.setQueryData<Message[]>(['messages', channelId], (old) => {
        if (!old) return old;

        return old.map((msg) => {
          if (msg.id !== messageId) return msg;

          const reactions = msg.reactions || [];
          const existingReaction = reactions.find((r) => r.emoji === emoji);

          if (existingReaction) {
            // User already reacted, increment count and add to users
            return {
              ...msg,
              reactions: reactions.map((r) =>
                r.emoji === emoji
                  ? { ...r, count: r.count + 1, me: true }
                  : r
              ),
            };
          } else {
            // New reaction
            return {
              ...msg,
              reactions: [
                ...reactions,
                { emoji, count: 1, users: [], me: true },
              ],
            };
          }
        });
      });

      return { previousMessages };
    },
    onError: (_err, _emoji, context) => {
      // Rollback on error
      if (context?.previousMessages) {
        queryClient.setQueryData(['messages', channelId], context.previousMessages);
      }
    },
    onSettled: () => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  const removeReactionMutation = useMutation({
    mutationFn: (emoji: string) => removeReaction(messageId, emoji),
    onMutate: async (emoji: string) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['messages', channelId] });

      // Snapshot previous value
      const previousMessages = queryClient.getQueryData<Message[]>(['messages', channelId]);

      // Optimistically update
      queryClient.setQueryData<Message[]>(['messages', channelId], (old) => {
        if (!old) return old;

        return old.map((msg) => {
          if (msg.id !== messageId) return msg;

          const reactions = msg.reactions || [];
          const existingReaction = reactions.find((r) => r.emoji === emoji);

          if (!existingReaction) return msg;

          // Decrement count
          const newCount = existingReaction.count - 1;

          if (newCount <= 0) {
            // Remove reaction if count reaches zero
            return {
              ...msg,
              reactions: reactions.filter((r) => r.emoji !== emoji),
            };
          } else {
            // Update count and me flag
            return {
              ...msg,
              reactions: reactions.map((r) =>
                r.emoji === emoji
                  ? { ...r, count: newCount, me: false }
                  : r
              ),
            };
          }
        });
      });

      return { previousMessages };
    },
    onError: (_err, _emoji, context) => {
      // Rollback on error
      if (context?.previousMessages) {
        queryClient.setQueryData(['messages', channelId], context.previousMessages);
      }
    },
    onSettled: () => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  const toggleReaction = (emoji: string, currentlyReacted: boolean) => {
    if (currentlyReacted) {
      removeReactionMutation.mutate(emoji);
    } else {
      addReactionMutation.mutate(emoji);
    }
  };

  return {
    addReaction: addReactionMutation.mutate,
    removeReaction: removeReactionMutation.mutate,
    toggleReaction,
    isLoading: addReactionMutation.isPending || removeReactionMutation.isPending,
  };
}
