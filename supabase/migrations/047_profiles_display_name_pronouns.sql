-- Migration 047: Add display_name and pronouns to profiles
-- Required by the Edit Profile screen (settings/edit-profile.tsx)

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS pronouns TEXT;

-- display_name is the user-visible name (different from username which is the login handle)
COMMENT ON COLUMN public.profiles.display_name IS 'User-facing display name, shown in messages and profile cards';
COMMENT ON COLUMN public.profiles.pronouns IS 'User pronouns (e.g. he/him, she/her, they/them)';
