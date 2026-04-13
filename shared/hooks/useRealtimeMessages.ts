import { useEffect, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { subscribeToChannel, unsubscribeFromChannel } from '@shared/services/realtimeService';
import type { Message } from '@shared/types/models';

/**
 * Subscribe to real-time message events for a channel.
 * Updates React Query cache on INSERT/UPDATE/DELETE.
 * Unsubscribes on unmount or channelId change.
 */
export function useRealtimeMessages(channelId: string | null) {
    const queryClient = useQueryClient();
    const channelIdRef = useRef(channelId);
    channelIdRef.current = channelId;

    useEffect(() => {
        if (!channelId) return;

        const unsubscribe = subscribeToChannel(channelId, {
            onInsert: (_message: Message) => {
                queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
            },
            onUpdate: (_message: Message) => {
                queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
            },
            onDelete: (_messageId: string) => {
                queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
            },
        });

        return () => {
            // Unsubscribe function returned from subscribeToChannel already calls unsubscribeFromChannel 
            // inside of it. Ensure we just call it and it will await naturally (fire and forget on unmount).
            unsubscribe();
        };
    }, [channelId, queryClient]);
}
