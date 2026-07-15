-- Migration 079 Down: Restore views without WITH (security_invoker = true)

-- 1. Restore users view
CREATE OR REPLACE VIEW public.users AS
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

-- 2. Restore e2ee_latest_signed_prekey view
CREATE OR REPLACE VIEW public.e2ee_latest_signed_prekey AS
SELECT DISTINCT ON (user_id, device_id)
    user_id, device_id, key_id, public_key, signature, created_at
FROM public.e2ee_signed_prekeys
WHERE expires_at IS NULL OR expires_at > NOW()
ORDER BY user_id, device_id, created_at DESC;
