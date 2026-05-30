# Full Theme Engine — Backend Schema

## 1. Tables

### `themes`

```sql
CREATE TABLE themes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL CHECK (length(name) BETWEEN 2 AND 64),
  slug          TEXT NOT NULL UNIQUE,
  blurb         TEXT CHECK (length(blurb) <= 280),
  spec_version  SMALLINT NOT NULL DEFAULT 1,
  spec          JSONB NOT NULL,
  cover_url     TEXT,
  status        TEXT NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','published','flagged','removed')),
  vetted        BOOLEAN NOT NULL DEFAULT FALSE,
  install_count INTEGER NOT NULL DEFAULT 0,
  report_count  INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_themes_status        ON themes(status) WHERE status = 'published';
CREATE INDEX idx_themes_author        ON themes(author_id);
CREATE INDEX idx_themes_install_count ON themes(install_count DESC) WHERE status = 'published';
CREATE INDEX idx_themes_spec_gin      ON themes USING GIN (spec);
```

### `user_theme_overrides`

```sql
CREATE TABLE user_theme_overrides (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme_id    UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_theme_overrides_theme ON user_theme_overrides(theme_id);
```

### `server_theme_defaults`

```sql
CREATE TABLE server_theme_defaults (
  server_id    UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  theme_id     UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  enforced     BOOLEAN NOT NULL DEFAULT FALSE,
  set_by       UUID NOT NULL REFERENCES users(id),
  set_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `theme_reports`

```sql
CREATE TABLE theme_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_id    UUID NOT NULL REFERENCES themes(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL CHECK (reason IN ('contrast','offensive','impersonation','spam','other')),
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_theme_reports_theme ON theme_reports(theme_id);
```

## 2. RLS Policies

```sql
ALTER TABLE themes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read published"
  ON themes FOR SELECT
  USING (status = 'published' OR author_id = auth.uid() OR is_admin(auth.uid()));

CREATE POLICY "Authors can insert"
  ON themes FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Authors can update own draft"
  ON themes FOR UPDATE
  USING (author_id = auth.uid() AND status IN ('draft','published'));

ALTER TABLE user_theme_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Self read/write"
  ON user_theme_overrides FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE server_theme_defaults ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members read"
  ON server_theme_defaults FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Owners write"
  ON server_theme_defaults FOR ALL
  USING (server_id IN (SELECT id FROM servers WHERE owner_id = auth.uid()));
```

## 3. Triggers

```sql
CREATE TRIGGER themes_set_updated_at
  BEFORE UPDATE ON themes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION bump_install_count() RETURNS TRIGGER AS $$
BEGIN
  UPDATE themes SET install_count = install_count + 1 WHERE id = NEW.theme_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_override_install
  AFTER INSERT ON user_theme_overrides
  FOR EACH ROW EXECUTE FUNCTION bump_install_count();

CREATE OR REPLACE FUNCTION auto_flag_on_reports() RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT report_count FROM themes WHERE id = NEW.theme_id) >= 5 THEN
    UPDATE themes SET status = 'flagged' WHERE id = NEW.theme_id AND status = 'published';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER theme_reports_autoflag
  AFTER INSERT ON theme_reports
  FOR EACH ROW EXECUTE FUNCTION auto_flag_on_reports();
```

## 4. Migration File

Path: `supabase/migrations/205_full_theme_engine.up.sql`
Down: `supabase/migrations/205_full_theme_engine.down.sql`

```sql
-- up
BEGIN;
-- create tables themes, user_theme_overrides, server_theme_defaults, theme_reports
-- create indexes per above
-- enable RLS and policies
-- create triggers
-- grants
GRANT SELECT ON themes TO authenticated;
GRANT INSERT, UPDATE ON themes TO authenticated;
GRANT SELECT, INSERT, DELETE ON user_theme_overrides TO authenticated;
GRANT SELECT ON server_theme_defaults TO authenticated;
GRANT INSERT, UPDATE, DELETE ON server_theme_defaults TO authenticated;
GRANT INSERT ON theme_reports TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `theme:<id>` | full spec JSON | 10m |
| `theme:list:popular:p<n>` | page of 24 | 1m |
| `theme:server:<sid>` | id of server default | 5m |
| `theme:user:<uid>` | id of override | 5m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "themes",
  "primaryKey": "id",
  "searchableAttributes": ["name", "blurb", "author_handle"],
  "filterableAttributes": ["status", "vetted", "tags"],
  "sortableAttributes": ["install_count", "created_at"]
}
```

## 7. Object Storage (Appwrite)

- Bucket: `theme_covers`
- Allowed MIME: `image/webp`, `image/png`, `image/jpeg`
- Max file size: 256 KB
- Permission: `read("any")`, `write("user:{authorId}")`

## 8. Data Retention

- Hot rows: 365d in primary.
- Removed themes: keep row for 30d (audit), then hard delete cover + spec.
- GDPR delete: cascade on `users.delete`; orphan published themes are migrated to `flicko_archive` author.

## 9. Sample Queries

```sql
-- popular published themes
SELECT id, name, slug, install_count, cover_url
FROM themes
WHERE status = 'published'
ORDER BY install_count DESC
LIMIT 24;

-- user effective theme: override > server > app default
WITH override AS (
  SELECT t.* FROM themes t
  JOIN user_theme_overrides o ON o.theme_id = t.id
  WHERE o.user_id = $1
)
SELECT * FROM override
UNION ALL
SELECT t.* FROM themes t
JOIN server_theme_defaults d ON d.theme_id = t.id
WHERE d.server_id = $2 AND NOT EXISTS (SELECT 1 FROM override)
LIMIT 1;
```
