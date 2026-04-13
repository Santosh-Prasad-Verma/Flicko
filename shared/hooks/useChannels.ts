import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getChannels, getChannel, createChannel, deleteChannel } from '@shared/services/channelService';
import type { CreateChannelInput } from '@shared/services/channelService';

export function useChannels(serverId: string | null) {
    return useQuery({
        queryKey: ['channels', serverId],
        queryFn: () => getChannels(serverId!),
        enabled: !!serverId,
        staleTime: 5 * 60 * 1000,
    });
}

export function useChannel(channelId: string | null) {
    return useQuery({
        queryKey: ['channel', channelId],
        queryFn: () => getChannel(channelId!),
        enabled: !!channelId,
        staleTime: 5 * 60 * 1000,
    });
}

export function useCreateChannel() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (input: CreateChannelInput) => createChannel(input),
        onSuccess: (_data, variables) => {
            queryClient.invalidateQueries({ queryKey: ['channels', variables.serverId] });
        },
    });
}

export function useDeleteChannel() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (channelId: string) => deleteChannel(channelId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['channels'] });
        },
    });
}
