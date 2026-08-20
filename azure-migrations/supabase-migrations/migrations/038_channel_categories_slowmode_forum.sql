-- 038_channel_categories_slowmode_forum.sql
--
-- Adds missing columns for channel categories, slowmode, forum support,
-- stage channels, and read states.

-- Ensure channel types match frontend requirements
-- Backend schema (001) already has: text, voice, category, dm
-- We need to add: announcement, forum, stage
-- Use DO block to alter the CHECK constraint if the column exists

-- 1. Add parent_id (for category grouping) if not already present
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'channels' AND column_name = 'parent_id'
  ) THEN
    ALTER TABLE channels ADD COLUMN parent_id UUID REFERENCES channels(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2. Add slowmode_seconds
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'channels' AND column_name = 'slowmode_seconds'
  ) THEN
    ALTER TABLE channels ADD COLUMN slowmode_seconds INTEGER DEFAULT 0;
  END IF;
END $$;

-- 3. Add default_thread_auto_archive
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'channels' AND column_name = 'default_thread_auto_archive'
  ) THEN
    ALTER TABLE channels ADD COLUMN default_thread_auto_archive INTEGER DEFAULT 1440; -- 24h default
  END IF;
END $$;

-- 4. Add updated_at to channels if not present
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'channels' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE channels ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- 5. Add hoist and icon_url to roles if not present
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'roles' AND column_name = 'hoist'
  ) THEN
    ALTER TABLE roles ADD COLUMN hoist BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'roles' AND column_name = 'mentionable'
  ) THEN
    ALTER TABLE roles ADD COLUMN mentionable BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'roles' AND column_name = 'icon_url'
  ) THEN
    ALTER TABLE roles ADD COLUMN icon_url TEXT;
  END IF;
END $$;

-- 6. Forum Tags table
CREATE TABLE IF NOT EXISTS forum_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT,               -- emoji associated with tag
  moderated BOOLEAN DEFAULT FALSE, -- only mods can apply
  position INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(channel_id, name)
);

-- 7. Forum post → tag join
CREATE TABLE IF NOT EXISTS forum_post_tags (
  thread_id UUID NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES forum_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (thread_id, tag_id)
);

-- 8. Channel read states (per-user per-channel)
CREATE TABLE IF NOT EXISTS channel_read_states (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  last_read_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  mention_count INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, channel_id)
);

-- 9. User notes (private notes about other users)
CREATE TABLE IF NOT EXISTS user_notes (
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  target_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (owner_id, target_id)
);

-- 9.5 Webhooks (Dependency for channel_follows)
CREATE TABLE IF NOT EXISTS webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  avatar_url TEXT,
  token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Announcement channel follows
CREATE TABLE IF NOT EXISTS channel_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  target_channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  webhook_id UUID REFERENCES webhooks(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source_channel_id, target_channel_id)
);

-- 11. Slowmode tracking (who sent last, when)
CREATE TABLE IF NOT EXISTS slowmode_state (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, channel_id)
);

-- 12. Member timeout tracking
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'server_members' AND column_name = 'timeout_until'
  ) THEN
    ALTER TABLE server_members ADD COLUMN timeout_until TIMESTAMPTZ;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'server_members' AND column_name = 'nickname'
  ) THEN
    ALTER TABLE server_members ADD COLUMN nickname TEXT;
  END IF;
END $$;

-- 13. Server notification settings per-user
CREATE TABLE IF NOT EXISTS server_notification_settings (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  level TEXT DEFAULT 'all_messages' CHECK (level IN ('all_messages', 'only_mentions', 'nothing')),
  suppress_everyone BOOLEAN DEFAULT FALSE,
  suppress_roles BOOLEAN DEFAULT FALSE,
  muted BOOLEAN DEFAULT FALSE,
  mute_until TIMESTAMPTZ,
  PRIMARY KEY (user_id, server_id)
);

-- 14. Channel notification settings per-user
CREATE TABLE IF NOT EXISTS channel_notification_settings (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  level TEXT DEFAULT 'default' CHECK (level IN ('default', 'all_messages', 'only_mentions', 'nothing')),
  muted BOOLEAN DEFAULT FALSE,
  mute_until TIMESTAMPTZ,
  PRIMARY KEY (user_id, channel_id)
);

-- 15. Category-level notification settings
CREATE TABLE IF NOT EXISTS category_notification_settings (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  muted BOOLEAN DEFAULT FALSE,
  collapsed BOOLEAN DEFAULT FALSE, -- whether user collapsed this category
  PRIMARY KEY (user_id, category_id)
);

-- RLS Policies
ALTER TABLE forum_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_post_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_read_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE slowmode_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_notification_settings ENABLE ROW LEVEL SECURITY;

-- Read states: users can only see/update their own
CREATE POLICY "Users can manage own read states"
  ON channel_read_states FOR ALL USING (auth.uid() = user_id);

-- User notes: only owner can see/edit
CREATE POLICY "Users can manage own notes"
  ON user_notes FOR ALL USING (auth.uid() = owner_id);

-- Forum tags: server members can view
CREATE POLICY "Members can view forum tags"
  ON forum_tags FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM server_members sm
      JOIN channels c ON c.id = forum_tags.channel_id
      WHERE sm.server_id = c.server_id AND sm.user_id = auth.uid()
    )
  );

-- Notification settings: users manage their own
CREATE POLICY "Users can manage server notification settings"
  ON server_notification_settings FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage channel notification settings"
  ON channel_notification_settings FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage category notification settings"
  ON category_notification_settings FOR ALL USING (auth.uid() = user_id);

-- Slowmode: users manage their own state
CREATE POLICY "Users can manage own slowmode state"
  ON slowmode_state FOR ALL USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_channels_parent_id ON channels(parent_id);
CREATE INDEX IF NOT EXISTS idx_channels_server_position ON channels(server_id, position);
CREATE INDEX IF NOT EXISTS idx_read_states_user ON channel_read_states(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_tags_channel ON forum_tags(channel_id);
CREATE INDEX IF NOT EXISTS idx_slowmode_user_channel ON slowmode_state(user_id, channel_id);
