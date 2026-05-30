# High Contrast Mode — Backend Schema

## 1. Tables

This feature is client-driven. The only persisted data is the user preference, written into the existing `user_preferences.accessibility_json` JSONB column.

If migration `252` (from `screen-reader-full`) has not yet run, this feature's migration `253` adds the column instead.

### `user_preferences.accessibility_json` (existing JSONB) — keys added

```jsonc
{
  "high_contrast_mode": "auto",          // "off" | "auto" | "on_light" | "on_dark"
  "neutralize_server_accents": true
}
```

## 2. RLS Policies

Already enforced on `user_preferences` (existing policies — `user_id = auth.uid()`).

No new tables → no new policies.

## 3. Triggers

Reuses existing `user_preferences_set_updated_at`.

## 4. Migration File

Path: `supabase/migrations/253_accessibility_high_contrast.up.sql`
Down: `supabase/migrations/253_accessibility_high_contrast.down.sql`

```sql
-- up
BEGIN;

-- Idempotent column add
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_user_prefs_accessibility_gin
  ON user_preferences USING GIN (accessibility_json);

-- Backfill defaults for existing rows that don't have these keys
UPDATE user_preferences
   SET accessibility_json = accessibility_json
       || jsonb_build_object(
            'high_contrast_mode', COALESCE(accessibility_json->>'high_contrast_mode', 'off'),
            'neutralize_server_accents', COALESCE((accessibility_json->>'neutralize_server_accents')::boolean, true)
          )
 WHERE accessibility_json->>'high_contrast_mode' IS NULL
    OR accessibility_json->>'neutralize_server_accents' IS NULL;

-- Optional view for analytics
CREATE OR REPLACE VIEW v_accessibility_hc_adoption AS
SELECT accessibility_json->>'high_contrast_mode' AS mode,
       COUNT(*)::bigint AS users
  FROM user_preferences
 WHERE accessibility_json ? 'high_contrast_mode'
 GROUP BY 1;

GRANT SELECT ON v_accessibility_hc_adoption TO service_role;

COMMIT;
```

```sql
-- down
BEGIN;
DROP VIEW IF EXISTS v_accessibility_hc_adoption;
-- Leave the column and JSON keys untouched to preserve user prefs.
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `a11y:prefs:<user_id>` | full JSON of `accessibility_json` | 5m (shared with screen-reader feature) |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable.

## 9. Data Retention

- Preference deleted via existing user-deletion cascade.

## 10. Sample Queries

```sql
-- Read current HC mode
SELECT accessibility_json->>'high_contrast_mode' AS mode
  FROM user_preferences
 WHERE user_id = $1;

-- Adoption rollup
SELECT * FROM v_accessibility_hc_adoption ORDER BY users DESC;

-- Set mode
UPDATE user_preferences
   SET accessibility_json = jsonb_set(
         accessibility_json,
         '{high_contrast_mode}',
         to_jsonb($2::text),
         true
       ),
       updated_at = now()
 WHERE user_id = $1;
```
