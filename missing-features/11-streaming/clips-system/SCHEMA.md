# Clips System — Database Schema

Migration: `231_clips_system.sql`. Builds on `230_vod_storage.sql` (FKs to `vods`).

## Tables

### `clips`

```sql
CREATE TYPE clip_status AS ENUM (
  'queued', 'rendering', 'ready',
  'archived', 'errored', 'removed'
);

CREATE TYPE clip_source AS ENUM ('live', 'vod');
CREATE TYPE clip_tier   AS ENUM ('hot', 'cold');

CREATE TABLE clips (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            text NOT NULL UNIQUE,           -- 8-char base58, public URL

  -- source
  source          clip_source NOT NULL,
  stream_id       uuid REFERENCES streams(id) ON DELETE SET NULL,
  vod_id          uuid REFERENCES vods(id)    ON DELETE SET NULL,
  creator_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  clipper_id      uuid NOT NULL REFERENCES users(id) ON DELETE SET NULL,

  -- range
  t_start_ms      integer NOT NULL,
  duration_ms     integer NOT NULL CHECK (duration_ms BETWEEN 5000 AND 300000),

  -- meta
  title           text NOT NULL DEFAULT '',
  description     text NOT NULL DEFAULT '',
  is_mature       boolean NOT NULL DEFAULT false,

  -- status
  status          clip_status NOT NULL DEFAULT 'queued',
  tier            clip_tier   NOT NULL DEFAULT 'hot',
  errored_reason  text,
  attempts        smallint NOT NULL DEFAULT 0,

  -- output
  mp4_url         text,
  mp4_540_url     text,                            -- mobile-net fallback
  thumb_url       text,
  width           integer,
  height          integer,
  size_bytes      bigint,

  -- counters
  view_count      bigint NOT NULL DEFAULT 0,
  like_count      bigint NOT NULL DEFAULT 0,
  share_count     bigint NOT NULL DEFAULT 0,
  report_count    bigint NOT NULL DEFAULT 0,

  -- archive + delete
  cold_url        text,
  archived_at     timestamptz,
  deleted_at      timestamptz,
  removed_reason  text,

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CHECK (
    (source = 'live' AND stream_id IS NOT NULL)
    OR
    (source = 'vod'  AND vod_id IS NOT NULL)
  )
);

CREATE INDEX clips_creator_created_idx
  ON clips (creator_id, created_at DESC)
  WHERE deleted_at IS NULL AND status IN ('ready','archived');

CREATE INDEX clips_clipper_created_idx
  ON clips (clipper_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX clips_stream_idx
  ON clips (stream_id, created_at DESC)
  WHERE stream_id IS NOT NULL;

CREATE INDEX clips_vod_idx
  ON clips (vod_id, t_start_ms)
  WHERE vod_id IS NOT NULL;

CREATE INDEX clips_status_queue_idx
  ON clips (created_at)
  WHERE status IN ('queued','rendering');

CREATE INDEX clips_trending_idx
  ON clips ((view_count + 5*like_count + 20*share_count) DESC, created_at DESC)
  WHERE deleted_at IS NULL AND status = 'ready';

CREATE TRIGGER clips_set_updated_at
  BEFORE UPDATE ON clips
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### `clip_views`

```sql
CREATE TABLE clip_views (
  id           bigserial PRIMARY KEY,
  clip_id      uuid NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
  viewer_id    uuid REFERENCES users(id) ON DELETE SET NULL,
  -- anonymous viewers identified by hashed (ip, ua)
  viewer_hash  bytea,
  watched_ms   integer NOT NULL DEFAULT 0,
  completed    boolean NOT NULL DEFAULT false,
  source       text NOT NULL DEFAULT 'web'
               CHECK (source IN ('web','ios','android','embed','feed','search')),
  country      text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX clip_views_clip_created_idx
  ON clip_views (clip_id, created_at DESC);

CREATE INDEX clip_views_viewer_idx
  ON clip_views (viewer_id, created_at DESC)
  WHERE viewer_id IS NOT NULL;

-- Hourly aggregate via continuous aggregate
CREATE MATERIALIZED VIEW clip_views_hourly AS
SELECT clip_id,
       date_trunc('hour', created_at) AS hour,
       count(*)                       AS views,
       avg(watched_ms)::int           AS avg_watched_ms,
       count(*) FILTER (WHERE completed) AS completed
FROM clip_views
GROUP BY 1,2
WITH NO DATA;

CREATE UNIQUE INDEX ON clip_views_hourly (clip_id, hour);
```

### `clip_reports`

```sql
CREATE TYPE clip_report_reason AS ENUM (
  'sexual','violence','hate','self_harm','spam','copyright','other'
);

CREATE TYPE clip_report_status AS ENUM (
  'pending','dismissed','removed','escalated'
);

CREATE TABLE clip_reports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clip_id         uuid NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
  reporter_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  reason          clip_report_reason NOT NULL,
  detail          text,
  status          clip_report_status NOT NULL DEFAULT 'pending',
  resolution      text,
  resolved_by     uuid REFERENCES users(id) ON DELETE SET NULL,
  resolved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX clip_reports_clip_idx ON clip_reports (clip_id);
CREATE INDEX clip_reports_pending_idx
  ON clip_reports (created_at)
  WHERE status = 'pending';
```

### Counter trigger

```sql
CREATE OR REPLACE FUNCTION clips_bump_report_count() RETURNS trigger AS $$
BEGIN
  UPDATE clips SET report_count = report_count + 1
  WHERE id = NEW.clip_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clip_reports_bump
  AFTER INSERT ON clip_reports
  FOR EACH ROW EXECUTE FUNCTION clips_bump_report_count();
```

## RLS

```sql
ALTER TABLE clips         ENABLE ROW LEVEL SECURITY;
ALTER TABLE clip_views    ENABLE ROW LEVEL SECURITY;
ALTER TABLE clip_reports  ENABLE ROW LEVEL SECURITY;

-- public read once ready and not removed
CREATE POLICY clips_public_read ON clips
  FOR SELECT USING (
    deleted_at IS NULL
    AND status IN ('ready','archived')
    AND removed_reason IS NULL
  );

-- clipper or creator can edit title, thumb, delete
CREATE POLICY clips_owner_update ON clips
  FOR UPDATE USING (
    clipper_id = auth.uid() OR creator_id = auth.uid()
  )
  WITH CHECK (
    clipper_id = auth.uid() OR creator_id = auth.uid()
  );

CREATE POLICY clips_owner_delete ON clips
  FOR DELETE USING (
    clipper_id = auth.uid() OR creator_id = auth.uid()
  );

CREATE POLICY clips_service_insert ON clips
  FOR INSERT WITH CHECK (
    auth.role() = 'service_role'
    OR clipper_id = auth.uid()
  );

-- views: anyone can write (rate-limited app-side), only owner reads detailed rows
CREATE POLICY clip_views_insert_anyone ON clip_views
  FOR INSERT WITH CHECK (true);

CREATE POLICY clip_views_owner_read ON clip_views
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM clips c
            WHERE c.id = clip_views.clip_id
              AND (c.creator_id = auth.uid() OR c.clipper_id = auth.uid()))
  );

-- reports: any authenticated user can submit; only mods read
CREATE POLICY clip_reports_insert_auth ON clip_reports
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY clip_reports_mod_read ON clip_reports
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_roles r
            WHERE r.user_id = auth.uid() AND r.role IN ('mod','admin'))
  );
```

## Hot vs Cold

- `tier='hot'`: `mp4_url` + `thumb_url` on Appwrite, served via CDN.
- `tier='cold'`: `cold_url` on R2, `mp4_url` is set to the R2 public URL after promotion. The 30-day archiver runs nightly. Thumbs always live in hot bucket because they are tiny.
- `removed`: both `mp4_url` and `cold_url` are nulled; the public page renders the "removed" copy.

## Slug

Slugs are 8 char base58 (URL-safe), generated by `nanoid`-style randomness with a uniqueness retry. Collision probability at 1 M clips < 10^-9.
