import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getMessages, sendMessage, editMessage, deleteMessage } from '@/services/messageService';
import type { SendMessageInput, EditMessageInput } from '@/services/messageService';
import type { Message } from '@shared/types/models';

const PAGE_SIZE = 50;

export function useMessages(channelId: string | null) {
    return useInfiniteQuery({
        queryKey: ['messages', channelId],
        queryFn: ({ pageParam }) =>
            getMessages({
                channelId: channelId!,
                limit: PAGE_SIZE,
                before: pageParam as string | undefined,
            }),
        enabled: !!channelId,
        initialPageParam: undefined as string | undefined,
        getNextPageParam: (lastPage) => {
            if (lastPage.length < PAGE_SIZE) return undefined;
            return lastPage[0]?.id;
        },
        staleTime: 30 * 1000,
    });
}

export function useSendMessage() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (input: SendMessageInput) => sendMessage(input),
        onMutate: async (input) => {
            await queryClient.cancelQueries({ queryKey: ['messages', input.channelId] });
            const previousData = queryClient.getQueryData(['messages', input.channelId]);
            const optimisticMessage: Partial<Message> = {
                id: `optimistic-${Date.now()}`,
                channel_id: input.channelId,
                content: input.content,
                created_at: new Date().toISOString(),
                reactions: [],
                attachments: [],
                embeds: [],
                mentions: [],
                mention_roles: [],
                mention_everyone: false,
                pinned: false,
                edited: false,
                type: input.replyToId ? 'reply' : 'default',
                reply_to_id: input.replyToId || null,
                updated_at: null,
            };
            queryClient.setQueryData(['messages', input.channelId], (old: { pages: Message[][]; pageParams: unknown[] } | undefined) => {
                if (!old) return old;
                const newPages = [...old.pages];
                newPages[newPages.length - 1] = [...(newPages[newPages.length - 1] || []), optimisticMessage as Message];
                return { ...old, pages: newPages };
            });
            return { previousData };
        },
        onSuccess: (_data, variables) => {
            queryClient.invalidateQueries({ queryKey: ['messages', variables.channelId] });
        },
        onError: (_error, variables, context) => {
            if (context?.previousData) {
                queryClient.setQueryData(['messages', variables.channelId], context.previousData);
            }
            queryClient.invalidateQueries({ queryKey: ['messages', variables.channelId] });
        },
    });
}

export function useEditMessage() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: ({ messageId, input }: { messageId: string; channelId: string; input: EditMessageInput }) =>
            editMessage(messageId, input),
        onMutate: async ({ messageId, channelId, input }) => {
            await queryClient.cancelQueries({ queryKey: ['messages', channelId] });
            const previousData = queryClient.getQueryData(['messages', channelId]);
            queryClient.setQueryData(['messages', channelId], (old: { pages: Message[][]; pageParams: unknown[] } | undefined) => {
                if (!old) return old;
                return {
                    ...old,
                    pages: old.pages.map((page) =>
                        page.map((msg) =>
                            msg.id === messageId ? { ...msg, content: input.content, edited: true } : msg,
                        ),
                    ),
                };
            });
            return { previousData, channelId };
        },
        onSuccess: (_data, { channelId }) => {
            queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
        },
        onError: (_error, _variables, context) => {
            if (context?.previousData) {
                queryClient.setQueryData(['messages', context.channelId], context.previousData);
            }
        },
    });
}

export function useDeleteMessage() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: ({ messageId }: { messageId: string; channelId: string }) =>
            deleteMessage(messageId),
        onMutate: async ({ messageId, channelId }) => {
            await queryClient.cancelQueries({ queryKey: ['messages', channelId] });
            const previousData = queryClient.getQueryData(['messages', channelId]);
            queryClient.setQueryData(['messages', channelId], (old: { pages: Message[][]; pageParams: unknown[] } | undefined) => {
                if (!old) return old;
                return {
                    ...old,
                    pages: old.pages.map((page) => page.filter((msg) => msg.id !== messageId)),
                };
            });
            return { previousData, channelId };
        },
        onSuccess: (_data, { channelId }) => {
            queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
        },
        onError: (_error, _variables, context) => {
            if (context?.previousData) {
                queryClient.setQueryData(['messages', context.channelId], context.previousData);
            }
        },
    });
}
