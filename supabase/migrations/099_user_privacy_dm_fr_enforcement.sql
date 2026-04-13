-- 099: Server-side enforcement for user privacy (DM policy, friend requests, presence masking RPC).
-- Defaults match shared/stores/settingsStore.ts DEFAULT_PRIVACY.

-- ---------------------------------------------------------------------------
-- 1. Privacy settings (one row per profile)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_privacy_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  allow_dms_from_server_members BOOLEAN NOT NULL DEFAULT true,
  allow_dms_from_everyone BOOLEAN NOT NULL DEFAULT false,
  allow_friend_requests_from_everyone BOOLEAN NOT NULL DEFAULT true,
  show_online_status BOOLEAN NOT NULL DEFAULT true,
  show_current_activity BOOLEAN NOT NULL DEFAULT true,
  read_receipts BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_privacy_settings_updated_at
  ON public.user_privacy_settings(updated_at DESC);

COMMENT ON TABLE public.user_privacy_settings IS
  'Per-user privacy toggles; enforced for DM INSERT, friend_requests INSERT, and optional presence RPC.';

-- Backfill for existing profiles (idempotent)
INSERT INTO public.user_privacy_settings (user_id)
SELECT id FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;

-- Keep updated_at fresh
CREATE OR REPLACE FUNCTION public.touch_user_privacy_settings()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_privacy_settings_touch ON public.user_privacy_settings;
CREATE TRIGGER trg_user_privacy_settings_touch
  BEFORE UPDATE ON public.user_privacy_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_user_privacy_settings();

-- Auto-create row for new profiles
CREATE OR REPLACE FUNCTION public.ensure_user_privacy_settings_row()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_privacy_settings (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

DROP TRIGGER IF EXISTS trg_profiles_ensure_privacy_settings ON public.profiles;
CREATE TRIGGER trg_profiles_ensure_privacy_settings
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_user_privacy_settings_row();

ALTER TABLE public.user_privacy_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own privacy settings" ON public.user_privacy_settings;
CREATE POLICY "Users read own privacy settings"
  ON public.user_privacy_settings FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users insert own privacy settings" ON public.user_privacy_settings;
CREATE POLICY "Users insert own privacy settings"
  ON public.user_privacy_settings FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users update own privacy settings" ON public.user_privacy_settings;
CREATE POLICY "Users update own privacy settings"
  ON public.user_privacy_settings FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Ensure profiles.online_status exists (mobile selects this alongside status)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS online_status TEXT DEFAULT 'offline';

-- ---------------------------------------------------------------------------
-- 3. SECURITY DEFINER helpers (bypass RLS on joined tables; fixed search_path)
-- ---------------------------------------------------------------------------

-- DM: blocks, mutual accepted friends, then recipient privacy + shared servers.
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

-- Friend requests: blocks, then receiver privacy or shared server membership.
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

GRANT EXECUTE ON FUNCTION public.user_privacy_can_send_dm(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_privacy_can_send_friend_request(uuid, uuid) TO authenticated;

-- Batch presence / activity masking for other users (viewer = auth.uid()).
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

GRANT EXECUTE ON FUNCTION public.get_privacy_masked_profile_fields(uuid[]) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Replace permissive INSERT policies
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can send DMs" ON public.direct_messages;
CREATE POLICY "Users can send DMs subject to privacy"
  ON public.direct_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.user_privacy_can_send_dm(auth.uid(), recipient_id)
  );

DROP POLICY IF EXISTS "Send friend request" ON public.friend_requests;
CREATE POLICY "Send friend request subject to privacy"
  ON public.friend_requests FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND public.user_privacy_can_send_friend_request(auth.uid(), receiver_id)
  );
