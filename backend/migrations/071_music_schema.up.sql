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

-- Per-server now-playing queue
CREATE TABLE IF NOT EXISTS music_queues (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id        UUID        NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    title            TEXT        NOT NULL,
    url              TEXT        NOT NULL,
    duration_seconds INTEGER     DEFAULT 0,
    requested_by     UUID        REFERENCES users(id) ON DELETE SET NULL,
    position         INTEGER     NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Per-server music settings
CREATE TABLE IF NOT EXISTS music_settings (
    server_id              UUID        PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled                BOOLEAN     NOT NULL DEFAULT TRUE,
    default_volume         INTEGER     NOT NULL DEFAULT 50 CHECK (default_volume BETWEEN 0 AND 100),
    dj_role_id             UUID,
    now_playing_channel_id UUID        REFERENCES channels(id) ON DELETE SET NULL,
    repeat_mode            TEXT        NOT NULL DEFAULT 'off' CHECK (repeat_mode IN ('off', 'song', 'queue')),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Per-server playlists
CREATE TABLE IF NOT EXISTS playlists (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id  UUID        NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    creator_id UUID        REFERENCES users(id) ON DELETE SET NULL,
    is_public  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (server_id, name)
);

-- Tracks within playlists
CREATE TABLE IF NOT EXISTS playlist_tracks (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id      UUID        NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    title            TEXT        NOT NULL,
    url              TEXT        NOT NULL,
    duration_seconds INTEGER     DEFAULT 0,
    position         INTEGER     NOT NULL DEFAULT 0,
    added_by         UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Recently-played history per server
CREATE TABLE IF NOT EXISTS song_history (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id  UUID        NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    title      TEXT        NOT NULL,
    url        TEXT        NOT NULL,
    played_by  UUID        REFERENCES users(id) ON DELETE SET NULL,
    played_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_spotify_sessions_user    ON spotify_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_spotify_sessions_status  ON spotify_sessions (status);
CREATE INDEX IF NOT EXISTS idx_shared_playlists_channel ON shared_playlists (channel_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_shared_playlists_user    ON shared_playlists (shared_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_music_events_user_time   ON music_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_playback_idempotency_exp ON playback_idempotency (expires_at);
CREATE INDEX IF NOT EXISTS idx_music_queues_server_pos  ON music_queues (server_id, position);
CREATE INDEX IF NOT EXISTS idx_playlists_server         ON playlists (server_id);
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist ON playlist_tracks (playlist_id, position);
CREATE INDEX IF NOT EXISTS idx_song_history_server_time ON song_history (server_id, played_at DESC);
