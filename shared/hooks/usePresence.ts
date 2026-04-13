import { useEffect, useState, useCallback, useRef } from 'react';
import { trackPresence } from '@shared/services/realtimeService';
import type { Presence } from '@shared/types/models';

/**
 * Track user presence in a channel and maintain a map of online users.
 */
export function usePresence(
    channelId: string | null,
    userId: string | null,
    username: string | null,
) {
    const [presences, setPresences] = useState<Map<string, Presence>>(new Map());
    const idleTimerRef = useRef<ReturnType<typeof setTimeout>>();
    const [myStatus, setMyStatus] = useState<'online' | 'idle' | 'dnd' | 'offline'>('online');

    // Reset idle timer on activity
    const resetIdleTimer = useCallback(() => {
        if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
        if (myStatus === 'idle') setMyStatus('online');
        idleTimerRef.current = setTimeout(() => {
            setMyStatus('idle');
        }, 5 * 60 * 1000); // 5 minutes
    }, [myStatus]);

    useEffect(() => {
        if (!channelId || !userId || !username) return;

        const unsubscribe = trackPresence(channelId, userId, username, myStatus, {
            onJoin: (uid, state) => {
                setPresences((prev) => {
                    const next = new Map(prev);
                    next.set(uid, {
                        user_id: uid,
                        status: state.status,
                        last_seen: state.online_at,
                    });
                    return next;
                });
            },
            onLeave: (uid) => {
                setPresences((prev) => {
                    const next = new Map(prev);
                    next.delete(uid);
                    return next;
                });
            },
            onSync: (syncPresences) => {
                const newMap = new Map<string, Presence>();
                for (const [key, states] of Object.entries(syncPresences)) {
                    if (states.length > 0) {
                        newMap.set(key, {
                            user_id: states[0].user_id,
                            status: states[0].status,
                            last_seen: states[0].online_at,
                        });
                    }
                }
                setPresences(newMap);
            },
        });

        // Set up activity listeners for idle detection
        const handlers = ['mousemove', 'keydown', 'click', 'scroll'] as const;
        handlers.forEach((event) => window.addEventListener(event, resetIdleTimer));
        resetIdleTimer();

        return () => {
            unsubscribe();
            handlers.forEach((event) => window.removeEventListener(event, resetIdleTimer));
            if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
        };
    }, [channelId, userId, username, myStatus, resetIdleTimer]);

    return { presences, myStatus, setMyStatus };
}
