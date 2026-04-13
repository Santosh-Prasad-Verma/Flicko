/**
 * PresenceTracker
 *
 * Invisible component that keeps the user's `profiles.status` in sync
 * with the app lifecycle (foreground → online, background → idle, closed → offline).
 * Also runs a heartbeat every 60s to keep `last_seen` fresh.
 *
 * Mount this inside AuthGate (only when user is authenticated).
 */
import { useEffect, useRef } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { supabase } from '../services/supabase';
import { useAuthStore } from '@stores/authStore';

const HEARTBEAT_INTERVAL_MS = 60_000; // 1 minute

/**
 * Update the profile status and last_seen timestamp in the DB.
 * Silently catches errors to avoid crashing the app.
 */
async function updatePresence(
  userId: string,
  status: 'online' | 'idle' | 'dnd' | 'offline',
) {
  try {
    await supabase
      .from('profiles')
      .update({ status, last_seen: new Date().toISOString() })
      .eq('id', userId);
  } catch {
    // Swallow — presence updates are best-effort
  }
}

export function PresenceTracker() {
  const user = useAuthStore((s) => s.user);
  const heartbeatRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const statusRef = useRef<'online' | 'idle' | 'offline'>('online');

  useEffect(() => {
    if (!user?.id) return;

    // Set online immediately
    statusRef.current = 'online';
    updatePresence(user.id, 'online');

    // Heartbeat: refresh last_seen every minute
    heartbeatRef.current = setInterval(() => {
      if (statusRef.current === 'online') {
        updatePresence(user.id, 'online');
      }
    }, HEARTBEAT_INTERVAL_MS);

    // AppState listener for foreground/background transitions
    const handleAppState = (state: AppStateStatus) => {
      if (state === 'active') {
        statusRef.current = 'online';
        updatePresence(user.id, 'online');
      } else if (state === 'background' || state === 'inactive') {
        statusRef.current = 'idle';
        updatePresence(user.id, 'idle');
      }
    };

    const subscription = AppState.addEventListener('change', handleAppState);

    return () => {
      subscription.remove();
      if (heartbeatRef.current) clearInterval(heartbeatRef.current);
      // Best-effort offline on unmount (logout / component teardown)
      updatePresence(user.id, 'offline');
    };
  }, [user?.id]);

  return null; // invisible component
}
