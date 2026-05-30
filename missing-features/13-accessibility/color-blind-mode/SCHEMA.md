# Color Blind Mode — Backend Schema

## 1. Tables

This feature is client-driven. The only persisted data lives in `user_preferences.accessibility_json`. No new tables.

### `user_preferences.accessibility_json` — keys added

```jsonc
{
  "color_blind_preset": "off",       // "off" | "auto" | "protan" | "deutan" | "tritan"
  "cvd_shape_supplement": true,
  "cvd_apply_filter": true
}
```

## 2. RLS Policies

Existing `user_preferences` RLS — `user_id = auth.uid()`. No changes.

## 3. Triggers

```sql
ALTER TABLE user_preferences
  ADD CONSTRAINT chk_color_blind_preset
  CHECK (
    (accessibility_json->>'color_blind_preset') IS NULL OR
    (accessibility_json->>'color_blind_preset') IN ('off','auto','protan','deutan','tritan')
  ) NOT VALID;
```

## 4. Migration File

Path: `supabase/migrations/259_accessibility_color_blind.up.sql`
Down: `supabase/migrations/259_accessibility_color_blind.down.sql`

```sql
-- up
BEGIN;

ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

UPDATE user_preferences
   SET accessibility_json = accessibility_json
       || jsonb_build_object(
            'color_blind_preset',     COALESCE(accessibility_json->>'color_blind_preset', 'off'),
            'cvd_shape_supplement',   COALESCE((accessibility_json->>'cvd_shape_supplement')::boolean, true),
            'cvd_apply_filter',       COALESCE((accessibility_json->>'cvd_apply_filter')::boolean, true)
          )
 WHERE accessibility_json->>'color_blind_preset' IS NULL
    OR accessibility_json->>'cvd_shape_supplement' IS NULL
    OR accessibility_json->>'cvd_apply_filter' IS NULL;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_color_blind_preset
  CHECK (
    (accessibility_json->>'color_blind_preset') IN ('off','auto','protan','deutan','tritan')
  ) NOT VALID;

CREATE OR REPLACE VIEW v_accessibility_cvd_adoption AS
SELECT accessibility_json->>'color_blind_preset' AS preset,
       COUNT(*)::bigint AS users
  FROM user_preferences
 WHERE accessibility_json ? 'color_blind_preset'
 GROUP BY 1;

GRANT SELECT ON v_accessibility_cvd_adoption TO service_role;

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_color_blind_preset;
DROP VIEW IF EXISTS v_accessibility_cvd_adoption;
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
-- Read CVD prefs
SELECT
  accessibility_json->>'color_blind_preset'                AS preset,
  (accessibility_json->>'cvd_shape_supplement')::boolean   AS shape,
  (accessibility_json->>'cvd_apply_filter')::boolean       AS filter
  FROM user_preferences
 WHERE user_id = $1;

-- Adoption rollup
SELECT * FROM v_accessibility_cvd_adoption ORDER BY users DESC;

-- Set preset
UPDATE user_preferences
   SET accessibility_json = jsonb_set(
         accessibility_json,
         '{color_blind_preset}',
         to_jsonb($2::text),
         true
       ),
       updated_at = now()
 WHERE user_id = $1;
```
