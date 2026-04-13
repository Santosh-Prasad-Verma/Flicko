-- 057_create_streams.sql
-- Streams table for Go Live feature

CREATE TABLE IF NOT EXISTS streams (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  channel_id      uuid        NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  server_id       uuid        NOT NULL REFERENCES servers(id) ON DELETE CASCADE,

  -- Stream metadata
  title           text        NOT NULL DEFAULT '',
  status          text        NOT NULL DEFAULT 'starting'
                              CHECK (status IN ('starting', 'live', 'ended', 'errored')),
  stream_type     text        NOT NULL DEFAULT 'screen'
                              CHECK (stream_type IN ('screen', 'application', 'game', 'camera')),

  -- Quality settings
  max_quality     text        NOT NULL DEFAULT '720p30'
                              CHECK (max_quality IN ('720p15', '720p30', '1080p30', '1080p60')),
  actual_quality  text,

  -- Viewer tracking
  viewer_count    integer     NOT NULL DEFAULT 0,
  max_viewers     integer     NOT NULL DEFAULT 0,

  -- Application metadata (for "Playing X" context)
  application_name text,
  application_id   text,

  -- Timestamps
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_streams_channel_live
  ON streams (channel_id)
  WHERE status = 'live';

CREATE INDEX IF NOT EXISTS idx_streams_server_live
  ON streams (server_id)
  WHERE status = 'live';

CREATE INDEX IF NOT EXISTS idx_streams_user_active
  ON streams (user_id)
  WHERE status IN ('starting', 'live');

-- Trigger for updated_at
CREATE TRIGGER set_streams_updated_at
  BEFORE UPDATE ON streams
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
