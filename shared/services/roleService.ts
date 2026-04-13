/**
 * Role Service
 *
 * Full CRUD for server roles + permission overrides.
 * Works with Supabase tables: roles, member_roles, permission_overwrites.
 */
import { supabase } from '../lib/supabase';
import { parsePermissions, permissionsToString, DEFAULT_EVERYONE_PERMISSIONS } from '../constants/permissions';
import type { PermissionOverride } from '../constants/permissions';

// ─── Types ─────────────────────────────────────────────────────────────────────

export interface Role {
  id: string;
  server_id: string;
  name: string;
  color: string | null;
  icon_url: string | null;
  hoist: boolean;
  mentionable: boolean;
  position: number;
  permissions: string; // stored as string for JSON safety (BigInt)
  is_everyone: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateRoleInput {
  serverId: string;
  name: string;
  color?: string | null;
  permissions?: bigint;
  hoist?: boolean;
  mentionable?: boolean;
}

export interface UpdateRoleInput {
  name?: string;
  color?: string | null;
  icon_url?: string | null;
  hoist?: boolean;
  mentionable?: boolean;
  permissions?: bigint;
  position?: number;
}

export interface MemberRole {
  role_id: string;
  user_id: string;
  server_id: string;
  assigned_at: string;
  role?: Role;
}

// ─── Role CRUD ─────────────────────────────────────────────────────────────────

/**
 * Fetch all roles for a server, ordered by position (highest first).
 */
export async function getServerRoles(serverId: string): Promise<Role[]> {
  const { data, error } = await supabase
    .from('roles')
    .select('*')
    .eq('server_id', serverId)
    .order('position', { ascending: false });

  if (error) throw new Error(`Failed to fetch roles: ${error.message}`);
  return (data ?? []).map(normalizeRole);
}

/**
 * Get a single role by ID.
 */
export async function getRole(roleId: string): Promise<Role> {
  const { data, error } = await supabase
    .from('roles')
    .select('*')
    .eq('id', roleId)
    .single();

  if (error) throw new Error(`Failed to fetch role: ${error.message}`);
  return normalizeRole(data);
}

/**
 * Create a new role (inserted at position 1, above @everyone).
 */
export async function createRole(input: CreateRoleInput): Promise<Role> {
  // Get current max position
  const { data: existing } = await supabase
    .from('roles')
    .select('position')
    .eq('server_id', input.serverId)
    .order('position', { ascending: false })
    .limit(1);

  const nextPosition = (existing?.[0]?.position ?? 0) + 1;

  const { data, error } = await supabase
    .from('roles')
    .insert({
      server_id: input.serverId,
      name: input.name,
      color: input.color ?? null,
      permissions: permissionsToString(input.permissions ?? 0n),
      hoist: input.hoist ?? false,
      mentionable: input.mentionable ?? false,
      position: nextPosition,
    })
    .select('*')
    .single();

  if (error) throw new Error(`Failed to create role: ${error.message}`);
  return normalizeRole(data);
}

/**
 * Update a role's properties.
 */
export async function updateRole(roleId: string, input: UpdateRoleInput): Promise<Role> {
  const updates: Record<string, any> = {};
  if (input.name !== undefined) updates.name = input.name;
  if (input.color !== undefined) updates.color = input.color;
  if (input.icon_url !== undefined) updates.icon_url = input.icon_url;
  if (input.hoist !== undefined) updates.hoist = input.hoist;
  if (input.mentionable !== undefined) updates.mentionable = input.mentionable;
  if (input.permissions !== undefined) updates.permissions = permissionsToString(input.permissions);
  if (input.position !== undefined) updates.position = input.position;

  const { data, error } = await supabase
    .from('roles')
    .update(updates)
    .eq('id', roleId)
    .select('*')
    .single();

  if (error) throw new Error(`Failed to update role: ${error.message}`);
  return normalizeRole(data);
}

/**
 * Delete a role. Cannot delete @everyone.
 */
export async function deleteRole(roleId: string): Promise<void> {
  const { error } = await supabase.from('roles').delete().eq('id', roleId);
  if (error) throw new Error(`Failed to delete role: ${error.message}`);
}

/**
 * Reorder roles (batch position update).
 */
export async function reorderRoles(
  serverId: string,
  order: { roleId: string; position: number }[],
): Promise<void> {
  // Update each role's position
  const updates = order.map(({ roleId, position }) =>
    supabase
      .from('roles')
      .update({ position })
      .eq('id', roleId)
      .eq('server_id', serverId),
  );

  const results = await Promise.all(updates);
  const failed = results.find((r: { error: any }) => r.error);
  if (failed?.error) throw new Error(`Failed to reorder roles: ${failed.error.message}`);
}

// ─── Member Roles ──────────────────────────────────────────────────────────────

/**
 * Get all role IDs for a member in a server.
 */
export async function getMemberRoles(
  serverId: string,
  userId: string,
): Promise<MemberRole[]> {
  const { data, error } = await supabase
    .from('member_roles')
    .select('*, role:roles(*)')
    .eq('server_id', serverId)
    .eq('user_id', userId);

  if (error) throw new Error(`Failed to fetch member roles: ${error.message}`);
  return data ?? [];
}

/**
 * Assign a role to a member.
 */
export async function assignRole(
  serverId: string,
  userId: string,
  roleId: string,
): Promise<void> {
  const { error } = await supabase.from('member_roles').insert({
    server_id: serverId,
    user_id: userId,
    role_id: roleId,
  });
  if (error && !error.message.includes('duplicate key'))
    throw new Error(`Failed to assign role: ${error.message}`);
}

/**
 * Remove a role from a member.
 */
export async function removeRoleFromMember(
  serverId: string,
  userId: string,
  roleId: string,
): Promise<void> {
  const { error } = await supabase
    .from('member_roles')
    .delete()
    .eq('server_id', serverId)
    .eq('user_id', userId)
    .eq('role_id', roleId);
  if (error) throw new Error(`Failed to remove role: ${error.message}`);
}

/**
 * Get members with a specific role.
 */
export async function getRoleMembers(
  serverId: string,
  roleId: string,
): Promise<{ user_id: string; username: string; display_name: string; avatar_url: string }[]> {
  const { data, error } = await supabase
    .from('member_roles')
    .select('user_id, user:profiles!user_id(username, display_name, avatar_url)')
    .eq('server_id', serverId)
    .eq('role_id', roleId);

  if (error) throw new Error(`Failed to fetch role members: ${error.message}`);
  return (data ?? []).map((d: any) => ({
    user_id: d.user_id,
    username: d.user?.username ?? '',
    display_name: d.user?.display_name ?? '',
    avatar_url: d.user?.avatar_url ?? '',
  }));
}

// ─── Permission Overrides ──────────────────────────────────────────────────────

/**
 * Get all permission overrides for a channel.
 */
export async function getChannelOverrides(channelId: string): Promise<PermissionOverride[]> {
  const { data, error } = await supabase
    .from('permission_overwrites')
    .select('*')
    .eq('channel_id', channelId);

  if (error) throw new Error(`Failed to fetch overrides: ${error.message}`);
  return (data ?? []).map((d: any) => ({
    target_id: d.target_id,
    target_type: d.target_type,
    allow: d.allow ?? '0',
    deny: d.deny ?? '0',
  }));
}

/**
 * Set a permission override for a channel (upsert).
 */
export async function setChannelOverride(
  channelId: string,
  targetId: string,
  targetType: 'role' | 'user',
  allow: bigint,
  deny: bigint,
): Promise<void> {
  const { error } = await supabase
    .from('permission_overwrites')
    .upsert(
      {
        channel_id: channelId,
        target_id: targetId,
        target_type: targetType,
        allow: permissionsToString(allow),
        deny: permissionsToString(deny),
      },
      { onConflict: 'channel_id,target_id,target_type' },
    );

  if (error) throw new Error(`Failed to set override: ${error.message}`);
}

/**
 * Delete a permission override.
 */
export async function deleteChannelOverride(
  channelId: string,
  targetId: string,
  targetType: 'role' | 'user',
): Promise<void> {
  const { error } = await supabase
    .from('permission_overwrites')
    .delete()
    .eq('channel_id', channelId)
    .eq('target_id', targetId)
    .eq('target_type', targetType);

  if (error) throw new Error(`Failed to delete override: ${error.message}`);
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

function normalizeRole(data: any): Role {
  return {
    ...data,
    permissions: String(data.permissions ?? '0'),
    is_everyone: data.name === '@everyone' || data.position === 0,
  };
}
