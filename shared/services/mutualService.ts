/**
 * Mutual Servers Service
 *
 * Find servers that two users share in common.
 * Requirements: Feature 29 (Mutual Servers / Mutual Friends)
 */
import { supabase } from '../lib/supabase';

export interface MutualServer {
  id: string;
  name: string;
  icon_url: string | null;
}

export interface MutualFriend {
  id: string;
  username: string;
  avatar_url: string | null;
  status?: string;
}

/**
 * Get servers both the current user and target user belong to.
 */
export async function getMutualServers(
  currentUserId: string,
  targetUserId: string,
): Promise<MutualServer[]> {
  // Get servers of current user
  const { data: myServers, error: e1 } = await supabase
    .from('server_members')
    .select('server_id')
    .eq('user_id', currentUserId);
  if (e1) throw e1;

  // Get servers of target user
  const { data: theirServers, error: e2 } = await supabase
    .from('server_members')
    .select('server_id')
    .eq('user_id', targetUserId);
  if (e2) throw e2;

  const myIds = new Set((myServers ?? []).map((s: any) => s.server_id));
  const mutualIds = (theirServers ?? [])
    .map((s: any) => s.server_id)
    .filter((id: string) => myIds.has(id));

  if (mutualIds.length === 0) return [];

  const { data, error } = await supabase
    .from('servers')
    .select('id, name, icon_url')
    .in('id', mutualIds);
  if (error) throw error;
  return data ?? [];
}

/**
 * Get mutual friends (users that both current user and target are friends with).
 */
export async function getMutualFriends(
  currentUserId: string,
  targetUserId: string,
): Promise<MutualFriend[]> {
  // Get friends of current user
  const { data: myFriends, error: e1 } = await supabase
    .from('friends')
    .select('friend_id')
    .eq('user_id', currentUserId)
    .eq('status', 'accepted');
  if (e1) throw e1;

  // Get friends of target user
  const { data: theirFriends, error: e2 } = await supabase
    .from('friends')
    .select('friend_id')
    .eq('user_id', targetUserId)
    .eq('status', 'accepted');
  if (e2) throw e2;

  const myIds = new Set((myFriends ?? []).map((f: any) => f.friend_id));
  const mutualIds = (theirFriends ?? [])
    .map((f: any) => f.friend_id)
    .filter((id: string) => myIds.has(id));

  if (mutualIds.length === 0) return [];

  const { data, error } = await supabase
    .from('profiles')
    .select('id, username, avatar_url, status')
    .in('id', mutualIds);
  if (error) throw error;
  return data ?? [];
}
