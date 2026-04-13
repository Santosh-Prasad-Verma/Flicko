/**
 * Group DM Service
 *
 * CRUD for group DM conversations.
 * Requirements: Feature 14 (Group DMs)
 */
import { supabase } from '../lib/supabase';

export interface GroupDM {
  id: string;
  name: string | null;
  icon_url: string | null;
  owner_id: string;
  created_at: string;
  updated_at: string;
  participants?: {
    user_id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
  }[];
  last_message?: {
    content: string;
    created_at: string;
    author_username: string;
  };
}

export async function getGroupDMs(userId: string): Promise<GroupDM[]> {
  const { data, error } = await supabase
    .from('group_dm_members')
    .select(`
      group_dm:group_dms!group_dm_id(
        id, name, icon_url, owner_id, created_at, updated_at
      )
    `)
    .eq('user_id', userId);
  if (error) throw error;

  const groups = (data ?? []).map((d: any) => d.group_dm).filter(Boolean);

  // Fetch participants for each group
  if (groups.length === 0) return [];
  const groupIds = groups.map((g: any) => g.id);

  const { data: members } = await supabase
    .from('group_dm_members')
    .select('group_dm_id, user:profiles!user_id(id, username, display_name, avatar_url)')
    .in('group_dm_id', groupIds);

  const memberMap = new Map<string, any[]>();
  for (const m of members ?? []) {
    const list = memberMap.get(m.group_dm_id) ?? [];
    list.push({ user_id: (m as any).user?.id, ...(m as any).user });
    memberMap.set(m.group_dm_id, list);
  }

  return groups.map((g: any) => ({
    ...g,
    participants: memberMap.get(g.id) ?? [],
  }));
}

export async function createGroupDM(
  ownerId: string,
  participantIds: string[],
  name?: string,
): Promise<GroupDM> {
  const allIds = [ownerId, ...participantIds.filter((id) => id !== ownerId)];
  if (allIds.length < 2) throw new Error('Need at least 2 participants');
  if (allIds.length > 10) throw new Error('Maximum 10 participants in a group DM');

  const { data: group, error } = await supabase
    .from('group_dms')
    .insert({ name: name || null, owner_id: ownerId })
    .select('*')
    .single();
  if (error) throw error;

  // Add all participants
  const memberInserts = allIds.map((uid) => ({ group_dm_id: group.id, user_id: uid }));
  const { error: memberError } = await supabase.from('group_dm_members').insert(memberInserts);
  if (memberError) throw memberError;

  return group;
}

export async function addGroupDMMember(groupDmId: string, userId: string) {
  // Check participant count
  const { count } = await supabase
    .from('group_dm_members')
    .select('*', { count: 'exact', head: true })
    .eq('group_dm_id', groupDmId);
  if ((count ?? 0) >= 10) throw new Error('Maximum 10 participants');

  const { error } = await supabase
    .from('group_dm_members')
    .insert({ group_dm_id: groupDmId, user_id: userId });
  if (error) throw error;
}

export async function removeGroupDMMember(groupDmId: string, userId: string) {
  const { error } = await supabase
    .from('group_dm_members')
    .delete()
    .eq('group_dm_id', groupDmId)
    .eq('user_id', userId);
  if (error) throw error;
}

export async function renameGroupDM(groupDmId: string, name: string | null) {
  const { error } = await supabase
    .from('group_dms')
    .update({ name, updated_at: new Date().toISOString() })
    .eq('id', groupDmId);
  if (error) throw error;
}

export async function deleteGroupDM(groupDmId: string) {
  const { error: membersErr } = await supabase.from('group_dm_members').delete().eq('group_dm_id', groupDmId);
  if (membersErr) throw new Error(`Failed to remove group members: ${membersErr.message}`);
  const { error } = await supabase.from('group_dms').delete().eq('id', groupDmId);
  if (error) throw new Error(`Failed to delete group DM: ${error.message}`);
}
