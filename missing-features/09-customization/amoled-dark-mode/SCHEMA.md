# AMOLED Dark Mode — Backend Schema

## 1. Tables

AMOLED stores its preference inline on the existing `user_settings` table (a JSONB blob already used for misc per-user preferences). v1 adds a typed accessor.

### Add to `user_settings`

```sql
-- migration adds a key 'amoled' inside the existing settings jsonb.
-- shape:
-- {
--   "amoled": {
--     "enabled": true,
--     "mode": "systemDark",   -- one of always | systemDark | sunset | off
--     "lastBatterySuggestAt": "2026-05-29T18:00:00Z"
--   }
-- }
```

If `user_settings` does not exist, create it:

```sql
CREATE TABLE IF NOT EXISTS user_settings (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  settings    JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_settings_amoled
  ON user_settings ((settings->'amoled'->>'mode'));
```

## 2. RLS Policies

```sql
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Self read"
  ON user_settings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Self upsert"
  ON user_settings FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Self update"
  ON user_settings FOR UPDATE
  USING (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER user_settings_set_updated_at
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/206_amoled_pref.up.sql`
Down: `supabase/migrations/206_amoled_pref.down.sql`

```sql
-- up
BEGIN;
CREATE TABLE IF NOT EXISTS user_settings (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  settings    JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_settings_amoled
  ON user_settings ((settings->'amoled'->>'mode'));

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- policies (self read/write)
CREATE POLICY "Self read on user_settings" ON user_settings
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Self upsert on user_settings" ON user_settings
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Self update on user_settings" ON user_settings
  FOR UPDATE USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON user_settings TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `user_settings:<uid>:amoled` | `{enabled,mode}` | 30m |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable.

## 9. Data Retention

- Preference rows persist for the user's lifetime.
- GDPR delete: cascade on `users.delete`.

## 10. Sample Queries

```sql
-- read amoled pref
SELECT settings -> 'amoled' AS amoled
FROM user_settings
WHERE user_id = $1;

-- update amoled mode
UPDATE user_settings
SET settings = jsonb_set(
        coalesce(settings, '{}'::jsonb),
        '{amoled}',
        $2::jsonb,
        true)
WHERE user_id = $1
RETURNING settings -> 'amoled';

-- aggregate adoption (admin)
SELECT settings->'amoled'->>'mode' AS mode, count(*)
FROM user_settings
GROUP BY 1;
```
