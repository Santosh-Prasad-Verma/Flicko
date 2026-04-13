/**
 * User Status Service
 *
 * Custom status + presence management.
 * Requirements: Feature 19 (User Status System)
 */
import { supabase } from '../lib/supabase';

export type PresenceStatus = 'online' | 'idle' | 'dnd' | 'offline' | 'invisible';

export interface CustomStatus {
  text: string | null;
  emoji: string | null;
  expires_at: string | null;
}

export interface UserPresence {
  user_id: string;
  status: PresenceStatus;
  custom_status: CustomStatus | null;
  last_seen: string;
}

// ─── Presence ──────────────────────────────────────────────────────────────────

export async function getPresence(userId: string): Promise<UserPresence | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, status, custom_status, last_seen')
    .eq('id', userId)
    .single();
  if (error) throw error;
  return data ? { user_id: data.id, status: data.status, custom_status: data.custom_status, last_seen: data.last_seen } : null;
}

export async function setPresenceStatus(userId: string, status: PresenceStatus) {
  const { error } = await supabase
    .from('profiles')
    .update({ status, last_seen: new Date().toISOString() })
    .eq('id', userId);
  if (error) throw error;
}

export async function setCustomStatus(
  userId: string,
  customStatus: CustomStatus | null,
) {
  const { error } = await supabase
    .from('profiles')
    .update({ custom_status: customStatus })
    .eq('id', userId);
  if (error) throw error;
}

// ─── Bulk presence for member list ─────────────────────────────────────────────

export async function getBulkPresence(userIds: string[]): Promise<UserPresence[]> {
  if (userIds.length === 0) return [];
  const { data, error } = await supabase
    .from('profiles')
    .select('id, status, custom_status, last_seen')
    .in('id', userIds);
  if (error) throw error;
  return (data ?? []).map((d: any) => ({
    user_id: d.id,
    status: d.status,
    custom_status: d.custom_status,
    last_seen: d.last_seen,
  }));
}

// ─── Status presets ────────────────────────────────────────────────────────────

export const STATUS_OPTIONS: { value: PresenceStatus; label: string; icon: string; color: string }[] = [
  { value: 'online', label: 'Online', icon: 'ellipse', color: '#2ECC71' },
  { value: 'idle', label: 'Idle', icon: 'moon', color: '#FECA57' },
  { value: 'dnd', label: 'Do Not Disturb', icon: 'remove-circle', color: '#FF4757' },
  { value: 'invisible', label: 'Invisible', icon: 'ellipse-outline', color: '#8A8AA3' },
];

export const CUSTOM_STATUS_PRESETS = [
  { emoji: '🎮', text: 'Playing games' },
  { emoji: '💻', text: 'Coding' },
  { emoji: '📚', text: 'Studying' },
  { emoji: '🎵', text: 'Listening to music' },
  { emoji: '😴', text: 'Sleeping' },
  { emoji: '🍕', text: 'Eating' },
  { emoji: '🏃', text: 'Away' },
  { emoji: '📱', text: 'On mobile' },
];
