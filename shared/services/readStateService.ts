/**
 * Read State Service
 *
 * Track per-channel read position for unread indicators.
 * Requirements: Feature 31 (Read States / Unread Tracking)
 */
import { supabase } from '../lib/supabase';

export interface ChannelReadState {
  channel_id: string;
  user_id: string;
  last_read_message_id: string | null;
  mention_count: number;
  last_read_at: string;
}

/**
 * Get read state for a single channel.
 */
export async function getReadState(
  channelId: string,
  userId: string,
): Promise<ChannelReadState | null> {
  const { data, error } = await supabase
    .from('channel_read_states')
    .select('*')
    .eq('channel_id', channelId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/**
 * Get read states for all channels the user can see in a server.
 */
export async function getServerReadStates(
  userId: string,
  channelIds: string[],
): Promise<ChannelReadState[]> {
  if (channelIds.length === 0) return [];
  const { data, error } = await supabase
    .from('channel_read_states')
    .select('*')
    .eq('user_id', userId)
    .in('channel_id', channelIds);
  if (error) throw error;
  return data ?? [];
}

/**
 * Mark a channel as read up to a given message ID.
 */
export async function markChannelRead(
  channelId: string,
  userId: string,
  lastReadMessageId: string,
) {
  const { error } = await supabase
    .from('channel_read_states')
    .upsert(
      {
        channel_id: channelId,
        user_id: userId,
        last_read_message_id: lastReadMessageId,
        mention_count: 0,
        last_read_at: new Date().toISOString(),
      },
      { onConflict: 'channel_id,user_id' },
    );
  if (error) throw error;
}

/**
 * Mark all channels in a server as read.
 */
export async function markServerRead(
  userId: string,
  channelIds: string[],
) {
  if (channelIds.length === 0) return;
  const promises = channelIds.map((chId) =>
    supabase
      .from('channel_read_states')
      .upsert(
        {
          channel_id: chId,
          user_id: userId,
          mention_count: 0,
          last_read_at: new Date().toISOString(),
        },
        { onConflict: 'channel_id,user_id' },
      ),
  );
  await Promise.all(promises);
}

/**
 * Increment mention count for a channel (called when user is @mentioned).
 */
export async function incrementMentionCount(
  channelId: string,
  userId: string,
) {
  // RPC call if database function exists, otherwise upsert
  const existing = await getReadState(channelId, userId);
  const newCount = (existing?.mention_count ?? 0) + 1;

  const { error } = await supabase
    .from('channel_read_states')
    .upsert(
      {
        channel_id: channelId,
        user_id: userId,
        mention_count: newCount,
      },
      { onConflict: 'channel_id,user_id' },
    );
  if (error) throw error;
}

/**
 * Check if a channel has unread messages.
 */
export function isChannelUnread(
  readState: ChannelReadState | null,
  latestMessageId: string | null,
): boolean {
  if (!readState || !latestMessageId) return false;
  if (!readState.last_read_message_id) return true;
  return readState.last_read_message_id !== latestMessageId;
}
