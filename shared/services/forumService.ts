/**
 * Forum Service
 *
 * Forum channels use threads as "posts." Each post can have tags.
 * Admin configures available tags per forum channel.
 */
import { supabase } from '../lib/supabase';

// ─── Types ─────────────────────────────────────────────────────────────────────

export interface ForumTag {
  id: string;
  channel_id: string;
  name: string;
  emoji: string | null;
  moderated: boolean;
  position: number;
  created_at: string;
}

export interface ForumPost {
  id: string; // thread.id
  name: string; // thread.name (post title)
  creator_id: string;
  message_count: number;
  last_message_at: string | null;
  archived: boolean;
  locked: boolean;
  created_at: string;
  tags: ForumTag[];
  creator?: { id: string; username: string; display_name: string; avatar_url: string };
}

export interface CreateForumPostInput {
  channelId: string;
  serverId: string;
  title: string;
  content: string; // initial message body
  tagIds?: string[];
}

// ─── Tag Management ────────────────────────────────────────────────────────────

export async function getForumTags(channelId: string): Promise<ForumTag[]> {
  const { data, error } = await supabase
    .from('forum_tags')
    .select('*')
    .eq('channel_id', channelId)
    .order('position');
  if (error) throw new Error(`Failed to fetch tags: ${error.message}`);
  return data ?? [];
}

export async function createForumTag(
  channelId: string,
  name: string,
  emoji?: string,
  moderated = false,
): Promise<ForumTag> {
  const { data: existing } = await supabase
    .from('forum_tags')
    .select('position')
    .eq('channel_id', channelId)
    .order('position', { ascending: false })
    .limit(1);

  const nextPos = (existing?.[0]?.position ?? -1) + 1;

  const { data, error } = await supabase
    .from('forum_tags')
    .insert({ channel_id: channelId, name, emoji: emoji ?? null, moderated, position: nextPos })
    .select('*')
    .single();
  if (error) throw new Error(`Failed to create tag: ${error.message}`);
  return data;
}

export async function updateForumTag(
  tagId: string,
  updates: Partial<Pick<ForumTag, 'name' | 'emoji' | 'moderated' | 'position'>>,
): Promise<ForumTag> {
  const { data, error } = await supabase
    .from('forum_tags')
    .update(updates)
    .eq('id', tagId)
    .select('*')
    .single();
  if (error) throw new Error(`Failed to update tag: ${error.message}`);
  return data;
}

export async function deleteForumTag(tagId: string): Promise<void> {
  const { error } = await supabase.from('forum_tags').delete().eq('id', tagId);
  if (error) throw new Error(`Failed to delete tag: ${error.message}`);
}

// ─── Forum Posts (Threads) ─────────────────────────────────────────────────────

export async function getForumPosts(
  channelId: string,
  options?: {
    sort?: 'latest_activity' | 'creation_date';
    tagId?: string;
    includeArchived?: boolean;
    limit?: number;
    before?: string;
  },
): Promise<ForumPost[]> {
  const limit = options?.limit ?? 25;
  const sort = options?.sort ?? 'latest_activity';

  let query = supabase
    .from('threads')
    .select(`
      *,
      creator:profiles!creator_id(id, username, display_name, avatar_url),
      tags:forum_post_tags(tag:forum_tags(*))
    `)
    .eq('parent_channel_id', channelId);

  if (!options?.includeArchived) {
    query = query.eq('archived', false);
  }

  if (options?.before) {
    query = query.lt('created_at', options.before);
  }

  if (sort === 'latest_activity') {
    query = query.order('last_message_at', { ascending: false, nullsFirst: false });
  } else {
    query = query.order('created_at', { ascending: false });
  }

  query = query.limit(limit);

  const { data, error } = await query;
  if (error) throw new Error(`Failed to fetch forum posts: ${error.message}`);

  // Flatten nested tags
  return (data ?? []).map((t: any) => ({
    id: t.id,
    name: t.name,
    creator_id: t.creator_id,
    message_count: t.message_count ?? 0,
    last_message_at: t.last_message_at,
    archived: t.archived,
    locked: t.locked,
    created_at: t.created_at,
    creator: t.creator,
    tags: (t.tags ?? []).map((pt: any) => pt.tag).filter(Boolean),
  }));
}

export async function createForumPost(input: CreateForumPostInput): Promise<ForumPost> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // 1. Create thread
  const { data: thread, error: threadErr } = await supabase
    .from('threads')
    .insert({
      server_id: input.serverId,
      parent_channel_id: input.channelId,
      name: input.title,
      creator_id: user.id,
      type: 'public',
      auto_archive_duration: '10080 minutes', // 7 days
      archive_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    })
    .select('*')
    .single();
  if (threadErr) throw new Error(`Failed to create post: ${threadErr.message}`);

  // 2. Create initial message
  const { error: msgErr } = await supabase.from('messages').insert({
    channel_id: input.channelId,
    thread_id: thread.id,
    author_id: user.id,
    content: input.content,
    type: 'default',
  });
  if (msgErr) throw new Error(`Failed to create post message: ${msgErr.message}`);

  // 3. Add tags
  if (input.tagIds?.length) {
    const { error: tagErr } = await supabase.from('forum_post_tags').insert(
      input.tagIds.map((tagId) => ({ thread_id: thread.id, tag_id: tagId })),
    );
    if (tagErr) throw new Error(`Failed to add post tags: ${tagErr.message}`);
  }

  // 4. Auto-join creator
  const { error: joinErr } = await supabase.from('thread_members').insert({
    thread_id: thread.id,
    user_id: user.id,
  });
  if (joinErr) throw new Error(`Failed to auto-join creator: ${joinErr.message}`);

  return {
    ...thread,
    tags: [],
    creator: undefined,
  };
}

// ─── Announcement / Cross-posting ──────────────────────────────────────────────

export async function publishMessage(messageId: string): Promise<void> {
  // Mark the message as published (add flag)
  const { error } = await supabase
    .from('message_flags')
    .upsert({ message_id: messageId, flag: 'crossposted' });
  if (error) throw new Error(`Failed to publish: ${error.message}`);
}

export async function followChannel(
  sourceChannelId: string,
  targetChannelId: string,
): Promise<void> {
  const { error } = await supabase
    .from('channel_follows')
    .insert({ source_channel_id: sourceChannelId, target_channel_id: targetChannelId });
  if (error && !error.message.includes('duplicate key'))
    throw new Error(`Failed to follow channel: ${error.message}`);
}

export async function unfollowChannel(
  sourceChannelId: string,
  targetChannelId: string,
): Promise<void> {
  const { error } = await supabase
    .from('channel_follows')
    .delete()
    .eq('source_channel_id', sourceChannelId)
    .eq('target_channel_id', targetChannelId);
  if (error) throw new Error(`Failed to unfollow channel: ${error.message}`);
}

export async function getChannelFollowers(channelId: string) {
  const { data, error } = await supabase
    .from('channel_follows')
    .select('*, target:channels!target_channel_id(id, name, server_id)')
    .eq('source_channel_id', channelId);
  if (error) throw new Error(`Failed to get followers: ${error.message}`);
  return data ?? [];
}

// ─── Slowmode ──────────────────────────────────────────────────────────────────

export const SLOWMODE_OPTIONS = [
  { label: 'Off', value: 0 },
  { label: '5s', value: 5 },
  { label: '10s', value: 10 },
  { label: '15s', value: 15 },
  { label: '30s', value: 30 },
  { label: '1m', value: 60 },
  { label: '2m', value: 120 },
  { label: '5m', value: 300 },
  { label: '10m', value: 600 },
  { label: '15m', value: 900 },
  { label: '30m', value: 1800 },
  { label: '1h', value: 3600 },
  { label: '2h', value: 7200 },
  { label: '6h', value: 21600 },
];

/**
 * Check if the user can currently send a message (respecting slowmode).
 * Returns seconds remaining, or 0 if OK.
 */
export async function getSlowmodeCooldown(
  channelId: string,
  userId: string,
  slowmodeSeconds: number,
): Promise<number> {
  if (slowmodeSeconds <= 0) return 0;

  const { data } = await supabase
    .from('slowmode_state')
    .select('last_message_at')
    .eq('channel_id', channelId)
    .eq('user_id', userId)
    .single();

  if (!data) return 0;

  const elapsed = (Date.now() - new Date(data.last_message_at).getTime()) / 1000;
  const remaining = slowmodeSeconds - elapsed;
  return remaining > 0 ? Math.ceil(remaining) : 0;
}

/**
 * Update last message timestamp for slowmode tracking.
 */
export async function updateSlowmodeState(channelId: string, userId: string): Promise<void> {
  const { error } = await supabase
    .from('slowmode_state')
    .upsert(
      { channel_id: channelId, user_id: userId, last_message_at: new Date().toISOString() },
      { onConflict: 'user_id,channel_id' },
    );
  if (error) throw new Error(`Failed to update slowmode state: ${error.message}`);
}
