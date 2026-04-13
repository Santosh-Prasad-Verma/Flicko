/**
 * Member Management Service
 *
 * Handles server member operations: list, search, timeout, kick, ban, nickname.
 * Requirements: Feature 17 (Member Management)
 */
import { supabase } from '../lib/supabase';
import { notifyMemberLeave } from './botService';

// ─── Types ─────────────────────────────────────────────────────────────────────

export interface ServerMember {
  id: string;
  server_id: string;
  user_id: string;
  nickname: string | null;
  timeout_until: string | null;
  joined_at: string;
  user?: {
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
    status?: string;
  };
  roles?: { id: string; name: string; color: string; position: number }[];
}

export interface BannedMember {
  id: string;
  server_id: string;
  user_id: string;
  reason: string | null;
  banned_by: string;
  created_at: string;
  user?: {
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
  };
}

export interface ServerInvite {
  id: string;
  server_id: string;
  code: string;
  created_by: string;
  max_uses: number | null;
  uses: number;
  expires_at: string | null;
  created_at: string;
  creator?: {
    username: string;
    display_name?: string;
  };
}

// ─── Member List ───────────────────────────────────────────────────────────────

export async function getServerMembers(
  serverId: string,
  options?: { search?: string; limit?: number; after?: string },
): Promise<ServerMember[]> {
  let query = supabase
    .from('server_members')
    .select(`
      *,
      user:profiles!user_id(id, username, display_name, avatar_url, status)
    `)
    .eq('server_id', serverId)
    .order('joined_at', { ascending: true });

  if (options?.search) {
    // Search by username or nickname
    query = query.or(
      `nickname.ilike.%${options.search}%,user.username.ilike.%${options.search}%`,
    );
  }
  // Cursor-based pagination: fetch members joined after the cursor timestamp
  if (options?.after) {
    query = query.gt('joined_at', options.after);
  }
  if (options?.limit) query = query.limit(options.limit);

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}

export async function getMemberWithRoles(serverId: string, userId: string): Promise<ServerMember | null> {
  // MED-024: Single query with nested join — replaces two-query member+roles fetch
  const { data: member, error } = await supabase
    .from('server_members')
    .select(`
      *,
      user:profiles!user_id(id, username, display_name, avatar_url, status),
      member_roles(role:roles!role_id(id, name, color, position))
    `)
    .eq('server_id', serverId)
    .eq('user_id', userId)
    .single();
  if (error) throw error;

  return {
    ...member,
    member_roles: undefined, // Remove the join artifact
    roles: ((member as any).member_roles ?? [])
      .map((mr: any) => mr.role)
      .filter(Boolean)
      .sort((a: any, b: any) => b.position - a.position),
  };
}

// ─── Nickname ──────────────────────────────────────────────────────────────────

export async function setNickname(serverId: string, userId: string, nickname: string | null) {
  const { error } = await supabase
    .from('server_members')
    .update({ nickname })
    .eq('server_id', serverId)
    .eq('user_id', userId);
  if (error) throw error;
}

// ─── Timeout ───────────────────────────────────────────────────────────────────

export const TIMEOUT_DURATIONS = [
  { label: '60 seconds', seconds: 60 },
  { label: '5 minutes', seconds: 300 },
  { label: '10 minutes', seconds: 600 },
  { label: '1 hour', seconds: 3600 },
  { label: '1 day', seconds: 86400 },
  { label: '1 week', seconds: 604800 },
] as const;

export async function timeoutMember(serverId: string, userId: string, durationSeconds: number) {
  const timeoutUntil = new Date(Date.now() + durationSeconds * 1000).toISOString();
  const { error } = await supabase
    .from('server_members')
    .update({ timeout_until: timeoutUntil })
    .eq('server_id', serverId)
    .eq('user_id', userId);
  if (error) throw error;
}

export async function removeTimeout(serverId: string, userId: string) {
  const { error } = await supabase
    .from('server_members')
    .update({ timeout_until: null })
    .eq('server_id', serverId)
    .eq('user_id', userId);
  if (error) throw error;
}

// ─── Kick ──────────────────────────────────────────────────────────────────────

export async function kickMember(serverId: string, userId: string) {
  // Notify backend bots (welcome goodbye)
  await notifyMemberLeave(serverId);

  const { error } = await supabase
    .from('server_members')
    .delete()
    .eq('server_id', serverId)
    .eq('user_id', userId);
  if (error) throw error;

  // Also remove member roles
  await supabase
    .from('member_roles')
    .delete()
    .eq('server_id', serverId)
    .eq('user_id', userId);
}

// ─── Ban ───────────────────────────────────────────────────────────────────────

export async function banMember(
  serverId: string,
  userId: string,
  bannedBy: string,
  reason?: string,
) {
  // Add to bans
  const { error: banError } = await supabase.from('bans').insert({
    server_id: serverId,
    user_id: userId,
    banned_by: bannedBy,
    reason: reason || null,
  });
  if (banError) throw banError;

  // Remove from server
  await kickMember(serverId, userId);
}

export async function unbanMember(serverId: string, userId: string) {
  const { error } = await supabase
    .from('bans')
    .delete()
    .eq('server_id', serverId)
    .eq('user_id', userId);
  if (error) throw error;
}

export async function getServerBans(serverId: string): Promise<BannedMember[]> {
  const { data, error } = await supabase
    .from('bans')
    .select(`
      *,
      user:profiles!user_id(id, username, display_name, avatar_url)
    `)
    .eq('server_id', serverId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

// ─── Invites ───────────────────────────────────────────────────────────────────

export async function getServerInvites(serverId: string): Promise<ServerInvite[]> {
  const { data, error } = await supabase
    .from('invites')
    .select(`
      *,
      creator:profiles!created_by(username, display_name)
    `)
    .eq('server_id', serverId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function createInvite(
  serverId: string,
  createdBy: string,
  options?: { maxUses?: number; expiresIn?: number },
): Promise<ServerInvite> {
  const code = generateInviteCode();
  const expiresAt = options?.expiresIn
    ? new Date(Date.now() + options.expiresIn * 1000).toISOString()
    : null;

  const { data, error } = await supabase
    .from('invites')
    .insert({
      server_id: serverId,
      code,
      created_by: createdBy,
      max_uses: options?.maxUses ?? null,
      expires_at: expiresAt,
    })
    .select('*')
    .single();
  if (error) throw error;
  return data;
}

export async function deleteInvite(inviteId: string) {
  const { error } = await supabase.from('invites').delete().eq('id', inviteId);
  if (error) throw error;
}

function generateInviteCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// ─── Transfer Ownership ────────────────────────────────────────────────────────

export async function transferOwnership(serverId: string, newOwnerId: string) {
  const { error } = await supabase
    .from('servers')
    .update({ owner_id: newOwnerId })
    .eq('id', serverId);
  if (error) throw error;
}
