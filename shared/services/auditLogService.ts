/**
 * Audit Log Service
 *
 * Read-only view of server audit log entries.
 * Requirements: Feature 25 (Audit Log)
 */
import { supabase } from '../lib/supabase';

export type AuditLogAction =
  | 'server_update'
  | 'channel_create'
  | 'channel_update'
  | 'channel_delete'
  | 'role_create'
  | 'role_update'
  | 'role_delete'
  | 'member_kick'
  | 'member_ban'
  | 'member_unban'
  | 'member_role_update'
  | 'message_delete'
  | 'message_pin'
  | 'message_unpin'
  | 'invite_create'
  | 'invite_delete'
  | 'webhook_create'
  | 'webhook_update'
  | 'webhook_delete'
  | 'emoji_create'
  | 'emoji_delete'
  | 'automod_rule_create'
  | 'automod_rule_update'
  | 'automod_rule_delete';

export interface AuditLogEntry {
  id: string;
  server_id: string;
  user_id: string;
  action: AuditLogAction;
  target_id: string | null;
  target_type: string | null;
  changes: Record<string, { old: any; new: any }> | null;
  reason: string | null;
  created_at: string;
  // Joined
  user?: { id: string; username: string; avatar_url: string | null };
}

export interface AuditLogFilter {
  action?: AuditLogAction;
  userId?: string;
  before?: string;
  limit?: number;
}

export async function getAuditLog(
  serverId: string,
  filter?: AuditLogFilter,
): Promise<AuditLogEntry[]> {
  let query = supabase
    .from('audit_log')
    .select('*, user:profiles!user_id(id, username, avatar_url)')
    .eq('server_id', serverId)
    .order('created_at', { ascending: false })
    .limit(filter?.limit ?? 50);

  if (filter?.action) query = query.eq('action', filter.action);
  if (filter?.userId) query = query.eq('user_id', filter.userId);
  if (filter?.before) query = query.lt('created_at', filter.before);

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}

export const AUDIT_ACTION_LABELS: Record<AuditLogAction, string> = {
  server_update: 'Server Updated',
  channel_create: 'Channel Created',
  channel_update: 'Channel Updated',
  channel_delete: 'Channel Deleted',
  role_create: 'Role Created',
  role_update: 'Role Updated',
  role_delete: 'Role Deleted',
  member_kick: 'Member Kicked',
  member_ban: 'Member Banned',
  member_unban: 'Member Unbanned',
  member_role_update: 'Member Roles Updated',
  message_delete: 'Message Deleted',
  message_pin: 'Message Pinned',
  message_unpin: 'Message Unpinned',
  invite_create: 'Invite Created',
  invite_delete: 'Invite Deleted',
  webhook_create: 'Webhook Created',
  webhook_update: 'Webhook Updated',
  webhook_delete: 'Webhook Deleted',
  emoji_create: 'Emoji Created',
  emoji_delete: 'Emoji Deleted',
  automod_rule_create: 'AutoMod Rule Created',
  automod_rule_update: 'AutoMod Rule Updated',
  automod_rule_delete: 'AutoMod Rule Deleted',
};
