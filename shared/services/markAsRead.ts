/**
 * Mark As Read Actions (Feature 8)
 *
 * Provides mark-as-read for servers, channels, and all.
 * Uses readStateStore under the hood.
 */
import { useReadStateStore } from '../stores/readStateStore';
import { supabase } from '../lib/supabase';

export async function markChannelAsRead(channelId: string, userId: string) {
  const now = new Date().toISOString();
  useReadStateStore.getState().markRead(channelId, 'latest', now);

  try {
    await supabase
      .from('read_states')
      .upsert(
        { user_id: userId, channel_id: channelId, last_read_at: now, last_read_message_id: null },
        { onConflict: 'user_id,channel_id' },
      );
  } catch (err) {
    console.error('[markAsRead] markChannelAsRead failed:', err);
  }
}

export async function markServerAsRead(serverId: string, userId: string) {
  try {
    // Get all channels in this server
    const { data: channels } = await supabase
      .from('channels')
      .select('id')
      .eq('server_id', serverId);

    if (!channels) return;

    const now = new Date().toISOString();
    const store = useReadStateStore.getState();

    for (const ch of channels) {
      store.markRead(ch.id, 'latest', now);
    }

    // Batch upsert read states
    const upserts = channels.map((ch) => ({
      user_id: userId,
      channel_id: ch.id,
      last_read_at: now,
      last_read_message_id: null,
    }));

    await supabase
      .from('read_states')
      .upsert(upserts, { onConflict: 'user_id,channel_id' });
  } catch (err) {
    console.error('[markAsRead] markServerAsRead failed:', err);
  }
}

export async function markAllAsRead(userId: string) {
  try {
    const { data: readStates } = await supabase
      .from('read_states')
      .select('channel_id')
      .eq('user_id', userId);

    const now = new Date().toISOString();
    const store = useReadStateStore.getState();

    if (readStates) {
      for (const rs of readStates) {
        store.markRead(rs.channel_id, 'latest', now);
      }
    }

    await supabase.rpc('mark_all_read', { p_user_id: userId, p_read_at: now });
  } catch (err) {
    console.error('[markAsRead] markAllAsRead failed:', err);
  }
}
