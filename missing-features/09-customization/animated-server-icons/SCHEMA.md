# Animated Server Icons — Backend Schema

## 1. Tables

### `server_animated_icons`

```sql
CREATE TABLE server_animated_icons (
  server_id        UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  format           TEXT NOT NULL CHECK (format IN ('gif','lottie')),
  url              TEXT NOT NULL,
  static_url       TEXT NOT NULL,
  size_bytes       INTEGER NOT NULL CHECK (size_bytes <= 524288),
  fps              SMALLINT NOT NULL DEFAULT 24,
  duration_ms      INTEGER NOT NULL DEFAULT 0,
  photosensitive   BOOLEAN NOT NULL DEFAULT FALSE,
  enabled          BOOLEAN NOT NULL DEFAULT TRUE,
  uploaded_by      UUID NOT NULL REFERENCES users(id),
  uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_server_animated_icons_uploader
  ON server_animated_icons(uploaded_by);
```

### `server_icon_reports`

```sql
CREATE TABLE server_icon_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  reporter_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason       TEXT NOT NULL CHECK (reason IN ('photosensitive','offensive','impersonation','other')),
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE server_animated_icons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read"
  ON server_animated_icons FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Owners can write"
  ON server_animated_icons FOR ALL
  USING (server_id IN (SELECT id FROM servers WHERE owner_id = auth.uid()));

ALTER TABLE server_icon_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can report"
  ON server_icon_reports FOR INSERT
  WITH CHECK (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
    AND reporter_id = auth.uid()
  );
```

## 3. Triggers

```sql
CREATE TRIGGER server_animated_icons_set_updated_at
  BEFORE UPDATE ON server_animated_icons
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION enforce_one_icon_per_server() RETURNS TRIGGER AS $$
BEGIN
  -- Already enforced by PK; this trigger is a place to publish realtime on change.
  PERFORM pg_notify('server_icon_updated', NEW.server_id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_icon_change
  AFTER INSERT OR UPDATE ON server_animated_icons
  FOR EACH ROW EXECUTE FUNCTION enforce_one_icon_per_server();
```

## 4. Migration File

Path: `supabase/migrations/207_animated_server_icons.up.sql`
Down: `supabase/migrations/207_animated_server_icons.down.sql`

```sql
-- up
BEGIN;
-- create tables, indexes, triggers
-- enable RLS, policies
-- grants
GRANT SELECT ON server_animated_icons TO authenticated;
GRANT INSERT, UPDATE, DELETE ON server_animated_icons TO authenticated;
GRANT INSERT ON server_icon_reports TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `icon:server:<sid>` | `{format,url,static_url,enabled}` | 30m |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Object Storage (Appwrite)

- Bucket: `server_icons`
- Allowed MIME: `image/gif`, `application/json` (Lottie), plus `image/webp` for static fallbacks.
- Max file size: 512 KB animated, 32 KB static.
- Permission: `read("any")`, `write("user:{ownerId}")`.

## 8. Data Retention

- Hot rows persist until icon is removed.
- On server delete: cascade.
- Removed icons keep static fallback for 7 days as audit, then hard delete.

## 9. Sample Queries

```sql
-- read for sidebar render
SELECT format, url, static_url, enabled
FROM server_animated_icons
WHERE server_id = $1 AND enabled = true;

-- top uploaders (admin)
SELECT uploaded_by, count(*)
FROM server_animated_icons
GROUP BY 1
ORDER BY count(*) DESC
LIMIT 20;
```
