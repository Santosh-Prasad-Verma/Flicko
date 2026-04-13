import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getDMConversations, getDMMessages, sendDM } from '@shared/services/dmService';
import type { SendDMInput } from '@shared/services/dmService';

const PAGE_SIZE = 50;

export function useDMConversations() {
    return useQuery({
        queryKey: ['dm-conversations'],
        queryFn: getDMConversations,
        staleTime: 30 * 1000,
    });
}

export function useDMMessages(otherUserId: string | null) {
    return useInfiniteQuery({
        queryKey: ['dm-messages', otherUserId],
        queryFn: ({ pageParam }) =>
            getDMMessages({
                otherUserId: otherUserId!,
                limit: PAGE_SIZE,
                before: pageParam as string | undefined,
            }),
        enabled: !!otherUserId,
        initialPageParam: undefined as string | undefined,
        getNextPageParam: (lastPage) => {
            if (lastPage.length < PAGE_SIZE) return undefined;
            return lastPage[0]?.id;
        },
        staleTime: 30 * 1000,
    });
}

export function useSendDM() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (input: SendDMInput) => sendDM(input),
        onMutate: async (input) => {
            await queryClient.cancelQueries({ queryKey: ['dm-messages', input.recipientId] });
            const previousMessages = queryClient.getQueryData(['dm-messages', input.recipientId]);
            return { previousMessages };
        },
        onSuccess: (_data, variables) => {
            queryClient.invalidateQueries({ queryKey: ['dm-messages', variables.recipientId] });
            queryClient.invalidateQueries({ queryKey: ['dm-conversations'] });
        },
        onError: (_error, variables, context) => {
            if (context?.previousMessages) {
                queryClient.setQueryData(['dm-messages', variables.recipientId], context.previousMessages);
            }
        },
    });
}
