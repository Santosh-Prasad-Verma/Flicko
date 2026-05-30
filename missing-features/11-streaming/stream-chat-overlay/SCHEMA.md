# SCHEMA — Stream Chat Overlay

## 1. Migration 232 — Chat Tables

```sql
-- migrations/232_stream_chat.up.sql

CREATE TABLE stream_chat_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id       UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    client_id       TEXT NOT NULL,
    body            TEXT NOT NULL CHECK (char_length(body) <= 500),
    body_tokens     JSONB NOT NULL DEFAULT '[]'::jsonb,
    badges          TEXT[] NOT NULL DEFAULT '{}',
    reply_to        UUID REFERENCES stream_chat_messages(id) ON DELETE SET NULL,
    is_pinned       BOOLEAN NOT NULL DEFAULT FALSE,
    is_highlight    BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    deleted_by      UUID REFERENCES users(id),
    delete_reason   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (stream_id, client_id)
);

CREATE INDEX idx_chat_messages_stream_created
    ON stream_chat_messages (stream_id, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_chat_messages_user
    ON stream_chat_messages (user_id, created_at DESC);

CREATE INDEX idx_chat_messages_pinned
    ON stream_chat_messages (stream_id)
    WHERE is_pinned = TRUE;

CREATE TABLE stream_chat_emotes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id      UUID REFERENCES channels(id) ON DELETE CASCADE,
    code            TEXT NOT NULL,
    image_url       TEXT NOT NULL,
    image_url_2x    TEXT,
    width           INTEGER NOT NULL DEFAULT 28,
    height          INTEGER NOT NULL DEFAULT 28,
    is_global       BOOLEAN NOT NULL DEFAULT FALSE,
    tier            TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free','sub','pro')),
    created_by      UUID REFERENCES users(id),
    approved        BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (channel_id, code),
    CHECK (channel_id IS NOT NULL OR is_global = TRUE)
);

CREATE INDEX idx_emotes_channel ON stream_chat_emotes (channel_id) WHERE approved = TRUE;
CREATE INDEX idx_emotes_global ON stream_chat_emotes (is_global) WHERE is_global = TRUE AND approved = TRUE;

CREATE TABLE stream_chat_bans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id       UUID REFERENCES streams(id) ON DELETE CASCADE,
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    actor_user_id   UUID NOT NULL REFERENCES users(id),
    scope           TEXT NOT NULL CHECK (scope IN ('stream','channel')),
    reason          TEXT,
    expires_at      TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    revoked_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bans_active_stream
    ON stream_chat_bans (stream_id, user_id)
    WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now());

CREATE INDEX idx_bans_active_channel
    ON stream_chat_bans (channel_id, user_id)
    WHERE scope = 'channel' AND revoked_at IS NULL;
```

## 2. Mode Flags (Redis)

Centrifugo channels are ephemeral, but mode flags survive node restarts in Redis.

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `chat:{sid}:mode:slow` | int seconds | stream lifetime | slowmode interval |
| `chat:{sid}:mode:emote_only` | bool | stream lifetime | emote-only flag |
| `chat:{sid}:mode:follow_only` | int minutes | stream lifetime | minimum follow age |
| `chat:{sid}:sm:{uid}` | NX flag | slowmode seconds | per-user slow gate |
| `chat:{sid}:rl:{uid}` | counter | 10s | rate-limit window |
| `chat:{sid}:ban:{uid}` | flag | up to 24h | ban cache |

## 3. RLS Policies

```sql
ALTER TABLE stream_chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY chat_msg_read ON stream_chat_messages
    FOR SELECT USING (
        deleted_at IS NULL
        OR auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM channel_moderators m
                   WHERE m.channel_id = stream_chat_messages.channel_id
                     AND m.user_id = auth.uid())
    );

CREATE POLICY chat_msg_write ON stream_chat_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY chat_msg_soft_delete ON stream_chat_messages
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM channel_moderators m
                WHERE m.channel_id = stream_chat_messages.channel_id
                  AND m.user_id = auth.uid())
        OR auth.uid() = user_id
    );

ALTER TABLE stream_chat_bans ENABLE ROW LEVEL SECURITY;

CREATE POLICY ban_read ON stream_chat_bans
    FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM channel_moderators m
                   WHERE m.channel_id = stream_chat_bans.channel_id
                     AND m.user_id = auth.uid())
    );

CREATE POLICY ban_write ON stream_chat_bans
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM channel_moderators m
                WHERE m.channel_id = stream_chat_bans.channel_id
                  AND m.user_id = auth.uid())
    );
```

## 4. Retention

- `stream_chat_messages` retained 30 days, then archived to S3 in Parquet partitioned by `date(created_at)`.
- Pinned and highlighted messages retained 90 days.
- `stream_chat_bans` retained indefinitely; expired rows compacted nightly.

## 5. Partitioning

```sql
-- Partition messages by month
ALTER TABLE stream_chat_messages
    PARTITION BY RANGE (created_at);

CREATE TABLE stream_chat_messages_2026_05 PARTITION OF stream_chat_messages
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
-- pg_partman manages monthly rollover
```

## 6. Down Migration

```sql
-- migrations/232_stream_chat.down.sql
DROP TABLE IF EXISTS stream_chat_bans;
DROP TABLE IF EXISTS stream_chat_emotes;
DROP TABLE IF EXISTS stream_chat_messages CASCADE;
```

## 7. Sample Queries

```sql
-- Last 50 messages on a stream
SELECT m.*, u.username, u.avatar_url
FROM stream_chat_messages m
JOIN users u ON u.id = m.user_id
WHERE m.stream_id = $1 AND m.deleted_at IS NULL
ORDER BY m.created_at DESC
LIMIT 50;

-- Active ban check
SELECT EXISTS (
    SELECT 1 FROM stream_chat_bans
    WHERE channel_id = $1 AND user_id = $2
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > now())
);

-- Mod activity in window
SELECT actor_user_id, count(*) AS actions
FROM stream_chat_bans
WHERE channel_id = $1 AND created_at > now() - interval '7 days'
GROUP BY actor_user_id
ORDER BY actions DESC;
```
