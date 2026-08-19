-- Migration 153: Fix Security Definer Views by adding WITH (security_invoker = true)
-- Recreates compatibility views with security_invoker = true to enforce Row-Level Security.

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

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
