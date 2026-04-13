# Privacy settings, DM policy, and friend requests

This document describes the **server-side** enforcement added in migration `099_user_privacy_dm_fr_enforcement.sql`, how the mobile app syncs settings, and what remains client-only.

## Data model

### Table: `public.user_privacy_settings`

One row per profile (`user_id` PK → `profiles.id`). Defaults match `DEFAULT_PRIVACY` in `shared/stores/settingsStore.ts`:

| Column | Default | Meaning |
|--------|---------|---------|
| `allow_dms_from_server_members` | `true` | If the user does not allow “everyone”, DMs are still allowed from people who share at least one server with them (when this is `true`). |
| `allow_dms_from_everyone` | `false` | If `true`, any non-blocked user can DM (subject to RLS). |
| `allow_friend_requests_from_everyone` | `true` | If `false`, incoming friend requests are only allowed from users who share a server. |
| `show_online_status` | `true` | If `false`, other users see `offline` / hidden presence via `get_privacy_masked_profile_fields`. |
| `show_current_activity` | `true` | If `false`, `custom_status` is hidden from others via the same RPC. |
| `read_receipts` | `true` | Stored for future use; **not enforced in Postgres yet** (no `message_reads` / receipts pipeline in this repo). |

Existing profiles are backfilled with default rows. New `profiles` rows get a privacy row from trigger `trg_profiles_ensure_privacy_settings`.

### Column: `profiles.online_status`

Migration `099` adds `profiles.online_status` if missing so mobile selects stay valid. Presence masking uses both `status` and `online_status` when present.

## RLS and helper functions

All helpers are `STABLE`, `SECURITY DEFINER`, `SET search_path = public`, and are granted to the `authenticated` role.

### `user_privacy_can_send_dm(sender_id, recipient_id)`

Returns `true` only when:

1. Sender and recipient are valid and different.
2. **No block** in either direction (`public.blocks`).
3. **Or** the pair has an **accepted** row in `public.friends` (either direction).
4. **Or** the recipient has `allow_dms_from_everyone = true`.
5. **Or** the recipient allows server DMs **and** sender and recipient share a `server_members` row (same `server_id`).

Otherwise returns `false`.

**Policy:** `direct_messages` INSERT uses:

`WITH CHECK (sender_id = auth.uid() AND user_privacy_can_send_dm(auth.uid(), recipient_id))`.

### `user_privacy_can_send_friend_request(sender_id, receiver_id)`

Returns `true` when:

1. Valid users, not blocked either way.
2. Receiver has `allow_friend_requests_from_everyone = true`, **or**
3. Sender and receiver share a server.

**Policy:** `friend_requests` INSERT uses:

`WITH CHECK (sender_id = auth.uid() AND user_privacy_can_send_friend_request(auth.uid(), receiver_id))`.

### `get_privacy_masked_profile_fields(p_ids uuid[])`

Returns `profile_id`, `status`, `online_status`, and `custom_status` for each id, applying the **viewing** user’s perspective via `auth.uid()`:

- For **your own** id, values are unchanged.
- For **others**, if `show_online_status` is false, status/online fields are forced to offline.
- If `show_current_activity` is false, `custom_status` is null for others.

Clients should call this RPC when displaying other users’ presence in lists (DMs, friends, profile) so privacy is honored even though raw `profiles` SELECT still returns full columns.

## Client responsibilities

| Area | Behavior |
|------|-----------|
| **Login / session** | `mobile/app/_layout.tsx` (`AuthGate`) loads `user_privacy_settings` and merges into `useSettingsStore` via `fetchUserPrivacySettings`. |
| **Privacy screen** | `mobile/app/settings/privacy.tsx` updates the store and **upserts** full preferences with `upsertUserPrivacySettings`. |
| **DM list / friends** | `fetchPrivacyMaskedProfileFields` + merge (see `dms.tsx`, `friends.tsx`). |
| **Profile (other user)** | `profile/[userId].tsx` masks the main profile query and mutual friends. |
| **Blocking** | Use `public.blocks` (`blocker_id`, `blocked_id`). The previous `blocked_users` reference was incorrect for this schema. |

## Read receipts

`read_receipts` is persisted and surfaced in the UI, but **there is no message-level read receipt storage or RLS** in the current migrations. Enforcement stays **client/UI** until a `read_at` (or similar) model and policies exist.

## Applying migrations

Run Supabase migrations as usual (e.g. `supabase db push` or your CI pipeline). After `099`, existing clients that only stored privacy in AsyncStorage should receive defaults from the backfill; users who change settings in the app will sync to the server.

## Related files

- `supabase/migrations/099_user_privacy_dm_fr_enforcement.sql` — schema, policies, RPCs.
- `shared/services/privacySettingsService.ts` — fetch, upsert, mask helpers.
- `shared/stores/settingsStore.ts` — `PrivacyPreferences` shape and defaults.
