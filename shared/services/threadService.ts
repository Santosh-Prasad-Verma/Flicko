import { supabase } from '../lib/supabase';

/**
 * Thread Service
 *
 * Manages thread CRUD, membership, and message operations.
 * Threads are created from messages and have their own message lists,
 * auto-archive behavior, and member tracking.
 */

export interface Thread {
  id: string;
  server_id: string;
  parent_channel_id: string;
  parent_message_id: string | null;
  name: string;
  creator_id: string;
  type: 'public' | 'private' | 'announcement';
  message_count: number;
  member_count: number;
  is_archived: boolean;
  auto_archive_duration: string; // interval
  archive_at: string;
  created_at: string;
  updated_at: string;
  creator?: {
    id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
  };
  last_message?: {
    content: string;
    created_at: string;
    author?: {
      username: string;
    };
  };
}

export interface ThreadMember {
  thread_id: string;
  user_id: string;
  joined_at: string;
  last_read_message_id: string | null;
  notification_settings: {
    all_messages: boolean;
    mentions_only: boolean;
  };
  user?: {
    id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
  };
}

export interface CreateThreadInput {
  channelId: string;
  serverId: string;
  parentMessageId: string;
  name: string;
  type?: 'public' | 'private';
  autoArchiveDuration?: number; // minutes: 60, 1440, 4320, 10080
}

const AUTO_ARCHIVE_DURATIONS: Record<number, string> = {
  60: '1 hour',
  1440: '24 hours',
  4320: '3 days',
  10080: '7 days',
};

/**
 * Create a new thread from a message
 */
export async function createThread(input: CreateThreadInput): Promise<Thread> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const archiveDuration = AUTO_ARCHIVE_DURATIONS[input.autoArchiveDuration ?? 1440] ?? '24 hours';
  const archiveAt = new Date(Date.now() + (input.autoArchiveDuration ?? 1440) * 60 * 1000).toISOString();

  const { data: thread, error } = await supabase
    .from('threads')
    .insert({
      server_id: input.serverId,
      parent_channel_id: input.channelId,
      parent_message_id: input.parentMessageId,
      name: input.name.trim(),
      creator_id: user.id,
      type: input.type ?? 'public',
      auto_archive_duration: archiveDuration,
      archive_at: archiveAt,
    })
    .select('*')
    .single();

  if (error) throw new Error(`Failed to create thread: ${error.message}`);

  // Auto-join the creator
  const { error: joinErr } = await supabase.from('thread_members').insert({
    thread_id: thread.id,
    user_id: user.id,
  });
  if (joinErr) throw new Error(`Failed to auto-join thread creator: ${joinErr.message}`);

  return thread;
}

/**
 * Get threads for a channel
 */
export async function getChannelThreads(channelId: string, includeArchived = false): Promise<Thread[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  let query = supabase
    .from('threads')
    .select('*, creator:profiles!creator_id(id, username, display_name, avatar_url)')
    .eq('parent_channel_id', channelId)
    .order('created_at', { ascending: false });

  if (!includeArchived) {
    query = query.eq('is_archived', false);
  }

  const { data, error } = await query;
  if (error) throw new Error(`Failed to fetch threads: ${error.message}`);
  return data ?? [];
}

/**
 * Get a single thread by ID
 */
export async function getThread(threadId: string): Promise<Thread> {
  const { data, error } = await supabase
    .from('threads')
    .select('*, creator:profiles!creator_id(id, username, display_name, avatar_url)')
    .eq('id', threadId)
    .single();

  if (error) throw new Error(`Failed to fetch thread: ${error.message}`);
  return data;
}

/**
 * Get messages in a thread
 */
export async function getThreadMessages(threadId: string, limit = 50, before?: string) {
  let query = supabase
    .from('messages')
    .select('*, author:profiles!author_id(id, username, display_name, avatar_url)')
    .eq('thread_id', threadId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (before) {
    const { data: beforeMsg } = await supabase
      .from('messages')
      .select('created_at')
      .eq('id', before)
      .single();
    if (beforeMsg) {
      query = query.lt('created_at', beforeMsg.created_at);
    }
  }

  const { data, error } = await query;
  if (error) throw new Error(`Failed to fetch thread messages: ${error.message}`);
  return (data ?? []).reverse();
}

/**
 * Send a message in a thread
 */
export async function sendThreadMessage(
  threadId: string, 
  channelId: string, 
  content: string, 
  options?: { isSilent?: boolean }
) {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData.session?.access_token;
  if (!token) throw new Error('Not authenticated');

  if (!content.trim()) throw new Error('Message content cannot be empty');
  if (content.length > 2000) throw new Error('Message too long');

  const API_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8080';
  const payload = {
    content: content.trim(),
    type: 'default',
    thread_id: threadId,
    is_silent: options?.isSilent || false,
  };

  const res = await fetch(`${API_URL}/v1/channels/${channelId}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(errText || 'Failed to send thread message');
  }

  const { id: messageId } = await res.json();

  // Update thread message count and archive timestamp
  await supabase.rpc('increment_thread_count', { thread_id: threadId }).catch(() => {
    // Fallback: direct update
    supabase
      .from('threads')
      .update({
        message_count: supabase.rpc ? undefined : 0, // Will be handled by trigger
        updated_at: new Date().toISOString(),
      })
      .eq('id', threadId)
      .then(() => {});
  });

  return { id: messageId };
}

/**
 * Get thread members
 */
export async function getThreadMembers(threadId: string): Promise<ThreadMember[]> {
  const { data, error } = await supabase
    .from('thread_members')
    .select('*, user:profiles!user_id(id, username, display_name, avatar_url)')
    .eq('thread_id', threadId);

  if (error) throw new Error(`Failed to fetch thread members: ${error.message}`);
  return data ?? [];
}

/**
 * Join a thread
 */
export async function joinThread(threadId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { error } = await supabase
    .from('thread_members')
    .upsert({
      thread_id: threadId,
      user_id: user.id,
    });

  if (error) throw new Error(`Failed to join thread: ${error.message}`);
}

/**
 * Leave a thread
 */
export async function leaveThread(threadId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { error } = await supabase
    .from('thread_members')
    .delete()
    .eq('thread_id', threadId)
    .eq('user_id', user.id);

  if (error) throw new Error(`Failed to leave thread: ${error.message}`);
}

/**
 * Archive/unarchive a thread (creator or admin only)
 */
export async function toggleThreadArchive(threadId: string, archived: boolean): Promise<void> {
  const { error } = await supabase
    .from('threads')
    .update({
      is_archived: archived,
      updated_at: new Date().toISOString(),
    })
    .eq('id', threadId);

  if (error) throw new Error(`Failed to update thread: ${error.message}`);
}

/**
 * Update thread notification settings
 */
export async function updateThreadNotifications(
  threadId: string,
  settings: { all_messages?: boolean; mentions_only?: boolean }
): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const { error } = await supabase
    .from('thread_members')
    .update({
      notification_settings: settings,
    })
    .eq('thread_id', threadId)
    .eq('user_id', user.id);

  if (error) throw new Error(`Failed to update notification settings: ${error.message}`);
}
