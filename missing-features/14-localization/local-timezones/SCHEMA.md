# Local Timezones — Backend Schema

## 1. Tables

### `profiles` (column add)

```sql
ALTER TABLE profiles
  ADD COLUMN timezone TEXT NOT NULL DEFAULT 'UTC',
  ADD COLUMN timezone_auto_detect BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN timezone_last_changed_at TIMESTAMPTZ;

CREATE INDEX idx_profiles_timezone ON profiles(timezone);
ALTER TABLE profiles
  ADD CONSTRAINT profiles_timezone_format
    CHECK (timezone ~ '^[A-Za-z_]+/[A-Za-z_]+(/[A-Za-z_]+)?$|^UTC$|^Etc/GMT[+-]?\d+$');
```

### `timezone_aliases`

A small mapping for common requested aliases (e.g. user types "Tokyo" → `Asia/Tokyo`).

```sql
CREATE TABLE timezone_aliases (
  alias       TEXT PRIMARY KEY,                 -- 'Tokyo', 'PST', 'EST'
  iana        TEXT NOT NULL,                    -- 'Asia/Tokyo', 'America/Los_Angeles' (PT-aware)
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `tz_audit_log`

Tracks user-initiated TZ changes (auto-detect changes don't log; only manual).

```sql
CREATE TABLE tz_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_tz      TEXT NOT NULL,
  new_tz      TEXT NOT NULL,
  source      TEXT NOT NULL,                    -- 'manual' | 'auto' | 'travel_prompt'
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tz_audit_log_user ON tz_audit_log(user_id);
```

## 2. RLS Policies

```sql
-- profile.timezone read inherits existing profiles RLS.
-- Public reads timezone_aliases:
ALTER TABLE timezone_aliases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public reads timezone aliases"
  ON timezone_aliases FOR SELECT USING (true);
CREATE POLICY "Admins manage timezone aliases"
  ON timezone_aliases FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- tz_audit_log: user reads own
ALTER TABLE tz_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "User reads own TZ audit"
  ON tz_audit_log FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Service role writes TZ audit"
  ON tz_audit_log FOR INSERT WITH CHECK (auth.role() = 'service_role');
```

## 3. Triggers

```sql
-- Audit on profile.timezone change
CREATE OR REPLACE FUNCTION tz_audit_change() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.timezone IS DISTINCT FROM OLD.timezone THEN
    INSERT INTO tz_audit_log(user_id, old_tz, new_tz, source)
    VALUES (NEW.user_id, OLD.timezone, NEW.timezone, 'manual');
    NEW.timezone_last_changed_at := now();
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_audit_tz
  BEFORE UPDATE OF timezone ON profiles
  FOR EACH ROW EXECUTE FUNCTION tz_audit_change();
```

## 4. Migration File

Path: `supabase/migrations/261_local_timezones.up.sql`
Down: `supabase/migrations/261_local_timezones.down.sql`

```sql
-- up
BEGIN;

ALTER TABLE profiles
  ADD COLUMN timezone TEXT NOT NULL DEFAULT 'UTC',
  ADD COLUMN timezone_auto_detect BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN timezone_last_changed_at TIMESTAMPTZ;

CREATE INDEX idx_profiles_timezone ON profiles(timezone);
ALTER TABLE profiles
  ADD CONSTRAINT profiles_timezone_format
    CHECK (timezone ~ '^[A-Za-z_]+/[A-Za-z_]+(/[A-Za-z_]+)?$|^UTC$|^Etc/GMT[+-]?\d+$');

CREATE TABLE timezone_aliases (...);
CREATE TABLE tz_audit_log (...);

INSERT INTO timezone_aliases(alias, iana) VALUES
  ('Tokyo',         'Asia/Tokyo'),
  ('NYC',           'America/New_York'),
  ('LA',            'America/Los_Angeles'),
  ('London',        'Europe/London'),
  ('Berlin',        'Europe/Berlin'),
  ('Mumbai',        'Asia/Kolkata'),
  ('Delhi',         'Asia/Kolkata'),
  ('Sao Paulo',     'America/Sao_Paulo'),
  ('Sydney',        'Australia/Sydney'),
  ('Singapore',     'Asia/Singapore'),
  ('Hong Kong',     'Asia/Hong_Kong'),
  ('Seoul',         'Asia/Seoul');

CREATE FUNCTION tz_audit_change() ...;
CREATE TRIGGER profiles_audit_tz ...;

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS profiles_audit_tz ON profiles;
DROP FUNCTION IF EXISTS tz_audit_change();
DROP TABLE IF EXISTS tz_audit_log;
DROP TABLE IF EXISTS timezone_aliases;
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_timezone_format,
  DROP COLUMN IF EXISTS timezone_last_changed_at,
  DROP COLUMN IF EXISTS timezone_auto_detect,
  DROP COLUMN IF EXISTS timezone;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `tz:user:<user_id>` | `Asia/Tokyo` | 1h |
| `tz:aliases` | JSON map | 1d |

## 6. Search Index

Not used — TZ search runs client-side over `timezone_aliases` + IANA list (~600 zones).

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- `profiles.timezone`: with the user (deleted on user delete, FK cascade).
- `tz_audit_log`: 90d hot, monthly archive to R2; GDPR cascade.
- `timezone_aliases`: never expire.

## 10. Sample Queries

```sql
-- Distribution of users by timezone (top 20)
SELECT timezone, COUNT(*) AS users
FROM profiles
WHERE timezone IS NOT NULL
GROUP BY timezone
ORDER BY users DESC
LIMIT 20;

-- Users still on UTC default (signal: missed onboarding TZ detection)
SELECT COUNT(*) FROM profiles WHERE timezone = 'UTC';

-- Resolve alias
SELECT iana FROM timezone_aliases WHERE LOWER(alias) = LOWER($1);

-- Recent TZ flips for a user (travel signal)
SELECT old_tz, new_tz, changed_at, source
FROM tz_audit_log
WHERE user_id = $1
ORDER BY changed_at DESC
LIMIT 5;
```
