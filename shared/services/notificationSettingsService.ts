/**
 * Notification Settings Service
 *
 * Per-server, per-channel, per-category notification preferences.
 * Requirements: Feature 18 (Notification Granularity)
 */
import { supabase } from '../lib/supabase';

export type NotifyLevel = 'all' | 'mentions' | 'none' | 'default';

export interface ServerNotificationSettings {
  server_id: string;
  user_id: string;
  level: NotifyLevel;
  suppress_everyone: boolean;
  suppress_role_mentions: boolean;
  mobile_push: boolean;
}

export interface ChannelNotificationSettings {
  channel_id: string;
  user_id: string;
  level: NotifyLevel;
  muted: boolean;
  mute_until: string | null;
}

// ─── Server-level ──────────────────────────────────────────────────────────────

export async function getServerNotificationSettings(
  serverId: string,
  userId: string,
): Promise<ServerNotificationSettings | null> {
  const { data, error } = await supabase
    .from('server_notification_settings')
    .select('*')
    .eq('server_id', serverId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function updateServerNotificationSettings(
  serverId: string,
  userId: string,
  updates: Partial<Omit<ServerNotificationSettings, 'server_id' | 'user_id'>>,
) {
  const { error } = await supabase
    .from('server_notification_settings')
    .upsert(
      { server_id: serverId, user_id: userId, ...updates },
      { onConflict: 'server_id,user_id' },
    );
  if (error) throw error;
}

// ─── Channel-level ─────────────────────────────────────────────────────────────

export async function getChannelNotificationSettings(
  channelId: string,
  userId: string,
): Promise<ChannelNotificationSettings | null> {
  const { data, error } = await supabase
    .from('channel_notification_settings')
    .select('*')
    .eq('channel_id', channelId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function updateChannelNotificationSettings(
  channelId: string,
  userId: string,
  updates: Partial<Omit<ChannelNotificationSettings, 'channel_id' | 'user_id'>>,
) {
  const { error } = await supabase
    .from('channel_notification_settings')
    .upsert(
      { channel_id: channelId, user_id: userId, ...updates },
      { onConflict: 'channel_id,user_id' },
    );
  if (error) throw error;
}

// ─── Mute shortcuts ────────────────────────────────────────────────────────────

export const MUTE_DURATIONS = [
  { label: '15 minutes', seconds: 900 },
  { label: '1 hour', seconds: 3600 },
  { label: '8 hours', seconds: 28800 },
  { label: '24 hours', seconds: 86400 },
  { label: 'Until I turn it back on', seconds: 0 },
] as const;

export async function muteChannel(channelId: string, userId: string, durationSeconds: number) {
  const muteUntil = durationSeconds > 0
    ? new Date(Date.now() + durationSeconds * 1000).toISOString()
    : null; // null = indefinite

  await updateChannelNotificationSettings(channelId, userId, {
    muted: true,
    mute_until: muteUntil,
  });
}

export async function unmuteChannel(channelId: string, userId: string) {
  await updateChannelNotificationSettings(channelId, userId, {
    muted: false,
    mute_until: null,
  });
}
