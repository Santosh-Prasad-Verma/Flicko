# Server Gallery — Backend Schema

## 1. Tables

### `user_galleries`

Materialized table of media items per server. Built by worker.

```sql
CREATE TABLE user_galleries (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  message_id    UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  author_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_kind    TEXT NOT NULL CHECK (media_kind IN ('image','gif','video')),
  media_url     TEXT NOT NULL,
  thumb_url     TEXT,
  width         INTEGER,
  height        INTEGER,
  duration_ms   INTEGER,
  size_bytes    BIGINT,
  alt_text      TEXT,
  nsfw          BOOLEAN NOT NULL DEFAULT false,
  status        TEXT NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','removed')),
  featured      BOOLEAN NOT NULL DEFAULT false,
  posted_at     TIMESTAMPTZ NOT NULL,
  ingested_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, message_id, media_url)
);

CREATE INDEX idx_user_galleries_server_posted ON user_galleries(server_id, posted_at DESC) WHERE status = 'visible';
CREATE INDEX idx_user_galleries_server_author ON user_galleries(server_id, author_id, posted_at DESC) WHERE status = 'visible';
CREATE INDEX idx_user_galleries_channel       ON user_galleries(channel_id, posted_at DESC) WHERE status = 'visible';
CREATE INDEX idx_user_galleries_featured      ON user_galleries(server_id) WHERE featured AND status = 'visible';
```

### `gallery_settings`

```sql
CREATE TABLE gallery_settings (
  server_id          UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled            BOOLEAN NOT NULL DEFAULT false,
  excluded_channels  UUID[] NOT NULL DEFAULT '{}',
  blur_nsfw          BOOLEAN NOT NULL DEFAULT true,
  retention_days     INTEGER NOT NULL DEFAULT 365,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `gallery_reports`

```sql
CREATE TABLE gallery_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id     UUID NOT NULL REFERENCES user_galleries(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL CHECK (reason IN ('nsfw_unmarked','copyright','hateful','spam','personal_info','other')),
  notes       TEXT,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE user_galleries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE gallery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE gallery_reports  ENABLE ROW LEVEL SECURITY;

-- Server members can read visible items in channels they can see
CREATE POLICY "Members read gallery"
  ON user_galleries FOR SELECT
  USING (
    status = 'visible'
    AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
    AND channel_id IN (SELECT channel_id FROM channel_visibility WHERE user_id = auth.uid())
  );

-- Mods can update status, feature
CREATE POLICY "Mod manage"
  ON user_galleries FOR UPDATE
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 64) = 64
    )
  );

-- Author can hide own item
CREATE POLICY "Author hide own"
  ON user_galleries FOR UPDATE
  USING (author_id = auth.uid())
  WITH CHECK (status IN ('visible','hidden'));

CREATE POLICY "Settings managers"
  ON gallery_settings FOR ALL
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 1) = 1
    )
  );

CREATE POLICY "Reports by reporter or mods"
  ON gallery_reports FOR SELECT
  USING (
    reporter_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_galleries g
      JOIN server_member_perms p ON p.server_id = g.server_id
      WHERE g.id = gallery_reports.item_id
        AND p.user_id = auth.uid() AND (p.perms & 64) = 64
    )
  );
```

## 3. Triggers

None heavy at trigger layer; ingestion is worker-driven.

## 4. Migration File

Path: `supabase/migrations/199_server_gallery.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE gallery_settings (...);
  CREATE TABLE user_galleries (...);
  CREATE TABLE gallery_reports (...);
  -- indexes, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `gallery:server:<sid>:p<n>:<filter>` | JSON list | 60s |
| `gallery:item:<id>` | JSON | 5m |
| `gallery:counts:<sid>` | counts | 5m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "gallery",
  "primaryKey": "id",
  "searchableAttributes": ["alt_text"],
  "filterableAttributes": ["server_id","channel_id","author_id","media_kind","posted_at","nsfw","status","featured"],
  "sortableAttributes": ["posted_at"]
}
```

## 7. Vector Index (Qdrant)

Optional v1.1: image embeddings for similar-look search.

## 8. Object Storage (Appwrite)

Existing message media. Gallery only references URLs.

## 9. Data Retention

- Items live as long as the source message
- Hidden items soft-stored 90 days then purged
- GDPR delete: cascade

## 10. Sample Queries

```sql
-- Newest images for server
SELECT * FROM user_galleries
WHERE server_id = $1 AND status = 'visible' AND media_kind IN ('image','gif')
ORDER BY posted_at DESC
LIMIT 60;

-- By author
SELECT * FROM user_galleries
WHERE server_id = $1 AND author_id = $2 AND status = 'visible'
ORDER BY posted_at DESC
LIMIT 60;

-- Featured
SELECT * FROM user_galleries
WHERE server_id = $1 AND featured AND status = 'visible'
ORDER BY posted_at DESC;
```
