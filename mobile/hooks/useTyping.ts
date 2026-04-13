/**
 * useTyping Hook (Mobile)
 *
 * Provides typing indicator tracking with throttled sends,
 * mirroring shared/hooks/useTyping using Supabase broadcast.
 */
import { useEffect, useState, useCallback, useRef } from 'react';
import { supabase } from '../services/supabase';

interface TypingUser {
  userId: string;
  username: string;
}

export function useTyping(
  channelId: string | null,
  userId: string | null,
  username: string | null,
) {
  const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const cleanupTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);

  // Send typing indicator (uses the subscribed channel ref)
  const startTyping = useCallback(() => {
    if (!channelRef.current || !userId || !username) return;

    channelRef.current.send({
      type: 'broadcast',
      event: 'typing_start',
      payload: { userId, username },
    });

    // Auto-stop after 5 seconds
    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    typingTimeoutRef.current = setTimeout(() => {
      stopTyping();
    }, 5000);
  }, [userId, username]);

  // Stop typing indicator
  const stopTyping = useCallback(() => {
    if (!channelRef.current || !userId) return;

    channelRef.current.send({
      type: 'broadcast',
      event: 'typing_stop',
      payload: { userId },
    });

    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
  }, [userId]);

  // Subscribe to other users' typing indicators
  useEffect(() => {
    if (!channelId || !userId) return;

    const channel = supabase.channel(`typing-${channelId}`);
    channelRef.current = channel;

    channel
      .on('broadcast', { event: 'typing_start' }, ({ payload }) => {
        if (payload.userId === userId) return; // skip self
        setTypingUsers((prev) => {
          if (prev.find((u) => u.userId === payload.userId)) return prev;
          return [...prev, { userId: payload.userId, username: payload.username }];
        });

        // Auto-remove after 6 seconds if no update
        const existingTimer = cleanupTimers.current.get(payload.userId);
        if (existingTimer) clearTimeout(existingTimer);
        cleanupTimers.current.set(
          payload.userId,
          setTimeout(() => {
            setTypingUsers((prev) => prev.filter((u) => u.userId !== payload.userId));
            cleanupTimers.current.delete(payload.userId);
          }, 6000),
        );
      })
      .on('broadcast', { event: 'typing_stop' }, ({ payload }) => {
        setTypingUsers((prev) => prev.filter((u) => u.userId !== payload.userId));
        const timer = cleanupTimers.current.get(payload.userId);
        if (timer) {
          clearTimeout(timer);
          cleanupTimers.current.delete(payload.userId);
        }
      })
      .subscribe();

    return () => {
      channelRef.current = null;
      supabase.removeChannel(channel);
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      cleanupTimers.current.forEach((timer) => clearTimeout(timer));
      cleanupTimers.current.clear();
    };
  }, [channelId, userId]);

  return { typingUsers, startTyping, stopTyping };
}
