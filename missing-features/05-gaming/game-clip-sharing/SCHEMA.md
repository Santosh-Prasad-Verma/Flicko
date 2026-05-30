# Game Clip Sharing — SCHEMA

```sql
CREATE TABLE clips (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       UUID NOT NULL REFERENCES users(id),
  server_id       UUID REFERENCES servers(id) ON DELETE SET NULL,
  channel_id      UUID REFERENCES channels(id) ON DELETE SET NULL,
  game_slug       TEXT,
  caption         TEXT,
  duration_sec    INT NOT NULL CHECK (duration_sec BETWEEN 1 AND 90),
  hls_url         TEXT,
  thumbnail_url   TEXT,
  audio_fp        TEXT,
  status          TEXT NOT NULL DEFAULT 'processing'
                    CHECK (status IN ('processing','ready','blocked','removed')),
  view_count      BIGINT NOT NULL DEFAULT 0,
  reaction_count  INT NOT NULL DEFAULT 0,
  saved           BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  ready_at        TIMESTAMPTZ
);
CREATE INDEX idx_clips_author     ON clips(author_id, created_at DESC);
CREATE INDEX idx_clips_channel    ON clips(channel_id, created_at DESC);
CREATE INDEX idx_clips_game       ON clips(game_slug, created_at DESC);

CREATE TABLE clip_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clip_id     UUID NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
  user_id     UUID,
  watched_ms  INT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE clip_reports (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clip_id    UUID NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id),
  reason     TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## RLS
```sql
ALTER TABLE clips ENABLE ROW LEVEL SECURITY;
CREATE POLICY clips_read_member ON clips FOR SELECT
  USING (server_id IS NULL OR server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid()));
CREATE POLICY clips_write_self ON clips FOR INSERT WITH CHECK (author_id=auth.uid());
CREATE POLICY clips_update_self ON clips FOR UPDATE USING (author_id=auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `clips:wall:<channel>` | cursor list | 60s |
| `clips:counts:<id>` | counters | 5s |

## Migration: `supabase/migrations/153_clips.up.sql`

## Retention
- Hot 30d, cold 60d, delete at 90d unless `saved=true`.
