-- 059_create_video_settings.sql

CREATE TABLE IF NOT EXISTS video_settings (
  user_id                uuid    PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,

  -- Camera defaults
  default_camera_enabled boolean NOT NULL DEFAULT false,
  default_camera_facing  text    NOT NULL DEFAULT 'front'
                                 CHECK (default_camera_facing IN ('front', 'back')),
  mirror_self_view       boolean NOT NULL DEFAULT true,

  -- Quality preferences
  preferred_quality      text    NOT NULL DEFAULT 'auto'
                                 CHECK (preferred_quality IN ('auto', '360p', '480p', '720p', '1080p')),
  preferred_fps          integer NOT NULL DEFAULT 30
                                 CHECK (preferred_fps IN (15, 30, 60)),
  hardware_acceleration  boolean NOT NULL DEFAULT true,

  -- Screen share defaults
  screen_share_audio     boolean NOT NULL DEFAULT true,
  screen_share_quality   text    NOT NULL DEFAULT '720p30'
                                 CHECK (screen_share_quality IN ('720p15', '720p30', '1080p30', '1080p60')),

  -- Bandwidth / data saver
  reduced_motion         boolean NOT NULL DEFAULT false,
  data_saver_mode        boolean NOT NULL DEFAULT false,
  max_incoming_quality   text    NOT NULL DEFAULT '1080p'
                                 CHECK (max_incoming_quality IN ('360p', '480p', '720p', '1080p')),

  -- Layout preferences
  default_layout         text    NOT NULL DEFAULT 'grid'
                                 CHECK (default_layout IN ('grid', 'focus', 'sidebar')),
  show_non_video         boolean NOT NULL DEFAULT true,

  -- PiP
  pip_enabled            boolean NOT NULL DEFAULT true,
  pip_position           text    NOT NULL DEFAULT 'bottom_right'
                                 CHECK (pip_position IN (
                                   'top_left', 'top_right',
                                   'bottom_left', 'bottom_right'
                                 )),

  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER set_video_settings_updated_at
  BEFORE UPDATE ON video_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Auto-create video_settings when profile is created
CREATE OR REPLACE FUNCTION create_default_video_settings()
RETURNS trigger AS $$
BEGIN
  INSERT INTO video_settings (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_video_settings
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_default_video_settings();
