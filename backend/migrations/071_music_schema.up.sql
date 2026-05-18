-- ============================================================
-- Migration 071: Sonic Drip — Music / Spotify Integration
-- ============================================================

-- Spotify sessions (store cookies only — NEVER passwords)
CREATE TABLE IF NOT EXISTS spotify_sessions (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    encrypted_session BYTEA       NOT NULL,
    display_name      TEXT,
    product           TEXT        DEFAULT 'free',
    device_id         TEXT,
    status            TEXT        NOT NULL DEFAULT 'active'
                                  CHECK (status IN ('active', 'expired', 'revoked')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ,
    UNIQUE (user_id)
);

-- Playback idempotency keys (prevent duplicate play commands)
CREATE TABLE IF NOT EXISTS playback_idempotency (
    key        TEXT        PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    response   JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

-- Shared playlists (shared to channels)
CREATE TABLE IF NOT EXISTS shared_playlists (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id    TEXT        NOT NULL,
    playlist_name  TEXT,
    spotify_url    TEXT        NOT NULL,
    track_count    INTEGER     DEFAULT 0,
    shared_by      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    channel_id     UUID        REFERENCES channels(id) ON DELETE CASCADE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMPTZ
);

-- Music events log (analytics, listen history)
CREATE TABLE IF NOT EXISTS music_events (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL,
    event_type  TEXT        NOT NULL,
    track_id    TEXT,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_spotify_sessions_user    ON spotify_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_spotify_sessions_status  ON spotify_sessions (status);
CREATE INDEX IF NOT EXISTS idx_shared_playlists_channel ON shared_playlists (channel_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shared_playlists_user    ON shared_playlists (shared_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_music_events_user_time   ON music_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_playback_idempotency_exp ON playback_idempotency (expires_at);
