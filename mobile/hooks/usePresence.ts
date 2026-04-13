/**
 * usePresence Hook (Mobile)
 *
 * Tracks user presence in a channel via Supabase Presence.
 * Mirrors the shared/hooks/usePresence pattern but uses React Native-compatible APIs.
 */
import { useEffect, useState, useCallback, useRef } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { supabase } from '../services/supabase';

export interface PresenceEntry {
  user_id: string;
  status: 'online' | 'idle' | 'dnd' | 'offline';
  last_seen: string;
}

export function usePresence(
  channelId: string | null,
  userId: string | null,
  username: string | null,
) {
  const [presences, setPresences] = useState<Map<string, PresenceEntry>>(new Map());
  const [myStatus, setMyStatus] = useState<'online' | 'idle' | 'dnd' | 'offline'>('online');
  const idleTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  // Track app state for idle detection (mobile equivalent of mouse/keyboard events)
  useEffect(() => {
    const handleAppStateChange = (state: AppStateStatus) => {
      if (state === 'active') {
        setMyStatus('online');
        resetIdleTimer();
      } else if (state === 'background' || state === 'inactive') {
        setMyStatus('idle');
        if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
      }
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);
    return () => subscription.remove();
  }, [resetIdleTimer]);

  const resetIdleTimer = useCallback(() => {
    if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
    if (myStatus === 'idle') setMyStatus('online');
    idleTimerRef.current = setTimeout(() => {
      setMyStatus('idle');
    }, 5 * 60 * 1000); // 5 minutes
  }, [myStatus]);

  useEffect(() => {
    if (!channelId || !userId || !username) return;

    const channel = supabase.channel(`presence-${channelId}`);

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState();
        const newMap = new Map<string, PresenceEntry>();
        for (const [_key, states] of Object.entries(state)) {
          const arr = states as any[];
          if (arr.length > 0) {
            newMap.set(arr[0].user_id, {
              user_id: arr[0].user_id,
              status: arr[0].status || 'online',
              last_seen: arr[0].online_at || new Date().toISOString(),
            });
          }
        }
        setPresences(newMap);
      })
      .on('presence', { event: 'join' }, ({ key, newPresences }) => {
        setPresences((prev) => {
          const next = new Map(prev);
          for (const p of newPresences) {
            next.set(p.user_id, {
              user_id: p.user_id,
              status: p.status || 'online',
              last_seen: p.online_at || new Date().toISOString(),
            });
          }
          return next;
        });
      })
      .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
        setPresences((prev) => {
          const next = new Map(prev);
          for (const p of leftPresences) {
            next.delete(p.user_id);
          }
          return next;
        });
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({
            user_id: userId,
            username,
            status: myStatus,
            online_at: new Date().toISOString(),
          });
        }
      });

    return () => {
      channel.untrack();
      supabase.removeChannel(channel);
      if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
    };
  }, [channelId, userId, username, myStatus]);

  return { presences, myStatus, setMyStatus };
}
