-- ============================================================
-- Migration 145: Watch Together
-- ============================================================

-- Create wt_sessions table
CREATE TABLE IF NOT EXISTS public.wt_sessions (
    id                  TEXT PRIMARY KEY,
    room_id             UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    host_user_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    media_kind          TEXT NOT NULL CHECK (media_kind IN ('youtube', 'vimeo', 'mp4', 'hls', 'appwrite')),
    media_url           TEXT NOT NULL,
    media_title         TEXT,
    media_duration_ms   INTEGER,
    settings            JSONB NOT NULL DEFAULT '{}'::jsonb,
    state               TEXT NOT NULL DEFAULT 'draft' CHECK (state IN ('draft', 'ready', 'playing', 'paused', 'ended')),
    anchor_position_ms  INTEGER NOT NULL DEFAULT 0,
    anchor_playing      BOOLEAN NOT NULL DEFAULT false,
    anchor_rate         NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    anchor_wall_ms      BIGINT NOT NULL DEFAULT 0,
    seq                 INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at            TIMESTAMPTZ,
    last_active_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes on wt_sessions
CREATE INDEX IF NOT EXISTS idx_wt_sessions_room_active 
  ON public.wt_sessions (room_id)
  WHERE state IN ('ready', 'playing', 'paused');

CREATE INDEX IF NOT EXISTS idx_wt_sessions_host ON public.wt_sessions (host_user_id);
CREATE INDEX IF NOT EXISTS idx_wt_sessions_last_active ON public.wt_sessions (last_active_at);

-- Create wt_participants table
CREATE TABLE IF NOT EXISTS public.wt_participants (
    id              BIGSERIAL PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES public.wt_sessions(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN ('host', 'viewer')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at         TIMESTAMPTZ,
    last_drift_ms   INTEGER NOT NULL DEFAULT 0,
    UNIQUE (session_id, user_id)
);

-- Create indexes on wt_participants
CREATE INDEX IF NOT EXISTS idx_wt_participants_session 
  ON public.wt_participants (session_id)
  WHERE left_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_wt_participants_user_active 
  ON public.wt_participants (user_id)
  WHERE left_at IS NULL;

-- Create wt_reactions table
CREATE TABLE IF NOT EXISTS public.wt_reactions (
    id              BIGSERIAL PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES public.wt_sessions(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    emoji           TEXT NOT NULL,
    position_ms     INTEGER NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index on wt_reactions
CREATE INDEX IF NOT EXISTS idx_wt_reactions_session_pos 
  ON public.wt_reactions (session_id, position_ms);

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION public.wt_touch_updated_at() 
RETURNS trigger AS $$
BEGIN 
    NEW.updated_at = now(); 
    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wt_sessions_touch
  BEFORE UPDATE ON public.wt_sessions
  FOR EACH ROW EXECUTE FUNCTION public.wt_touch_updated_at();

-- Enable Row-Level Security
ALTER TABLE public.wt_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wt_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wt_reactions ENABLE ROW LEVEL SECURITY;

-- Sessions: readable to channel voice states members; writable/insertable to host only
CREATE POLICY wt_sessions_read ON public.wt_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.voice_states m
      WHERE m.channel_id = public.wt_sessions.room_id
        AND m.user_id = auth.uid()
    )
  );

CREATE POLICY wt_sessions_host_write ON public.wt_sessions
  FOR UPDATE
  USING (host_user_id = auth.uid())
  WITH CHECK (host_user_id = auth.uid());

CREATE POLICY wt_sessions_insert ON public.wt_sessions
  FOR INSERT
  WITH CHECK (host_user_id = auth.uid());

-- Participants: a participant can read their own session row; host can read all
CREATE POLICY wt_participants_self_read ON public.wt_participants
  FOR SELECT
  USING (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.wt_sessions s
      WHERE s.id = public.wt_participants.session_id
        AND s.host_user_id = auth.uid()
    )
  );

CREATE POLICY wt_participants_self_insert ON public.wt_participants
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY wt_participants_self_leave ON public.wt_participants
  FOR UPDATE
  USING (user_id = auth.uid());

-- Reactions: any active participant can post their own; session members can read
CREATE POLICY wt_reactions_insert ON public.wt_reactions
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.wt_participants p
      WHERE p.session_id = public.wt_reactions.session_id
        AND p.user_id = auth.uid()
        AND p.left_at IS NULL
    )
  );

CREATE POLICY wt_reactions_read ON public.wt_reactions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.wt_participants p
      WHERE p.session_id = public.wt_reactions.session_id
        AND p.user_id = auth.uid()
    )
  );

-- Enable realtime for watch together tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.wt_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wt_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wt_reactions;
