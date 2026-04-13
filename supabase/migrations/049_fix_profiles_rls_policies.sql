-- HIGH-007: Fix overly permissive profile RLS policies
-- Restrict profile visibility to authenticated users only.
-- Add is_private column for user privacy control.

-- Add is_private column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false;

-- Index for privacy filtering
CREATE INDEX IF NOT EXISTS idx_profiles_is_private ON profiles(is_private) WHERE NOT is_private;

-- Drop the overly permissive policy
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;

-- Policy: Authenticated users can see non-private profiles, their own profile,
-- and profiles of accepted friends (even if private)
CREATE POLICY "Profiles viewable by authenticated users"
  ON profiles FOR SELECT
  TO authenticated
  USING (
    -- Own profile is always visible
    id = auth.uid()
    -- Non-private profiles visible to all authenticated users
    OR NOT is_private
    -- Private profiles visible to accepted friends
    OR EXISTS (
      SELECT 1 FROM friends 
      WHERE (user_id = auth.uid() AND friend_id = profiles.id AND status = 'accepted')
         OR (user_id = profiles.id AND friend_id = auth.uid() AND status = 'accepted')
    )
  );

-- Create a safe public view for profile lookups (excludes sensitive fields like email)
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
  id,
  username,
  discriminator,
  display_name,
  avatar,
  banner,
  bio,
  status,
  custom_status,
  created_at
FROM profiles
WHERE NOT is_private;
