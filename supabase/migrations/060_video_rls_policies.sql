-- 060_video_rls_policies.sql

-- ========================
-- streams
-- ========================
ALTER TABLE streams ENABLE ROW LEVEL SECURITY;

-- Anyone in the server can see active streams
CREATE POLICY streams_select_server_member ON streams
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM members
      WHERE members.server_id = streams.server_id
        AND members.user_id = auth.uid()
    )
  );

-- Only the streamer can insert their own stream
CREATE POLICY streams_insert_own ON streams
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Only the streamer can update their own stream
CREATE POLICY streams_update_own ON streams
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ========================
-- stream_viewers
-- ========================
ALTER TABLE stream_viewers ENABLE ROW LEVEL SECURITY;

-- Viewers in the same server can see who's watching
CREATE POLICY stream_viewers_select ON stream_viewers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM streams s
      JOIN members m ON m.server_id = s.server_id
      WHERE s.id = stream_viewers.stream_id
        AND m.user_id = auth.uid()
    )
  );

-- Users can only insert their own viewer record
CREATE POLICY stream_viewers_insert_own ON stream_viewers
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can only update their own viewer record
CREATE POLICY stream_viewers_update_own ON stream_viewers
  FOR UPDATE USING (user_id = auth.uid());

-- ========================
-- video_settings
-- ========================
ALTER TABLE video_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY video_settings_select_own ON video_settings
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY video_settings_insert_own ON video_settings
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY video_settings_update_own ON video_settings
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
