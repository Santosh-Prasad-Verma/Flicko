-- 058_create_stream_viewers.sql

CREATE TABLE IF NOT EXISTS stream_viewers (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id   uuid        NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  user_id     uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at   timestamptz NOT NULL DEFAULT now(),
  left_at     timestamptz,

  -- Unique active viewer per stream
  CONSTRAINT unique_active_viewer
    UNIQUE (stream_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_stream_viewers_active
  ON stream_viewers (stream_id)
  WHERE left_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_stream_viewers_user
  ON stream_viewers (user_id)
  WHERE left_at IS NULL;

-- Function to update viewer count on streams table
CREATE OR REPLACE FUNCTION update_stream_viewer_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE streams
    SET viewer_count = (
      SELECT count(*) FROM stream_viewers
      WHERE stream_id = NEW.stream_id AND left_at IS NULL
    ),
    max_viewers = GREATEST(
      max_viewers,
      (SELECT count(*) FROM stream_viewers
       WHERE stream_id = NEW.stream_id AND left_at IS NULL)
    )
    WHERE id = NEW.stream_id;
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' AND NEW.left_at IS NOT NULL AND OLD.left_at IS NULL THEN
    UPDATE streams
    SET viewer_count = (
      SELECT count(*) FROM stream_viewers
      WHERE stream_id = NEW.stream_id AND left_at IS NULL
    )
    WHERE id = NEW.stream_id;
    RETURN NEW;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_viewer_count
  AFTER INSERT OR UPDATE ON stream_viewers
  FOR EACH ROW
  EXECUTE FUNCTION update_stream_viewer_count();
