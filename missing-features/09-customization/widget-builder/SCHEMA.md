# Widget Builder — Backend Schema

## 1. Tables

### `embed_widgets`

```sql
CREATE TABLE embed_widgets (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id        UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  slug             TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL CHECK (length(name) BETWEEN 2 AND 80),
  layout           JSONB NOT NULL DEFAULT '{"blocks":[]}'::jsonb,
  theme            JSONB NOT NULL DEFAULT '{"mode":"auto","primary":"#7AA2F7"}'::jsonb,
  frame_ancestors  TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  enabled          BOOLEAN NOT NULL DEFAULT TRUE,
  created_by       UUID NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_embed_widgets_server ON embed_widgets(server_id);
CREATE INDEX idx_embed_widgets_slug   ON embed_widgets(slug);
```

### `embed_widget_views`

```sql
CREATE TABLE embed_widget_views (
  id          BIGSERIAL PRIMARY KEY,
  widget_id   UUID NOT NULL REFERENCES embed_widgets(id) ON DELETE CASCADE,
  ts_minute   TIMESTAMPTZ NOT NULL,
  count       INTEGER NOT NULL DEFAULT 0,
  UNIQUE(widget_id, ts_minute)
);

CREATE INDEX idx_embed_widget_views_widget ON embed_widget_views(widget_id, ts_minute DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE embed_widgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can read"
  ON embed_widgets FOR SELECT
  USING (server_id IN (SELECT id FROM servers WHERE owner_id = auth.uid())
         OR EXISTS (
           SELECT 1 FROM server_members sm
           WHERE sm.server_id = embed_widgets.server_id
             AND sm.user_id = auth.uid()
             AND sm.permissions @> ARRAY['manage_server']
         ));

CREATE POLICY "Owners can write"
  ON embed_widgets FOR ALL
  USING (server_id IN (SELECT id FROM servers WHERE owner_id = auth.uid()));
```

Public render is via Cloudflare Worker hitting an unauthenticated, rate-limited endpoint that bypasses RLS via service role.

## 3. Triggers

```sql
CREATE TRIGGER embed_widgets_set_updated_at
  BEFORE UPDATE ON embed_widgets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Validate layout JSON shape on insert/update.
CREATE OR REPLACE FUNCTION validate_widget_layout() RETURNS TRIGGER AS $$
BEGIN
  IF jsonb_typeof(NEW.layout->'blocks') <> 'array' THEN
    RAISE EXCEPTION 'layout.blocks must be an array';
  END IF;
  IF jsonb_array_length(NEW.layout->'blocks') > 24 THEN
    RAISE EXCEPTION 'too many blocks (max 24)';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER embed_widgets_validate
  BEFORE INSERT OR UPDATE ON embed_widgets
  FOR EACH ROW EXECUTE FUNCTION validate_widget_layout();
```

## 4. Migration File

Path: `supabase/migrations/209_widget_builder.up.sql`
Down: `supabase/migrations/209_widget_builder.down.sql`

```sql
-- up
BEGIN;
-- create tables, indexes, triggers
-- enable RLS, policies
-- grants
GRANT SELECT ON embed_widgets TO authenticated;
GRANT INSERT, UPDATE, DELETE ON embed_widgets TO authenticated;
GRANT SELECT ON embed_widgets TO service_role;
GRANT INSERT ON embed_widget_views TO service_role;
COMMIT;
```

## 5. Cache Keys

| Layer | Key | Value | TTL |
|-------|-----|-------|-----|
| Cloudflare KV | `widget:<slug>:html` | rendered HTML | 60s |
| Cloudflare KV | `widget:<slug>:meta` | JSON `{frame_ancestors}` | 5m |
| Redis (origin) | `widget:slug:<slug>` | `embed_widgets` row | 5m |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

- Bucket: `widget_assets` for banner images uploaded by builder.
- Allowed MIME: `image/webp`, `image/png`, `image/jpeg`.
- Max file size: 256 KB.

## 9. Data Retention

- Hot rows: indefinite while widget is active.
- View counts aggregated daily and trimmed monthly to 90d retention.
- Server delete cascades.

## 10. Sample Queries

```sql
-- render fetch (origin, called by edge)
SELECT slug, layout, theme, frame_ancestors
FROM embed_widgets
WHERE slug = $1 AND enabled = true;

-- daily view tally
SELECT widget_id, sum(count)
FROM embed_widget_views
WHERE ts_minute >= now() - interval '24 hours'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;

-- list widgets for a server
SELECT id, name, slug, updated_at
FROM embed_widgets
WHERE server_id = $1
ORDER BY updated_at DESC;
```
