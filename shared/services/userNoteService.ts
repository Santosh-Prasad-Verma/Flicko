/**
 * User Notes Service
 *
 * Private per-user notes about other users (stored locally or in Supabase).
 * Requirements: Feature 28 (User Notes)
 */
import { supabase } from '../lib/supabase';

export interface UserNote {
  owner_id: string;
  target_user_id: string;
  content: string;
  updated_at: string;
}

export async function getUserNote(
  ownerId: string,
  targetUserId: string,
): Promise<UserNote | null> {
  const { data, error } = await supabase
    .from('user_notes')
    .select('*')
    .eq('owner_id', ownerId)
    .eq('target_user_id', targetUserId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function setUserNote(
  ownerId: string,
  targetUserId: string,
  content: string,
) {
  if (!content.trim()) {
    // Delete note if empty
    const { error } = await supabase
      .from('user_notes')
      .delete()
      .eq('owner_id', ownerId)
      .eq('target_user_id', targetUserId);
    if (error) throw error;
    return;
  }

  const { error } = await supabase
    .from('user_notes')
    .upsert(
      {
        owner_id: ownerId,
        target_user_id: targetUserId,
        content: content.trim(),
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'owner_id,target_user_id' },
    );
  if (error) throw error;
}
