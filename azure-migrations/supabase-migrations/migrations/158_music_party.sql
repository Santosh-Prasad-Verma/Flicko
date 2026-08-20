-- ============================================================
-- Migration 158: Music Party
-- ============================================================

-- Create mp_sessions table
CREATE TABLE IF NOT EXISTS public.mp_sessions (
    id                  TEXT PRIMARY KEY,
    room_id             UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    dj_user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    next_dj_user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    rotation_mode       TEXT NOT NULL DEFAULT 'manual' CHECK (rotation_mode IN ('manual', 'round_robin', 'listener_vote')),
    state               TEXT NOT NULL DEFAULT 'draft' CHECK (state IN ('draft', 'ready', 'playing', 'paused', 'ended', 'degraded')),
    current_track_uri   TEXT,
    current_position_ms INTEGER NOT NULL DEFAULT 0,
    current_started_at  TIMESTAMPTZ,
    anchor_wall_ms      BIGINT NOT NULL DEFAULT 0,
    seq                 INTEGER NOT NULL DEFAULT 0,
    settings            JSONB NOT NULL DEFAULT '{
                          "vote_skip_threshold": 0.5,
                          "max_listeners": 25,
                          "allow_dupes": true
                        }'::jsonb,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at            TIMESTAMPTZ,
    last_active_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes on mp_sessions
CREATE INDEX IF NOT EXISTS idx_mp_sessions_room_active 
  ON public.mp_sessions (room_id)
  WHERE state IN ('ready', 'playing', 'paused', 'degraded');

CREATE INDEX IF NOT EXISTS idx_mp_sessions_dj ON public.mp_sessions (dj_user_id);
CREATE INDEX IF NOT EXISTS idx_mp_sessions_last_active ON public.mp_sessions (last_active_at);

-- Create mp_participants table
CREATE TABLE IF NOT EXISTS public.mp_participants (
    id              BIGSERIAL PRIMARY KEY,
    session_id      TEXT NOT NULL REFERENCES public.mp_sessions(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN ('dj', 'listener')),
    spotify_tier    TEXT CHECK (spotify_tier IN ('premium', 'free', 'none')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at         TIMESTAMPTZ,
    UNIQUE (session_id, user_id)
);

-- Create indexes on mp_participants
CREATE INDEX IF NOT EXISTS idx_mp_participants_session 
  ON public.mp_participants (session_id)
  WHERE left_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_mp_participants_user_active 
  ON public.mp_participants (user_id)
  WHERE left_at IS NULL;

-- Create mp_queue table
CREATE TABLE IF NOT EXISTS public.mp_queue (
    id               TEXT PRIMARY KEY,
    session_id       TEXT NOT NULL REFERENCES public.mp_sessions(id) ON DELETE CASCADE,
    spotify_uri      TEXT NOT NULL,
    title            TEXT,
    artist           TEXT,
    duration_ms      INTEGER,
    album_art_url    TEXT,
    preview_url      TEXT,
    added_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    position         DOUBLE PRECISION NOT NULL,
    state            TEXT NOT NULL DEFAULT 'queued' CHECK (state IN ('queued', 'playing', 'completed', 'skipped', 'removed')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    played_at        TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ
);

-- Create indexes on mp_queue
CREATE INDEX IF NOT EXISTS idx_mp_queue_session_position 
  ON public.mp_queue (session_id, position)
  WHERE state = 'queued';

CREATE INDEX IF NOT EXISTS idx_mp_queue_session_state 
  ON public.mp_queue (session_id, state);

-- Create mp_vibes table
CREATE TABLE IF NOT EXISTS public.mp_vibes (
    id            BIGSERIAL PRIMARY KEY,
    session_id    TEXT NOT NULL REFERENCES public.mp_sessions(id) ON DELETE CASCADE,
    queue_item_id TEXT REFERENCES public.mp_queue(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('heart', 'fire', 'star', 'skip_vote')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (queue_item_id, user_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_mp_vibes_session ON public.mp_vibes (session_id);

-- Create spotify_tokens table
CREATE TABLE IF NOT EXISTS public.spotify_tokens (
    user_id       UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    access_token  BYTEA NOT NULL,
    refresh_token BYTEA NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    scope         TEXT NOT NULL,
    tier          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION public.mp_touch_updated_at() 
RETURNS trigger AS $$
BEGIN 
    NEW.updated_at = now(); 
    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mp_sessions_touch
  BEFORE UPDATE ON public.mp_sessions
  FOR EACH ROW EXECUTE FUNCTION public.mp_touch_updated_at();

CREATE TRIGGER spotify_tokens_touch
  BEFORE UPDATE ON public.spotify_tokens
  FOR EACH ROW EXECUTE FUNCTION public.mp_touch_updated_at();

-- Enable Row-Level Security
ALTER TABLE public.mp_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mp_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mp_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mp_vibes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spotify_tokens ENABLE ROW LEVEL SECURITY;

-- Sessions: readable to channel voice states members; writable/insertable to DJ only
CREATE POLICY mp_sessions_read ON public.mp_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.voice_states m
      WHERE m.channel_id = public.mp_sessions.room_id
        AND m.user_id = auth.uid()
    )
  );

CREATE POLICY mp_sessions_dj_write ON public.mp_sessions
  FOR UPDATE
  USING (dj_user_id = auth.uid())
  WITH CHECK (dj_user_id = auth.uid());

CREATE POLICY mp_sessions_insert ON public.mp_sessions
  FOR INSERT
  WITH CHECK (dj_user_id = auth.uid());

-- Participants: a participant can read/write their own participant row
CREATE POLICY mp_participants_self ON public.mp_participants
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Queue: read access to active session participants; insert/edit to session members and DJs
CREATE POLICY mp_queue_session_member_read ON public.mp_queue
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.mp_participants p
      WHERE p.session_id = public.mp_queue.session_id 
        AND p.user_id = auth.uid()
    )
  );

CREATE POLICY mp_queue_member_insert ON public.mp_queue
  FOR INSERT
  WITH CHECK (
    added_by_user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.mp_participants p
      WHERE p.session_id = public.mp_queue.session_id
        AND p.user_id = auth.uid() 
        AND p.left_at IS NULL
    )
  );

CREATE POLICY mp_queue_dj_or_owner_modify ON public.mp_queue
  FOR UPDATE
  USING (
    added_by_user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM public.mp_sessions s
      WHERE s.id = public.mp_queue.session_id 
        AND s.dj_user_id = auth.uid()
    )
  );

-- Vibes: users can read and write their own vibes
CREATE POLICY mp_vibes_self ON public.mp_vibes
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Spotify tokens: user-only access
CREATE POLICY spotify_tokens_self ON public.spotify_tokens
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Enable realtime for watch together tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.mp_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mp_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mp_queue;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mp_vibes;
