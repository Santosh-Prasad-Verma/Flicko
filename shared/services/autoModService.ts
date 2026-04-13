/**
 * AutoMod Service
 *
 * Manage auto-moderation rules for a server.
 * Requirements: Feature 21 (AutoMod)
 */
import { supabase } from '../lib/supabase';

export type AutoModTriggerType =
  | 'keyword'
  | 'spam'
  | 'mention_spam'
  | 'link'
  | 'invite_link'
  | 'caps';

export type AutoModActionType =
  | 'block_message'
  | 'send_alert'
  | 'timeout'
  | 'delete_message';

export interface AutoModRule {
  id: string;
  server_id: string;
  name: string;
  enabled: boolean;
  trigger_type: AutoModTriggerType;
  trigger_metadata: {
    keyword_filter?: string[];
    regex_patterns?: string[];
    allow_list?: string[];
    mention_limit?: number;
  };
  actions: {
    type: AutoModActionType;
    metadata?: {
      channel_id?: string;         // for send_alert
      timeout_duration?: number;   // seconds
    };
  }[];
  exempt_roles: string[];
  exempt_channels: string[];
  created_at: string;
  updated_at: string;
}

export interface CreateAutoModRuleInput {
  name: string;
  trigger_type: AutoModTriggerType;
  trigger_metadata?: AutoModRule['trigger_metadata'];
  actions: AutoModRule['actions'];
  exempt_roles?: string[];
  exempt_channels?: string[];
  enabled?: boolean;
}

// ─── CRUD ──────────────────────────────────────────────────────────────────────

export async function getAutoModRules(serverId: string): Promise<AutoModRule[]> {
  const { data, error } = await supabase
    .from('automod_rules')
    .select('*')
    .eq('server_id', serverId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function getAutoModRule(ruleId: string): Promise<AutoModRule> {
  const { data, error } = await supabase
    .from('automod_rules')
    .select('*')
    .eq('id', ruleId)
    .single();
  if (error) throw error;
  return data;
}

export async function createAutoModRule(
  serverId: string,
  input: CreateAutoModRuleInput,
): Promise<AutoModRule> {
  const { data, error } = await supabase
    .from('automod_rules')
    .insert({
      server_id: serverId,
      ...input,
      enabled: input.enabled ?? true,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function updateAutoModRule(
  ruleId: string,
  updates: Partial<Omit<AutoModRule, 'id' | 'server_id' | 'created_at'>>,
): Promise<AutoModRule> {
  const { data, error } = await supabase
    .from('automod_rules')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', ruleId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteAutoModRule(ruleId: string) {
  const { error } = await supabase
    .from('automod_rules')
    .delete()
    .eq('id', ruleId);
  if (error) throw error;
}

export async function toggleAutoModRule(ruleId: string, enabled: boolean) {
  return updateAutoModRule(ruleId, { enabled });
}

// ─── Presets ───────────────────────────────────────────────────────────────────

export const AUTOMOD_PRESETS: { name: string; trigger_type: AutoModTriggerType; description: string }[] = [
  { name: 'Block Bad Words', trigger_type: 'keyword', description: 'Block messages containing specific keywords' },
  { name: 'Anti-Spam', trigger_type: 'spam', description: 'Block rapid duplicate messages' },
  { name: 'Mention Limit', trigger_type: 'mention_spam', description: 'Limit excessive @mentions per message' },
  { name: 'Block Links', trigger_type: 'link', description: 'Block messages containing URLs' },
  { name: 'Block Invite Links', trigger_type: 'invite_link', description: 'Block Discord/server invite links' },
  { name: 'Caps Filter', trigger_type: 'caps', description: 'Block messages with excessive caps' },
];
