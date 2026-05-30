# Accent Colors — Backend Schema

## 1. Tables

### `user_settings` (existing — extended)

```sql
ALTER TABLE user_settings
  ADD COLUMN accent_color TEXT NOT NULL DEFAULT '#7C5CFF';

ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_accent_color_format
    CHECK (accent_color ~ '^#[0-9A-Fa-f]{6}$');

CREATE INDEX IF NOT EXISTS idx_user_settings_accent_color
  ON user_settings(accent_color);
-- low-cardinality but useful for "% of users on each color" telemetry
```

### `accent_color_audit` (new — optional, analytics-only)

```sql
CREATE TABLE accent_color_audit (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_color   TEXT,
  new_color   TEXT NOT NULL,
  source      TEXT NOT NULL CHECK (source IN ('palette','custom','reset','onboarding')),
  is_plus     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accent_audit_user    ON accent_color_audit(user_id);
CREATE INDEX idx_accent_audit_created ON accent_color_audit(created_at DESC);
CREATE INDEX idx_accent_audit_source  ON accent_color_audit(source);
```

The audit table is wiped after 90 days by the existing `cleanup_audit_logs()` cron.

## 2. RLS Policies

```sql
-- user_settings already has RLS; only the accent_color column changes nothing.
-- For accent_color_audit:

ALTER TABLE accent_color_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own accent audit"
  ON accent_color_audit FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "service role inserts"
  ON accent_color_audit FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- no UPDATE/DELETE policies — audit is append-only
```

## 3. Triggers

```sql
-- Append to audit on accent_color change
CREATE OR REPLACE FUNCTION fn_accent_color_audit() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.accent_color IS DISTINCT FROM OLD.accent_color THEN
    INSERT INTO accent_color_audit (user_id, old_color, new_color, source, is_plus)
    VALUES (
      NEW.user_id,
      OLD.accent_color,
      NEW.accent_color,
      COALESCE(current_setting('flicko.accent_source', true), 'palette'),
      COALESCE(current_setting('flicko.is_plus', true)::boolean, false)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_settings_accent_audit
  AFTER UPDATE OF accent_color ON user_settings
  FOR EACH ROW EXECUTE FUNCTION fn_accent_color_audit();
```

The Go service sets `SET LOCAL flicko.accent_source = 'custom'` (or 'palette') inside the transaction so the trigger has accurate metadata.

## 4. Migration File

Path: `supabase/migrations/125_accent_colors.up.sql`
Down: `supabase/migrations/125_accent_colors.down.sql`

```sql
-- 125_accent_colors.up.sql
BEGIN;

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS accent_color TEXT NOT NULL DEFAULT '#7C5CFF';

ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_accent_color_format
    CHECK (accent_color ~ '^#[0-9A-Fa-f]{6}$');

CREATE INDEX IF NOT EXISTS idx_user_settings_accent_color
  ON user_settings(accent_color);

CREATE TABLE IF NOT EXISTS accent_color_audit (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_color   TEXT,
  new_color   TEXT NOT NULL,
  source      TEXT NOT NULL CHECK (source IN ('palette','custom','reset','onboarding')),
  is_plus     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accent_audit_user    ON accent_color_audit(user_id);
CREATE INDEX idx_accent_audit_created ON accent_color_audit(created_at DESC);
CREATE INDEX idx_accent_audit_source  ON accent_color_audit(source);

ALTER TABLE accent_color_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own accent audit" ON accent_color_audit
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "service role inserts" ON accent_color_audit
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION fn_accent_color_audit() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.accent_color IS DISTINCT FROM OLD.accent_color THEN
    INSERT INTO accent_color_audit (user_id, old_color, new_color, source, is_plus)
    VALUES (
      NEW.user_id, OLD.accent_color, NEW.accent_color,
      COALESCE(current_setting('flicko.accent_source', true), 'palette'),
      COALESCE(current_setting('flicko.is_plus', true)::boolean, false)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_settings_accent_audit
  AFTER UPDATE OF accent_color ON user_settings
  FOR EACH ROW EXECUTE FUNCTION fn_accent_color_audit();

GRANT SELECT, INSERT ON accent_color_audit TO authenticated;

COMMIT;
```

```sql
-- 125_accent_colors.down.sql
BEGIN;
DROP TRIGGER IF EXISTS user_settings_accent_audit ON user_settings;
DROP FUNCTION IF EXISTS fn_accent_color_audit;
DROP TABLE IF EXISTS accent_color_audit;
ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_accent_color_format;
ALTER TABLE user_settings DROP COLUMN IF EXISTS accent_color;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `user:settings:{user_id}` | JSON of full user_settings row (existing) | 5m |
| `accent:palette:v1` | JSON list of 16 swatches + contrast ratios | 24h |
| `accent:stats:daily:{date}` | JSON `{ "#7C5CFF": 12345, ... }` for ops dashboard | 7d |

No new cache key needed for individual accent — it rides on `user:settings` cache.

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable — accent is a 7-byte string, no blob.

## 9. Data Retention

- `user_settings.accent_color`: retained for life of user account; reset to default on account deletion (CASCADE clears row).
- `accent_color_audit`: 90 days, then truncated by existing nightly job `cleanup_audit_logs()`.
- GDPR export: include `accent_color` under "preferences"; include audit rows under "activity log".
- GDPR delete: cascades via FK on `user_id`.

## 10. Sample Queries

```sql
-- read accent for a single user (handler hot path)
SELECT accent_color
FROM user_settings
WHERE user_id = $1;

-- top 10 most popular accents (ops dashboard)
SELECT accent_color, COUNT(*) AS users
FROM user_settings
GROUP BY accent_color
ORDER BY users DESC
LIMIT 10;

-- changes over last 7 days, by source
SELECT source, COUNT(*) AS changes
FROM accent_color_audit
WHERE created_at > now() - INTERVAL '7 days'
GROUP BY source;

-- detect users on out-of-palette colors who lost Plus
SELECT u.id
FROM user_settings u
LEFT JOIN premium_subscriptions p
       ON p.user_id = u.user_id AND p.status = 'active'
WHERE u.accent_color NOT IN ('#7C5CFF','#FF6B6B', /* ...the 16... */)
  AND p.id IS NULL;
```
