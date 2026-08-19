-- 056_enhance_voice_states_video.sql
-- Add video and screen share state columns to existing voice_states

ALTER TABLE voice_states
  ADD COLUMN IF NOT EXISTS video_enabled      boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS screen_sharing      boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS screen_share_type   text      CHECK (screen_share_type IN ('screen', 'application', 'camera_flip')),
  ADD COLUMN IF NOT EXISTS video_quality       text      NOT NULL DEFAULT 'auto'
                                                CHECK (video_quality IN ('auto', '360p', '480p', '720p', '1080p')),
  ADD COLUMN IF NOT EXISTS video_fps           integer   NOT NULL DEFAULT 30
                                                CHECK (video_fps IN (15, 30, 60)),
  ADD COLUMN IF NOT EXISTS suppress_video      boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS camera_facing       text      NOT NULL DEFAULT 'front'
                                                CHECK (camera_facing IN ('front', 'back'));

-- Index for quick lookups: who is streaming in a channel?
CREATE INDEX IF NOT EXISTS idx_voice_states_screen_sharing
  ON voice_states (channel_id)
  WHERE screen_sharing = true;

CREATE INDEX IF NOT EXISTS idx_voice_states_video_enabled
  ON voice_states (channel_id)
  WHERE video_enabled = true;

-- Composite index for active voice participants with media
CREATE INDEX IF NOT EXISTS idx_voice_states_active_media
  ON voice_states (channel_id, user_id)
  WHERE video_enabled = true OR screen_sharing = true;
