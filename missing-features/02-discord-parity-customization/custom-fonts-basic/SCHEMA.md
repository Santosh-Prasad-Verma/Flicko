# Custom Fonts (Basic) — Backend Schema

## 1. Tables

### `user_settings` (existing — extended)

```sql
ALTER TABLE user_settings
  ADD COLUMN font_family TEXT NOT NULL DEFAULT 'inter';

ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_font_family_allowed
    CHECK (font_family IN (
      'inter','roboto','opendyslexic','atkinson',
      'jetbrains_mono','lora','comfortaa'
    ));
```

The whitelist is duplicated (Postgres CHECK + Go validator + Flutter catalog) on purpose. Each layer can refuse independently. Adding a new font means a coordinated migration + backend release + client release.

### `font_family_audit` (optional, analytics)

```sql
CREATE TABLE font_family_audit (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_family  TEXT,
  new_family  TEXT NOT NULL,
  source      TEXT NOT NULL CHECK (source IN ('settings','onboarding','reset','migration')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_font_audit_user    ON font_family_audit(user_id);
CREATE INDEX idx_font_audit_created ON font_family_audit(created_at DESC);
CREATE INDEX idx_font_audit_new     ON font_family_audit(new_family);
```

Wiped after 90 days by existing `cleanup_audit_logs()` cron.

### `font_catalog` (server-authoritative metadata, optional)

Useful for shipping new fonts to clients before app update. Read-only for clients.

```sql
CREATE TABLE font_catalog (
  id                  TEXT PRIMARY KEY,            -- e.g. 'inter'
  display_name        TEXT NOT NULL,
  family_css          TEXT NOT NULL,
  category            TEXT NOT NULL CHECK (category IN ('sans','serif','mono','display','accessible')),
  bundled_in_min_app  TEXT NOT NULL,               -- semver, e.g. '2026.05.0'
  dyslexia_friendly   BOOLEAN NOT NULL DEFAULT FALSE,
  license             TEXT NOT NULL,
  enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  position            INTEGER NOT NULL DEFAULT 0
);
```

Seed rows for the 7 v1 fonts inserted by the migration.

## 2. RLS Policies

```sql
-- user_settings already has RLS; the new column piggybacks.
-- For font_family_audit:

ALTER TABLE font_family_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own font audit"
  ON font_family_audit FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "service role inserts"
  ON font_family_audit FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- font_catalog: read-only for everyone, service-role write
ALTER TABLE font_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone reads catalog"
  ON font_catalog FOR SELECT
  USING (enabled = TRUE);

CREATE POLICY "service role manages catalog"
  ON font_catalog FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
```

## 3. Triggers

```sql
CREATE OR REPLACE FUNCTION fn_font_family_audit() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.font_family IS DISTINCT FROM OLD.font_family THEN
    INSERT INTO font_family_audit(user_id, old_family, new_family, source)
    VALUES (
      NEW.user_id,
      OLD.font_family,
      NEW.font_family,
      COALESCE(current_setting('flicko.font_source', true), 'settings')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_settings_font_audit
  AFTER UPDATE OF font_family ON user_settings
  FOR EACH ROW EXECUTE FUNCTION fn_font_family_audit();
```

Service sets `SET LOCAL flicko.font_source = 'onboarding'` (or 'reset', etc) within the txn.

## 4. Migration File

Path: `supabase/migrations/128_custom_fonts_basic.up.sql`
Down: `supabase/migrations/128_custom_fonts_basic.down.sql`

```sql
-- 128_custom_fonts_basic.up.sql
BEGIN;

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS font_family TEXT NOT NULL DEFAULT 'inter';

ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_font_family_allowed
    CHECK (font_family IN (
      'inter','roboto','opendyslexic','atkinson',
      'jetbrains_mono','lora','comfortaa'
    ));

CREATE TABLE IF NOT EXISTS font_catalog (
  id                  TEXT PRIMARY KEY,
  display_name        TEXT NOT NULL,
  family_css          TEXT NOT NULL,
  category            TEXT NOT NULL CHECK (category IN ('sans','serif','mono','display','accessible')),
  bundled_in_min_app  TEXT NOT NULL,
  dyslexia_friendly   BOOLEAN NOT NULL DEFAULT FALSE,
  license             TEXT NOT NULL,
  enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  position            INTEGER NOT NULL DEFAULT 0
);

INSERT INTO font_catalog (id, display_name, family_css, category, bundled_in_min_app, dyslexia_friendly, license, position) VALUES
  ('inter',          'Inter',                'Inter',          'sans',       '2026.05.0', FALSE, 'OFL-1.1',   1),
  ('roboto',         'Roboto',               'Roboto',         'sans',       '2026.05.0', FALSE, 'Apache-2.0',2),
  ('opendyslexic',   'OpenDyslexic',         'OpenDyslexic',   'accessible', '2026.05.0', TRUE,  'OFL-1.1',   3),
  ('atkinson',       'Atkinson Hyperlegible','Atkinson',       'accessible', '2026.05.0', TRUE,  'OFL-1.1',   4),
  ('jetbrains_mono', 'JetBrains Mono',       'JetBrainsMono',  'mono',       '2026.05.0', FALSE, 'OFL-1.1',   5),
  ('lora',           'Lora',                 'Lora',           'serif',      '2026.05.0', FALSE, 'OFL-1.1',   6),
  ('comfortaa',      'Comfortaa',            'Comfortaa',      'display',    '2026.05.0', FALSE, 'OFL-1.1',   7);

CREATE TABLE IF NOT EXISTS font_family_audit (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_family  TEXT,
  new_family  TEXT NOT NULL,
  source      TEXT NOT NULL CHECK (source IN ('settings','onboarding','reset','migration')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_font_audit_user    ON font_family_audit(user_id);
CREATE INDEX idx_font_audit_created ON font_family_audit(created_at DESC);
CREATE INDEX idx_font_audit_new     ON font_family_audit(new_family);

ALTER TABLE font_family_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE font_catalog       ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own font audit" ON font_family_audit FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "service role inserts" ON font_family_audit FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "anyone reads catalog" ON font_catalog FOR SELECT
  USING (enabled = TRUE);

CREATE POLICY "service role manages catalog" ON font_catalog FOR ALL
  USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION fn_font_family_audit() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.font_family IS DISTINCT FROM OLD.font_family THEN
    INSERT INTO font_family_audit(user_id, old_family, new_family, source)
    VALUES (
      NEW.user_id, OLD.font_family, NEW.font_family,
      COALESCE(current_setting('flicko.font_source', true), 'settings')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_settings_font_audit
  AFTER UPDATE OF font_family ON user_settings
  FOR EACH ROW EXECUTE FUNCTION fn_font_family_audit();

GRANT SELECT ON font_catalog TO authenticated, anon;
GRANT SELECT, INSERT ON font_family_audit TO authenticated;

COMMIT;
```

```sql
-- 128_custom_fonts_basic.down.sql
BEGIN;
DROP TRIGGER IF EXISTS user_settings_font_audit ON user_settings;
DROP FUNCTION IF EXISTS fn_font_family_audit;
DROP TABLE IF EXISTS font_family_audit;
DROP TABLE IF EXISTS font_catalog;
ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_font_family_allowed;
ALTER TABLE user_settings DROP COLUMN IF EXISTS font_family;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `user:settings:{user_id}` | JSON of full user_settings (existing) | 5m |
| `font:catalog:v1` | JSON list of enabled font_catalog rows | 24h |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable. Fonts are bundled in the Flutter app, not served by us.

## 9. Data Retention

- `user_settings.font_family`: lifetime of account; cascade on user delete.
- `font_family_audit`: 90 days, then truncated by existing nightly job.
- `font_catalog`: append/edit only by service role; effectively permanent.
- GDPR export: include `font_family` under "preferences"; include audit rows under "activity log".

## 10. Sample Queries

```sql
-- read font for a single user (handler hot path)
SELECT font_family
FROM user_settings
WHERE user_id = $1;

-- top fonts in production
SELECT font_family, COUNT(*) AS users
FROM user_settings
GROUP BY font_family
ORDER BY users DESC;

-- accessibility uptake — share of users on dyslexia-friendly fonts
SELECT
  COUNT(*) FILTER (WHERE font_family IN ('opendyslexic','atkinson'))::float
  / NULLIF(COUNT(*),0) AS share_dyslexia_fonts
FROM user_settings;

-- catalog read for clients (cached)
SELECT id, display_name, family_css, category, dyslexia_friendly, position
FROM font_catalog
WHERE enabled
ORDER BY position;

-- changes per source over last 7 days
SELECT source, COUNT(*) FROM font_family_audit
WHERE created_at > now() - INTERVAL '7 days'
GROUP BY source;
```
