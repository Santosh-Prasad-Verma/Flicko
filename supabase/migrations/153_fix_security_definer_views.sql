-- Migration 153: Fix Security Definer Views by adding WITH (security_invoker = true)
-- Both views are recreated with the invoker security model to enforce RLS correctly.

-- 1. Recreate users view
CREATE OR REPLACE VIEW public.users WITH (security_invoker = true) AS
SELECT
  id,
  username,
  email,
  display_name,
  avatar      AS avatar_url,
  banner      AS banner_url,
  bio,
  status,
  custom_status,
  created_at,
  updated_at
FROM public.profiles;

-- 2. Recreate e2ee_latest_signed_prekey view
CREATE OR REPLACE VIEW public.e2ee_latest_signed_prekey WITH (security_invoker = true) AS
SELECT DISTINCT ON (user_id, device_id)
    user_id, device_id, key_id, public_key, signature, created_at
FROM public.e2ee_signed_prekeys
WHERE expires_at IS NULL OR expires_at > NOW()
ORDER BY user_id, device_id, created_at DESC;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
