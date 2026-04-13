import { supabase } from '../lib/supabase';
import type { PrivacyPreferences } from '../stores/settingsStore';

export type UserPrivacyRow = {
  allow_dms_from_server_members: boolean;
  allow_dms_from_everyone: boolean;
  allow_friend_requests_from_everyone: boolean;
  show_online_status: boolean;
  show_current_activity: boolean;
  read_receipts: boolean;
};

function rowToPreferences(row: UserPrivacyRow): PrivacyPreferences {
  return {
    allowDmsFromServerMembers: row.allow_dms_from_server_members,
    allowDmsFromEveryone: row.allow_dms_from_everyone,
    allowFriendRequestsFromEveryone: row.allow_friend_requests_from_everyone,
    showOnlineStatus: row.show_online_status,
    showCurrentActivity: row.show_current_activity,
    readReceipts: row.read_receipts,
  };
}

/**
 * Load privacy toggles for the signed-in user (RLS: own row only).
 */
export async function fetchUserPrivacySettings(userId: string): Promise<PrivacyPreferences | null> {
  const { data, error } = await supabase
    .from('user_privacy_settings')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) {
    console.warn('[privacySettingsService] fetch failed:', error.message);
    return null;
  }
  if (!data) return null;
  return rowToPreferences(data as UserPrivacyRow);
}

/**
 * Upsert full privacy state (server enforces DM / friend-request policies using this row).
 */
export async function upsertUserPrivacySettings(
  userId: string,
  prefs: PrivacyPreferences
): Promise<void> {
  const { error } = await supabase.from('user_privacy_settings').upsert(
    {
      user_id: userId,
      allow_dms_from_server_members: prefs.allowDmsFromServerMembers,
      allow_dms_from_everyone: prefs.allowDmsFromEveryone,
      allow_friend_requests_from_everyone: prefs.allowFriendRequestsFromEveryone,
      show_online_status: prefs.showOnlineStatus,
      show_current_activity: prefs.showCurrentActivity,
      read_receipts: prefs.readReceipts,
    },
    { onConflict: 'user_id' }
  );

  if (error) throw new Error(error.message);
}

export type MaskedProfileFields = {
  profile_id: string;
  status: string | null;
  online_status: string | null;
  custom_status: string | null;
};

/**
 * Returns presence / activity fields respecting each user's privacy relative to auth.uid().
 */
export async function fetchPrivacyMaskedProfileFields(
  profileIds: string[]
): Promise<Map<string, MaskedProfileFields>> {
  const unique = [...new Set(profileIds.filter(Boolean))];
  const out = new Map<string, MaskedProfileFields>();
  if (unique.length === 0) return out;

  const { data, error } = await supabase.rpc('get_privacy_masked_profile_fields', {
    p_ids: unique,
  });

  if (error) {
    console.warn('[privacySettingsService] mask RPC failed:', error.message);
    return out;
  }

  for (const row of (data ?? []) as MaskedProfileFields[]) {
    if (row?.profile_id) out.set(row.profile_id, row);
  }
  return out;
}

/** Merge masked presence fields onto a nested profile object from a select/join. */
export function applyMaskToProfileObject(
  profile: Record<string, unknown> | null | undefined,
  mask: Map<string, MaskedProfileFields>
): Record<string, unknown> | null | undefined {
  if (!profile || typeof profile !== 'object') return profile;
  const id = profile.id as string | undefined;
  if (!id) return profile;
  const m = mask.get(id);
  if (!m) return profile;
  return {
    ...profile,
    status: m.status ?? profile.status,
    online_status: m.online_status ?? profile.online_status,
    custom_status: m.custom_status !== undefined ? m.custom_status : profile.custom_status,
  };
}
