-- Migration 064: Allow system/bot messages without an author_id
-- Bot messages (welcome, leveling, automod, starboard, ticket) are inserted
-- by the Go backend with type='system'. These don't have a real user profile,
-- so author_id must be nullable for system messages.

-- Make author_id nullable on messages table
ALTER TABLE public.messages ALTER COLUMN author_id DROP NOT NULL;

-- Create a compatibility view so the Go backend (which queries 'users')
-- works against the Supabase schema (which uses 'profiles').
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

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
