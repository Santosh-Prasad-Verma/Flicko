# Short Videos — SCHEMA

```sql
CREATE TABLE short_videos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       UUID NOT NULL REFERENCES users(id),
  server_id       UUID REFERENCES servers(id) ON DELETE SET NULL,
  visibility      TEXT NOT NULL DEFAULT 'server' CHECK (visibility IN ('public','server','friends','private')),
  caption         TEXT,
  duration_sec    INT NOT NULL CHECK (duration_sec BETWEEN 1 AND 60),
  hls_url         TEXT,
  thumbnail_url   TEXT,
  captions_url    TEXT,
  audio_fp        TEXT,
  status          TEXT NOT NULL DEFAULT 'processing'
                    CHECK (status IN ('processing','ready','blocked','removed')),
  view_count      BIGINT NOT NULL DEFAULT 0,
  like_count      INT NOT NULL DEFAULT 0,
  comment_count   INT NOT NULL DEFAULT 0,
  share_count     INT NOT NULL DEFAULT 0,
  save_count      INT NOT NULL DEFAULT 0,
  ranking_score   NUMERIC(10,4) NOT NULL DEFAULT 0,
  embedding       VECTOR(768),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at    TIMESTAMPTZ
);
CREATE INDEX idx_sv_author     ON short_videos(author_id, created_at DESC);
CREATE INDEX idx_sv_server     ON short_videos(server_id, published_at DESC);
CREATE INDEX idx_sv_ranking    ON short_videos(ranking_score DESC) WHERE status='ready' AND visibility='public';
CREATE INDEX idx_sv_embedding  ON short_videos USING ivfflat (embedding vector_cosine_ops);

CREATE TABLE short_video_engagements (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id     UUID NOT NULL REFERENCES short_videos(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id),
  kind         TEXT NOT NULL CHECK (kind IN ('view','like','unlike','comment','share','save','unsave')),
  watch_ms     INT,
  payload      JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sve_video    ON short_video_engagements(video_id, created_at DESC);
CREATE INDEX idx_sve_user_kind ON short_video_engagements(user_id, kind, created_at DESC);

CREATE TABLE short_video_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id    UUID NOT NULL REFERENCES short_videos(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id),
  reason      TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','rejected')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE short_video_feed_signals (
  user_id      UUID NOT NULL REFERENCES users(id),
  video_id     UUID NOT NULL REFERENCES short_videos(id) ON DELETE CASCADE,
  signal_type  TEXT NOT NULL,
  weight       NUMERIC(8,4) NOT NULL,
  computed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, video_id, signal_type)
);
```

## RLS
```sql
ALTER TABLE short_videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY sv_read_public ON short_videos FOR SELECT
  USING (visibility='public' AND status='ready');
CREATE POLICY sv_read_server ON short_videos FOR SELECT
  USING (visibility='server' AND server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid()));
CREATE POLICY sv_read_friends ON short_videos FOR SELECT
  USING (visibility='friends' AND author_id IN (SELECT friend_id FROM friends WHERE user_id=auth.uid()));
CREATE POLICY sv_read_self ON short_videos FOR SELECT USING (author_id=auth.uid());
CREATE POLICY sv_write_self ON short_videos FOR INSERT WITH CHECK (author_id=auth.uid());
CREATE POLICY sv_update_self ON short_videos FOR UPDATE USING (author_id=auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `sv:feed:fyp:<user>` | cursor list | 60s |
| `sv:feed:server:<id>` | cursor list | 30s |
| `sv:counts:<id>` | counters | 5s |

## Migration: `supabase/migrations/237_short_videos.up.sql`

## Retention
- 30d hot Appwrite, 60d cold R2, archive or delete at 180d (author opt-in extends).
- Engagements 90d aggregate-then-purge.
