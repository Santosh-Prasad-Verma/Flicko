-- 131: Defensive fixes for voice channel join failure and privacy SQL functions.
--
-- Problem 1: voice_states.session_id is NOT NULL with no default. Any code path
-- that upserts without an explicit session_id triggers Postgres error 23502.
-- We give it a uuid default so the column is self-healing while still unique.
--
-- Problem 2: Migration 099 (privacy enforcement) was authored with single
-- dollar-quote markers ($) instead of $$ on several functions. Depending on
-- when it ran, the functions may exist with empty/broken bodies, which then
-- silently rejects every direct_message INSERT and friend_request INSERT.
-- This migration re-creates them with the correct body and is idempotent.

-- ── 1. voice_states.session_id default + safe upsert ────────────────────────

ALTER TABLE public.voice_states
  ALTER COLUMN session_id SET DEFAULT gen_random_uuid()::text;

-- Backfill any rows that somehow ended up with NULL (shouldn't happen with the
-- NOT NULL constraint, but harmless if we have to repair after a partial fail).
UPDATE public.voice_states
SET session_id = gen_random_uuid()::text
WHERE session_id IS NULL;

-- ── 2. Privacy functions — re-create with proper bodies ─────────────────────

CREATE OR REPLACE FUNCTION public.user_privacy_can_send_dm(p_sender uuid, p_recipient uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_sender IS NULL OR p_recipient IS NULL OR p_sender = p_recipient THEN false
    WHEN EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p_sender AND b.blocked_id = p_recipient)
         OR (b.blocker_id = p_recipient AND b.blocked_id = p_sender)
    ) THEN false
    WHEN EXISTS (
      SELECT 1 FROM public.friends f
      WHERE f.status = 'accepted'
        AND (
          (f.user_id = p_sender AND f.friend_id = p_recipient)
          OR (f.user_id = p_recipient AND f.friend_id = p_sender)
        )
    ) THEN true
    WHEN COALESCE(ups.allow_dms_from_everyone, false) THEN true
    WHEN COALESCE(ups.allow_dms_from_server_members, true)
      AND EXISTS (
        SELECT 1
        FROM public.server_members sm1
        INNER JOIN public.server_members sm2 ON sm1.server_id = sm2.server_id
        WHERE sm1.user_id = p_sender AND sm2.user_id = p_recipient
      ) THEN true
    ELSE false
  END
  FROM (SELECT 1) AS _
  LEFT JOIN public.user_privacy_settings ups ON ups.user_id = p_recipient;
$$;

CREATE OR REPLACE FUNCTION public.user_privacy_can_send_friend_request(p_sender uuid, p_receiver uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_sender IS NULL OR p_receiver IS NULL OR p_sender = p_receiver THEN false
    WHEN EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p_sender AND b.blocked_id = p_receiver)
         OR (b.blocker_id = p_receiver AND b.blocked_id = p_sender)
    ) THEN false
    WHEN COALESCE(ups.allow_friend_requests_from_everyone, true) THEN true
    WHEN EXISTS (
      SELECT 1
      FROM public.server_members sm1
      INNER JOIN public.server_members sm2 ON sm1.server_id = sm2.server_id
      WHERE sm1.user_id = p_sender AND sm2.user_id = p_receiver
    ) THEN true
    ELSE false
  END
  FROM (SELECT 1) AS _
  LEFT JOIN public.user_privacy_settings ups ON ups.user_id = p_receiver;
$$;

CREATE OR REPLACE FUNCTION public.touch_user_privacy_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_user_privacy_settings_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_privacy_settings (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_privacy_masked_profile_fields(p_ids uuid[])
RETURNS TABLE (
  profile_id uuid,
  status text,
  online_status text,
  custom_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    CASE
      WHEN p.id = auth.uid() THEN p.status::text
      WHEN NOT COALESCE(ups.show_online_status, true) THEN 'offline'
      ELSE p.status::text
    END AS status,
    CASE
      WHEN p.id = auth.uid() THEN COALESCE(p.online_status::text, p.status::text, 'offline')
      WHEN NOT COALESCE(ups.show_online_status, true) THEN 'offline'
      ELSE COALESCE(p.online_status::text, p.status::text, 'offline')
    END AS online_status,
    CASE
      WHEN p.id = auth.uid() THEN p.custom_status
      WHEN NOT COALESCE(ups.show_current_activity, true) THEN NULL
      ELSE p.custom_status
    END AS custom_status
  FROM public.profiles p
  LEFT JOIN public.user_privacy_settings ups ON ups.user_id = p.id
  WHERE p.id = ANY(p_ids);
$$;

GRANT EXECUTE ON FUNCTION public.user_privacy_can_send_dm(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_privacy_can_send_friend_request(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_privacy_masked_profile_fields(uuid[]) TO authenticated;

-- Re-assert the policies in case they were dropped in a botched run.
DROP POLICY IF EXISTS "Users can send DMs subject to privacy" ON public.direct_messages;
CREATE POLICY "Users can send DMs subject to privacy"
  ON public.direct_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.user_privacy_can_send_dm(auth.uid(), recipient_id)
  );

DROP POLICY IF EXISTS "Send friend request subject to privacy" ON public.friend_requests;
CREATE POLICY "Send friend request subject to privacy"
  ON public.friend_requests FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.user_privacy_can_send_friend_request(auth.uid(), receiver_id)
  );
