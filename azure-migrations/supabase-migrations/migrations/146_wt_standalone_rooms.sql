-- ============================================================
-- Migration 146: Watch Together Standalone Rooms & Lobbies
-- ============================================================

-- Make room_id nullable to support standalone rooms created outside a channel
ALTER TABLE public.wt_sessions ALTER COLUMN room_id DROP NOT NULL;

-- Add standalone, public, and lobby details
ALTER TABLE public.wt_sessions 
    ADD COLUMN IF NOT EXISTS is_standalone BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS lobby_name TEXT;

-- Drop old read policy
DROP POLICY IF EXISTS wt_sessions_read ON public.wt_sessions;

-- Recreate read policy to support standalone watch rooms (accessible via secure session ID)
CREATE POLICY wt_sessions_read ON public.wt_sessions
  FOR SELECT
  USING (
    room_id IS NULL OR
    EXISTS (
      SELECT 1 FROM public.voice_states m
      WHERE m.channel_id = public.wt_sessions.room_id
        AND m.user_id = auth.uid()
    )
  );

-- Create index for high-performance public lobbies queries
CREATE INDEX IF NOT EXISTS idx_wt_sessions_public_active 
  ON public.wt_sessions (is_public)
  WHERE is_public = true AND state IN ('ready', 'playing', 'paused');
