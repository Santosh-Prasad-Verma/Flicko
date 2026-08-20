-- Migration: Add server_emojis table for MinIO-backed custom emoji storage
-- The profiles.avatar, profiles.banner, servers.icon, servers.banner columns
-- already exist from migrations 001 and 002.
-- The messages.attachments JSONB column already exists from migration 005/008.

-- Custom emojis table
CREATE TABLE IF NOT EXISTS server_emojis (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  url         TEXT NOT NULL,
  object_name TEXT NOT NULL,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(server_id, name)
);

-- Index for fast emoji lookup per server
CREATE INDEX IF NOT EXISTS idx_server_emojis_server_id ON server_emojis(server_id);
