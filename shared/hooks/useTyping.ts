import { useEffect, useState, useCallback, useRef } from 'react';
import { sendTypingIndicator, stopTypingIndicator, subscribeToTyping } from '@shared/services/realtimeService';

interface TypingUser {
    userId: string;
    username: string;
}

/**
 * Typing indicator hook: throttled sending + tracking other users typing.
 */
export function useTyping(
    channelId: string | null,
    userId: string | null,
    username: string | null,
) {
    const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
    const typingTimeoutRef = useRef<ReturnType<typeof setTimeout>>();

    // Start/update typing indicator
    const startTyping = useCallback(() => {
        if (!channelId || !userId || !username) return;
        sendTypingIndicator(channelId, userId, username);

        // Auto-stop after 5 seconds of no typing
        if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
        typingTimeoutRef.current = setTimeout(() => {
            if (channelId && userId) {
                stopTypingIndicator(channelId, userId);
            }
        }, 5000);
    }, [channelId, userId, username]);

    // Stop typing indicator
    const stopTyping = useCallback(() => {
        if (!channelId || !userId) return;
        stopTypingIndicator(channelId, userId);
        if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    }, [channelId, userId]);

    // Subscribe to other users' typing indicators
    useEffect(() => {
        if (!channelId || !userId) return;

        const unsubscribe = subscribeToTyping(channelId, userId, {
            onTypingStart: (uid, uname) => {
                setTypingUsers((prev) => {
                    if (prev.find((u) => u.userId === uid)) return prev;
                    return [...prev, { userId: uid, username: uname }];
                });
            },
            onTypingStop: (uid) => {
                setTypingUsers((prev) => prev.filter((u) => u.userId !== uid));
            },
        });

        return () => {
            unsubscribe();
            if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
        };
    }, [channelId, userId]);

    return { typingUsers, startTyping, stopTyping };
}
