# Channel Backgrounds — Backend Schema

## 1. Tables

### `channel_backgrounds`

```sql
CREATE TABLE channel_backgrounds (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id          UUID NOT NULL UNIQUE REFERENCES channels(id) ON DELETE CASCADE,
  server_id           UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  uploader_id         UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,

  file_id_original    TEXT NOT NULL,
  file_id_mobile      TEXT,
  file_id_blurred     TEXT,
  blurhash            TEXT NOT NULL,

  width_px            INTEGER NOT NULL,
  height_px           INTEGER NOT NULL,
  bytes_original      INTEGER NOT NULL,
  mime_type           TEXT NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp')),
  sha256              TEXT NOT NULL,

  dominant_color      TEXT NOT NULL,         -- '#3A2D58'
  mean_luminance      REAL NOT NULL,         -- 0..1
  min_text_contrast   REAL,                  -- worst-case contrast vs white text
  focal_x             REAL NOT NULL DEFAULT 0.5,  -- 0..1
  focal_y             REAL NOT NULL DEFAULT 0.5,

  status              TEXT NOT NULL DEFAULT 'processing'
                       CHECK (status IN ('processing','ready','original_only','failed')),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_channel_bg_server   ON channel_backgrounds(server_id);
CREATE INDEX idx_channel_bg_uploader ON channel_backgrounds(uploader_id);
CREATE INDEX idx_channel_bg_sha      ON channel_backgrounds(sha256);
CREATE INDEX idx_channel_bg_status   ON channel_backgrounds(status) WHERE status <> 'ready';
```

### `channel_background_blob_deletions` (worker queue)

```sql
CREATE TABLE channel_background_blob_deletions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id      TEXT NOT NULL,
  enqueued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts     SMALLINT NOT NULL DEFAULT 0,
  last_error   TEXT
);

CREATE INDEX idx_bg_deletions_pending
  ON channel_background_blob_deletions(enqueued_at)
  WHERE attempts < 5;
```

### `channel_background_user_overrides` (per-user opacity per channel)

```sql
CREATE TABLE channel_background_user_overrides (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id  UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  opacity     REAL NOT NULL CHECK (opacity BETWEEN 0 AND 0.8),
  enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, channel_id)
);

CREATE INDEX idx_bg_overrides_user ON channel_background_user_overrides(user_id);
```

Global member toggle (`channel_backgrounds_enabled`) and default opacity (`channel_bg_opacity_default`) live on `user_settings` (existing).

## 2. RLS Policies

```sql
ALTER TABLE channel_backgrounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channel members can read"
  ON channel_backgrounds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_id = channel_backgrounds.server_id
        AND user_id = auth.uid()
    )
  );

CREATE POLICY "channel admins can write"
  ON channel_backgrounds FOR INSERT
  WITH CHECK (has_channel_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

CREATE POLICY "channel admins can update"
  ON channel_backgrounds FOR UPDATE
  USING (has_channel_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

CREATE POLICY "channel admins can delete"
  ON channel_backgrounds FOR DELETE
  USING (has_channel_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

ALTER TABLE channel_background_user_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users own override"
  ON channel_background_user_overrides FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

`has_channel_permission` already exists in `supabase/migrations/128_add_server_permission_function.sql` (extended for channels by this migration).

## 3. Triggers

```sql
CREATE TRIGGER channel_backgrounds_updated_at
  BEFORE UPDATE ON channel_backgrounds
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Enqueue blob deletion when row is removed
CREATE OR REPLACE FUNCTION fn_enqueue_bg_blob_delete() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO channel_background_blob_deletions(file_id) VALUES
    (OLD.file_id_original),
    (OLD.file_id_mobile),
    (OLD.file_id_blurred);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER channel_backgrounds_after_delete
  AFTER DELETE ON channel_backgrounds
  FOR EACH ROW EXECUTE FUNCTION fn_enqueue_bg_blob_delete();
```

The blob-deletion worker drains `channel_background_blob_deletions` every 60 s.

## 4. Migration File

Path: `supabase/migrations/126_channel_backgrounds.up.sql`
Down: `supabase/migrations/126_channel_backgrounds.down.sql`

```sql
-- 126_channel_backgrounds.up.sql
BEGIN;

CREATE TABLE channel_backgrounds ( /* ...as above... */ );
CREATE TABLE channel_background_blob_deletions ( /* ...as above... */ );
CREATE TABLE channel_background_user_overrides ( /* ...as above... */ );

-- indexes (see above)
-- RLS (see above)
-- functions + triggers (see above)

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS channel_backgrounds_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS channel_bg_opacity_default REAL NOT NULL DEFAULT 0.30
    CHECK (channel_bg_opacity_default BETWEEN 0 AND 0.8);

GRANT SELECT, INSERT, UPDATE, DELETE ON channel_backgrounds TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON channel_background_user_overrides TO authenticated;

COMMIT;
```

```sql
-- 126_channel_backgrounds.down.sql
BEGIN;

DROP TRIGGER IF EXISTS channel_backgrounds_after_delete ON channel_backgrounds;
DROP TRIGGER IF EXISTS channel_backgrounds_updated_at ON channel_backgrounds;
DROP FUNCTION IF EXISTS fn_enqueue_bg_blob_delete;

DROP TABLE IF EXISTS channel_background_user_overrides;
DROP TABLE IF EXISTS channel_background_blob_deletions;
DROP TABLE IF EXISTS channel_backgrounds;

ALTER TABLE user_settings DROP COLUMN IF EXISTS channel_bg_opacity_default;
ALTER TABLE user_settings DROP COLUMN IF EXISTS channel_backgrounds_enabled;

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `channel:bg:{channel_id}` | JSON of background row + URLs | 5m |
| `channel:bg:list:{server_id}` | JSON `{channel_id: bg_id}` map | 1m |
| `channel:bg:override:{user_id}:{channel_id}` | JSON override | 30m |

Invalidation on every UPDATE/DELETE through `services.cache.Invalidate()` helper.

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

- Bucket: `channel-backgrounds`
- Allowed MIME: `image/jpeg`, `image/png`, `image/webp`
- Max file size: 8 MB (admin-side limit; configured via Appwrite bucket policy).
- Permissions:
  - `read("any")` (public CDN, behind Cloudflare with signed-cookie hot-link protection).
  - `write("role:flicko_backend")` — only the Go backend service role uploads.
- Lifecycle: blobs deleted via worker queue (see triggers).
- File-id pattern: `bg_{channel_id}_{variant}` keeps it human-debuggable.

## 9. Data Retention

- Hot rows: indefinite while channel exists.
- Cold archive: not needed — image is the artifact, not historical state.
- GDPR: cascade on `users.delete` for `uploader_id` (sets to NULL, keeps image — channel owner is the data controller).
- Channel deletion → blob deletion in <24h.

## 10. Sample Queries

```sql
-- read background for a channel (handler hot path)
SELECT * FROM channel_backgrounds
WHERE channel_id = $1 AND status IN ('ready','original_only');

-- list pending variant work
SELECT id, channel_id, file_id_original
FROM channel_backgrounds
WHERE status = 'processing'
  AND updated_at < now() - INTERVAL '5 minutes';

-- top servers by background usage
SELECT s.name, COUNT(*) AS bg_count
FROM channel_backgrounds cb JOIN servers s ON s.id = cb.server_id
GROUP BY s.id, s.name
ORDER BY bg_count DESC
LIMIT 25;

-- storage cost estimate
SELECT SUM(bytes_original) / 1024.0 / 1024.0 AS mb_total
FROM channel_backgrounds;

-- pending blob cleanup
SELECT * FROM channel_background_blob_deletions
WHERE attempts < 5
ORDER BY enqueued_at ASC
LIMIT 100;
```
