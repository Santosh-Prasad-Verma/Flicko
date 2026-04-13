/**
 * Webhook Service
 *
 * Manage webhooks for server channels.
 * Requirements: Feature 22 (Webhooks)
 */
import { supabase } from '../lib/supabase';

export interface Webhook {
  id: string;
  server_id: string;
  channel_id: string;
  name: string;
  avatar_url: string | null;
  token: string;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface CreateWebhookInput {
  channel_id: string;
  name: string;
  avatar_url?: string | null;
}

// ─── CRUD ──────────────────────────────────────────────────────────────────────

export async function getServerWebhooks(serverId: string): Promise<Webhook[]> {
  const { data, error } = await supabase
    .from('webhooks')
    .select('*')
    .eq('server_id', serverId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function getChannelWebhooks(channelId: string): Promise<Webhook[]> {
  const { data, error } = await supabase
    .from('webhooks')
    .select('*')
    .eq('channel_id', channelId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function createWebhook(
  serverId: string,
  userId: string,
  input: CreateWebhookInput,
): Promise<Webhook> {
  const { data, error } = await supabase
    .from('webhooks')
    .insert({
      server_id: serverId,
      channel_id: input.channel_id,
      name: input.name,
      avatar_url: input.avatar_url ?? null,
      created_by: userId,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function updateWebhook(
  webhookId: string,
  updates: Partial<Pick<Webhook, 'name' | 'avatar_url' | 'channel_id'>>,
): Promise<Webhook> {
  const { data, error } = await supabase
    .from('webhooks')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', webhookId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteWebhook(webhookId: string) {
  const { error } = await supabase
    .from('webhooks')
    .delete()
    .eq('id', webhookId);
  if (error) throw error;
}

/**
 * Get the full webhook URL for external integrations.
 */
export function getWebhookUrl(webhook: Webhook, baseUrl: string): string {
  return `${baseUrl}/api/webhooks/${webhook.id}/${webhook.token}`;
}
