-- ============================================================
-- Migration 053: Soundboard & Activities tables
-- ============================================================
-- Adds tables for the Soundboard feature and Activity sessions.

-- ── Soundboard Sounds ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS soundboard_sounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 64),
  emoji TEXT DEFAULT '🔊',
  sound_url TEXT NOT NULL,
  duration REAL DEFAULT 0,
  uploaded_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  play_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_soundboard_sounds_server ON soundboard_sounds(server_id);

-- ── Soundboard Favorites ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS soundboard_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sound_id UUID NOT NULL REFERENCES soundboard_sounds(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, sound_id)
);

CREATE INDEX idx_soundboard_favorites_user ON soundboard_favorites(user_id);

-- Increment play count RPC
CREATE OR REPLACE FUNCTION increment_sound_play_count(sound_id UUID)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE soundboard_sounds
  SET play_count = play_count + 1,
      updated_at = now()
  WHERE id = sound_id;
$$;

-- ── Activities ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon_url TEXT DEFAULT '',
  category TEXT NOT NULL CHECK (category IN ('games', 'watch_together', 'premium')),
  max_participants INTEGER DEFAULT 25,
  is_premium BOOLEAN DEFAULT false,
  embed_url TEXT DEFAULT '',
  developer TEXT DEFAULT 'Flicko',
  avg_duration TEXT DEFAULT '~15 min',
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── Activity Sessions ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activity_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  host_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  state TEXT NOT NULL DEFAULT 'launching'
    CHECK (state IN ('idle', 'launching', 'active', 'closing', 'ended')),
  embed_url TEXT DEFAULT '',
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_activity_sessions_channel ON activity_sessions(channel_id);
CREATE INDEX idx_activity_sessions_state ON activity_sessions(state);

-- ── Activity Participants ────────────────────────────────────

CREATE TABLE IF NOT EXISTS activity_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES activity_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, user_id)
);

CREATE INDEX idx_activity_participants_session ON activity_participants(session_id);

-- ── RLS Policies ─────────────────────────────────────────────

ALTER TABLE soundboard_sounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE soundboard_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_participants ENABLE ROW LEVEL SECURITY;

-- Soundboard: server members can read, admins/uploaders can manage
CREATE POLICY "Server members can view soundboard sounds"
  ON soundboard_sounds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = soundboard_sounds.server_id
        AND server_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Server members can insert soundboard sounds"
  ON soundboard_sounds FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = soundboard_sounds.server_id
        AND server_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Uploaders or admins can delete soundboard sounds"
  ON soundboard_sounds FOR DELETE
  USING (
    uploaded_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM servers
      WHERE servers.id = soundboard_sounds.server_id
        AND servers.owner_id = auth.uid()
    )
  );

-- Favorites: users manage their own
CREATE POLICY "Users manage own favorites"
  ON soundboard_favorites FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Activities: everyone can read
DROP POLICY IF EXISTS "Anyone can view activities" ON activities;
CREATE POLICY "Anyone can view activities"
  ON activities FOR SELECT
  USING (true);

-- Activity sessions: server members can view & manage
CREATE POLICY "Server members can view activity sessions"
  ON activity_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = activity_sessions.server_id
        AND server_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Server members can create activity sessions"
  ON activity_sessions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = activity_sessions.server_id
        AND server_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Host can update activity sessions"
  ON activity_sessions FOR UPDATE
  USING (host_user_id = auth.uid());

CREATE POLICY "Host can delete activity sessions"
  ON activity_sessions FOR DELETE
  USING (host_user_id = auth.uid());

-- Activity participants: session members can view, users manage their own
CREATE POLICY "Server members can view activity participants"
  ON activity_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM activity_sessions AS s
      JOIN server_members AS sm ON sm.server_id = s.server_id
      WHERE s.id = activity_participants.session_id
        AND sm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can join activity sessions"
  ON activity_participants FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can leave activity sessions"
  ON activity_participants FOR DELETE
  USING (user_id = auth.uid());

-- Enable realtime for activity sessions
ALTER PUBLICATION supabase_realtime ADD TABLE activity_sessions;
