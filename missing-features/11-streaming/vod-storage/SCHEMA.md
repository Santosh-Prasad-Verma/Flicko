# VOD Storage — Database Schema

Migration: `230_vod_storage.sql`. All tables in `public` schema. UUIDs are `gen_random_uuid()` defaults. Timestamps `timestamptz`.

## Tables

### `vods`

```sql
CREATE TYPE vod_status AS ENUM (
  'pending', 'recording', 'finalizing', 'ready',
  'archived', 'errored', 'deleted'
);

CREATE TYPE vod_visibility AS ENUM (
  'public', 'unlisted', 'subscribers', 'private'
);

CREATE TYPE vod_tier AS ENUM ('hot', 'cold');

CREATE TABLE vods (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id       uuid NOT NULL REFERENCES streams(id) ON DELETE RESTRICT,
  creator_id      uuid NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  title           text NOT NULL DEFAULT '',
  description     text NOT NULL DEFAULT '',
  status          vod_status NOT NULL DEFAULT 'pending',
  visibility      vod_visibility NOT NULL DEFAULT 'public',
  tier            vod_tier NOT NULL DEFAULT 'hot',

  -- LiveKit egress
  egress_id       text,
  egress_room     text,

  -- Manifests
  hot_manifest    text,                   -- Appwrite file URL
  cold_manifest   text,                   -- R2 URL after archive
  thumbnail_url   text,                   -- 1280x720 jpg

  -- Stats (denormalized)
  duration_seconds integer NOT NULL DEFAULT 0,
  view_count       bigint  NOT NULL DEFAULT 0,
  size_bytes       bigint  NOT NULL DEFAULT 0,

  -- Whisper status
  chapters_status  text NOT NULL DEFAULT 'pending'
                   CHECK (chapters_status IN
                          ('pending','processing','ready','skipped','failed')),

  started_at      timestamptz,
  ended_at        timestamptz,
  archived_at     timestamptz,
  deleted_at      timestamptz,
  purged_at       timestamptz,

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX vods_creator_created_idx
  ON vods (creator_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX vods_status_idx ON vods (status)
  WHERE status IN ('recording','finalizing');

CREATE INDEX vods_tier_age_idx
  ON vods (tier, created_at)
  WHERE tier = 'hot' AND status = 'ready';

CREATE INDEX vods_visibility_idx ON vods (visibility)
  WHERE deleted_at IS NULL AND status = 'ready';

CREATE TRIGGER vods_set_updated_at
  BEFORE UPDATE ON vods
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### `vod_segments`

```sql
CREATE TABLE vod_segments (
  id            bigserial PRIMARY KEY,
  vod_id        uuid NOT NULL REFERENCES vods(id) ON DELETE CASCADE,
  seq           integer NOT NULL,
  duration_ms   integer NOT NULL,
  size_bytes    integer NOT NULL,
  is_gap        boolean NOT NULL DEFAULT false,
  is_muted      boolean NOT NULL DEFAULT false,

  rendition     text NOT NULL DEFAULT '720p30'
                CHECK (rendition IN ('1080p60','720p30','480p30','audio')),

  hot_url       text,
  hot_etag      text,
  cold_url      text,
  cold_etag     text,
  archived_at   timestamptz,

  created_at    timestamptz NOT NULL DEFAULT now(),

  UNIQUE (vod_id, seq, rendition)
);

CREATE INDEX vod_segments_vod_seq_idx
  ON vod_segments (vod_id, rendition, seq);

CREATE INDEX vod_segments_pending_archive_idx
  ON vod_segments (vod_id)
  WHERE archived_at IS NULL;
```

### `vod_chapters`

```sql
CREATE TABLE vod_chapters (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vod_id       uuid NOT NULL REFERENCES vods(id) ON DELETE CASCADE,
  t_start_ms   integer NOT NULL,
  t_end_ms     integer NOT NULL,
  title        text NOT NULL,
  source       text NOT NULL DEFAULT 'whisper'
               CHECK (source IN ('whisper','manual','hybrid')),
  confidence   real NOT NULL DEFAULT 0.0,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CHECK (t_end_ms > t_start_ms)
);

CREATE INDEX vod_chapters_vod_t_idx
  ON vod_chapters (vod_id, t_start_ms);
```

## Row Level Security

```sql
ALTER TABLE vods            ENABLE ROW LEVEL SECURITY;
ALTER TABLE vod_segments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE vod_chapters    ENABLE ROW LEVEL SECURITY;

-- vods: public read for public+ready, creator full access
CREATE POLICY vods_public_read ON vods
  FOR SELECT USING (
    deleted_at IS NULL
    AND status = 'ready'
    AND (
      visibility = 'public'
      OR (visibility = 'unlisted')                    -- via direct link only
      OR (visibility = 'subscribers'
          AND EXISTS (SELECT 1 FROM subscriptions s
                      WHERE s.subscriber_id = auth.uid()
                        AND s.creator_id = vods.creator_id
                        AND s.status = 'active'))
      OR creator_id = auth.uid()
    )
  );

CREATE POLICY vods_creator_write ON vods
  FOR UPDATE USING (creator_id = auth.uid())
  WITH CHECK (creator_id = auth.uid());

CREATE POLICY vods_creator_delete ON vods
  FOR DELETE USING (creator_id = auth.uid());

CREATE POLICY vods_service_insert ON vods
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- segments: only via vod join, never directly readable
CREATE POLICY vod_segments_via_vod ON vod_segments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM vods v WHERE v.id = vod_segments.vod_id)
  );

CREATE POLICY vod_segments_service_write ON vod_segments
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- chapters: same visibility as the parent vod
CREATE POLICY vod_chapters_via_vod ON vod_chapters
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM vods v WHERE v.id = vod_chapters.vod_id)
  );

CREATE POLICY vod_chapters_creator_write ON vod_chapters
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM vods v
            WHERE v.id = vod_chapters.vod_id
              AND v.creator_id = auth.uid())
  );
```

## Hot vs Cold

- `tier='hot'`: `vod_segments.hot_url` populated, served via Appwrite CDN. `cold_url` null until archive.
- `tier='cold'`: archiver swaps `cold_url` per segment, then sets `vods.cold_manifest` and `vods.tier='cold'`. The hot rows are kept in the DB but `hot_url` is set null after Appwrite delete to free quota tracking.
- Manifest URL resolution at request time: `coalesce(cold_manifest, hot_manifest)`. Segments resolved client-side via the manifest itself; the API never returns segment URLs directly.

## Storage Quota View

```sql
CREATE VIEW v_creator_storage AS
SELECT
  creator_id,
  sum(size_bytes) FILTER (WHERE tier = 'hot')  AS hot_bytes,
  sum(size_bytes) FILTER (WHERE tier = 'cold') AS cold_bytes,
  count(*) FILTER (WHERE status = 'ready')     AS vods_ready
FROM vods
WHERE deleted_at IS NULL
GROUP BY creator_id;
```

## Cleanup

`vod_purge_worker` runs every 30 min:

```sql
SELECT id FROM vods
WHERE deleted_at IS NOT NULL
  AND deleted_at < now() - interval '24 hours'
  AND purged_at IS NULL
LIMIT 100;
```

For each, it deletes R2 + Appwrite objects, then sets `purged_at`. The row stays for legal audit.
