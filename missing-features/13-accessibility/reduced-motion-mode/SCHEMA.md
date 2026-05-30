# Reduced Motion Mode — Backend Schema

## 1. Tables

This feature is client-driven. Persistent storage is per-user preferences inside the existing `user_preferences.accessibility_json` JSONB column. No new tables.

### `user_preferences.accessibility_json` — keys added

```jsonc
{
  "reduced_motion_mode": "auto",     // "off" | "auto" | "on_reduce" | "on_remove"
  "auto_pause_gifs": true
}
```

## 2. RLS Policies

Existing `user_preferences` RLS — `user_id = auth.uid()`. No changes.

## 3. Triggers

Range/value check on the JSONB:

```sql
ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reduced_motion_mode
  CHECK (
    (accessibility_json->>'reduced_motion_mode') IS NULL OR
    (accessibility_json->>'reduced_motion_mode') IN ('off','auto','on_reduce','on_remove')
  ) NOT VALID;
```

## 4. Migration File

Path: `supabase/migrations/257_accessibility_reduced_motion.up.sql`
Down: `supabase/migrations/257_accessibility_reduced_motion.down.sql`

```sql
-- up
BEGIN;

ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

UPDATE user_preferences
   SET accessibility_json = accessibility_json
       || jsonb_build_object(
            'reduced_motion_mode', COALESCE(accessibility_json->>'reduced_motion_mode', 'auto'),
            'auto_pause_gifs',     COALESCE((accessibility_json->>'auto_pause_gifs')::boolean, true)
          )
 WHERE accessibility_json->>'reduced_motion_mode' IS NULL
    OR accessibility_json->>'auto_pause_gifs' IS NULL;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reduced_motion_mode
  CHECK (
    (accessibility_json->>'reduced_motion_mode') IN ('off','auto','on_reduce','on_remove')
  ) NOT VALID;

CREATE OR REPLACE VIEW v_accessibility_reduced_motion_adoption AS
SELECT accessibility_json->>'reduced_motion_mode' AS mode,
       COUNT(*)::bigint AS users
  FROM user_preferences
 WHERE accessibility_json ? 'reduced_motion_mode'
 GROUP BY 1;

GRANT SELECT ON v_accessibility_reduced_motion_adoption TO service_role;

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_reduced_motion_mode;
DROP VIEW IF EXISTS v_accessibility_reduced_motion_adoption;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `a11y:prefs:<user_id>` | full JSON | 5m (shared) |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable.

## 9. Data Retention

- Preferences deleted via existing user-deletion cascade.

## 10. Sample Queries

```sql
-- Read current motion mode
SELECT accessibility_json->>'reduced_motion_mode' AS mode,
       (accessibility_json->>'auto_pause_gifs')::boolean AS pause_gifs
  FROM user_preferences
 WHERE user_id = $1;

-- Adoption
SELECT * FROM v_accessibility_reduced_motion_adoption ORDER BY users DESC;

-- Set mode
UPDATE user_preferences
   SET accessibility_json = jsonb_set(
         accessibility_json,
         '{reduced_motion_mode}',
         to_jsonb($2::text),
         true
       ),
       updated_at = now()
 WHERE user_id = $1;
```
