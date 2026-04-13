/**
 * Server Template Service
 *
 * Create and apply server templates (channel + role structure snapshots).
 * Requirements: Feature 23 (Server Templates)
 */
import { supabase } from '../lib/supabase';

export interface ServerTemplate {
  id: string;
  name: string;
  description: string | null;
  source_server_id: string;
  creator_id: string;
  usage_count: number;
  serialized_data: {
    channels: { name: string; type: string; position: number; parent_name?: string }[];
    roles: { name: string; permissions: string; color: string | null; hoist: boolean }[];
  };
  created_at: string;
  updated_at: string;
}

export interface CreateTemplateInput {
  name: string;
  description?: string;
}

// ─── CRUD ──────────────────────────────────────────────────────────────────────

export async function getServerTemplates(serverId: string): Promise<ServerTemplate[]> {
  const { data, error } = await supabase
    .from('server_templates')
    .select('*')
    .eq('source_server_id', serverId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function getPublicTemplates(): Promise<ServerTemplate[]> {
  const { data, error } = await supabase
    .from('server_templates')
    .select('*')
    .order('usage_count', { ascending: false })
    .limit(50);
  if (error) throw error;
  return data ?? [];
}

export async function createTemplate(
  serverId: string,
  userId: string,
  input: CreateTemplateInput,
): Promise<ServerTemplate> {
  // Snapshot current server structure
  const [channelsRes, rolesRes] = await Promise.all([
    supabase.from('channels').select('name, type, position, parent_id').eq('server_id', serverId).order('position'),
    supabase.from('roles').select('name, permissions, color, hoist').eq('server_id', serverId).order('position'),
  ]);
  if (channelsRes.error) throw channelsRes.error;
  if (rolesRes.error) throw rolesRes.error;

  const { data, error } = await supabase
    .from('server_templates')
    .insert({
      name: input.name,
      description: input.description ?? null,
      source_server_id: serverId,
      creator_id: userId,
      serialized_data: {
        channels: (channelsRes.data ?? []).map((ch: any) => ({
          name: ch.name,
          type: ch.type,
          position: ch.position,
        })),
        roles: (rolesRes.data ?? []).map((r: any) => ({
          name: r.name,
          permissions: r.permissions,
          color: r.color,
          hoist: r.hoist,
        })),
      },
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteTemplate(templateId: string) {
  const { error } = await supabase
    .from('server_templates')
    .delete()
    .eq('id', templateId);
  if (error) throw error;
}
