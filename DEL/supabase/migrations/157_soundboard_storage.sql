-- ============================================================
-- Migration 157: Soundboard Storage Bucket and RLS Policies
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('soundboard-sounds', 'soundboard-sounds', true)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow any authenticated user to select files from soundboard-sounds
CREATE POLICY "Allow authenticated SELECT on soundboard-sounds"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'soundboard-sounds');

-- Policy to allow authenticated users to insert soundboard files
CREATE POLICY "Allow authenticated INSERT on soundboard-sounds"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'soundboard-sounds');

-- RPC function alias for play sound count incrementation
CREATE OR REPLACE FUNCTION increment_sound_plays(sound_id UUID)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE soundboard_sounds
  SET play_count = play_count + 1,
      updated_at = now()
  WHERE id = sound_id;
$$;

