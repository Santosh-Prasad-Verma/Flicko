/**
 * Stream Service — CRUD and realtime subscriptions for Go Live streams
 *
 * Zero-cost: All data in Supabase Postgres (self-hosted on OCI)
 */
import { supabase } from '../lib/supabase';
import { RealtimeChannel } from '@supabase/supabase-js';

// ──────────────────────────────────────────
// Types
// ──────────────────────────────────────────

export interface Stream {
  id: string;
  user_id: string;
  channel_id: string;
  server_id: string;
  title: string;
  status: 'starting' | 'live' | 'ended' | 'errored';
  stream_type: 'screen' | 'application' | 'game' | 'camera';
  max_quality: string;
  actual_quality: string | null;
  viewer_count: number;
  max_viewers: number;
  application_name: string | null;
  started_at: string;
  ended_at: string | null;
  // Joined from profiles
  user?: {
    username: string;
    avatar_url: string | null;
  };
}

export interface StreamViewer {
  id: string;
  stream_id: string;
  user_id: string;
  joined_at: string;
  left_at: string | null;
  user?: {
    username: string;
    avatar_url: string | null;
  };
}

// ──────────────────────────────────────────
// CRUD Operations
// ──────────────────────────────────────────

export async function getActiveStreams(channelId: string): Promise<Stream[]> {
  const { data, error } = await supabase
    .from('streams')
    .select(`
      *,
      user:profiles!user_id(username, avatar_url)
    `)
    .eq('channel_id', channelId)
    .in('status', ['starting', 'live'])
    .order('started_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

export async function getStreamById(streamId: string): Promise<Stream | null> {
  const { data, error } = await supabase
    .from('streams')
    .select(`
      *,
      user:profiles!user_id(username, avatar_url)
    `)
    .eq('id', streamId)
    .single();

  if (error) return null;
  return data;
}

export async function getStreamViewers(streamId: string): Promise<StreamViewer[]> {
  const { data, error } = await supabase
    .from('stream_viewers')
    .select(`
      *,
      user:profiles!user_id(username, avatar_url)
    `)
    .eq('stream_id', streamId)
    .is('left_at', null)
    .order('joined_at', { ascending: true });

  if (error) throw error;
  return data || [];
}

export async function getServerActiveStreams(serverId: string): Promise<Stream[]> {
  const { data, error } = await supabase
    .from('streams')
    .select(`
      *,
      user:profiles!user_id(username, avatar_url)
    `)
    .eq('server_id', serverId)
    .eq('status', 'live')
    .order('viewer_count', { ascending: false });

  if (error) throw error;
  return data || [];
}

export async function updateStreamTitle(streamId: string, title: string): Promise<void> {
  const { error } = await supabase
    .from('streams')
    .update({ title })
    .eq('id', streamId);

  if (error) throw error;
}

// ──────────────────────────────────────────
// Realtime Subscriptions
// ──────────────────────────────────────────

export function subscribeToChannelStreams(
  channelId: string,
  callbacks: {
    onStreamStarted?: (stream: Stream) => void;
    onStreamUpdated?: (stream: Stream) => void;
    onStreamEnded?: (stream: Stream) => void;
  }
): RealtimeChannel {
  return supabase
    .channel(`streams:channel:${channelId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'streams',
        filter: `channel_id=eq.${channelId}`,
      },
      (payload) => {
        callbacks.onStreamStarted?.(payload.new as Stream);
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'streams',
        filter: `channel_id=eq.${channelId}`,
      },
      (payload) => {
        const stream = payload.new as Stream;
        if (stream.status === 'ended' || stream.status === 'errored') {
          callbacks.onStreamEnded?.(stream);
        } else {
          callbacks.onStreamUpdated?.(stream);
        }
      }
    )
    .subscribe();
}

export function subscribeToStreamViewerCount(
  streamId: string,
  onViewerCountChange: (count: number) => void
): RealtimeChannel {
  return supabase
    .channel(`stream_viewers:${streamId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'stream_viewers',
        filter: `stream_id=eq.${streamId}`,
      },
      async () => {
        // Re-fetch current count
        const { count } = await supabase
          .from('stream_viewers')
          .select('id', { count: 'exact', head: true })
          .eq('stream_id', streamId)
          .is('left_at', null);

        onViewerCountChange(count || 0);
      }
    )
    .subscribe();
}
