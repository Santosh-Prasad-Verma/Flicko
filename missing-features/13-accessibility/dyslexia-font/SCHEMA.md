# Dyslexia Font — Backend Schema

## 1. Tables

This feature is client-driven. The only persisted data lives in `user_preferences.accessibility_json` (already added in migration 252/253). This migration only seeds keys and adds validation triggers.

### `user_preferences.accessibility_json` — keys added

```jsonc
{
  "reader_font_family": "system",       // "system" | "open_dyslexic" | "atkinson"
  "reader_line_height": 1.4,            // float, 1.2 - 2.0
  "reader_letter_spacing": 0.0          // float, 0.0 - 0.08
}
```

## 2. RLS Policies

Existing `user_preferences` RLS — `user_id = auth.uid()`. No changes.

## 3. Triggers

Server-side range validation via a CHECK on JSONB:

```sql
ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_font_family
  CHECK (
    (accessibility_json->>'reader_font_family') IS NULL OR
    (accessibility_json->>'reader_font_family') IN ('system', 'open_dyslexic', 'atkinson')
  ) NOT VALID;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_line_height
  CHECK (
    (accessibility_json->>'reader_line_height') IS NULL OR
    ((accessibility_json->>'reader_line_height')::numeric BETWEEN 1.2 AND 2.0)
  ) NOT VALID;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_letter_spacing
  CHECK (
    (accessibility_json->>'reader_letter_spacing') IS NULL OR
    ((accessibility_json->>'reader_letter_spacing')::numeric BETWEEN 0.0 AND 0.08)
  ) NOT VALID;
```

`NOT VALID` keeps existing rows from blocking the migration; we validate later in a follow-up online task.

## 4. Migration File

Path: `supabase/migrations/254_accessibility_reader_font.up.sql`
Down: `supabase/migrations/254_accessibility_reader_font.down.sql`

```sql
-- up
BEGIN;

-- Defensive: ensure column exists
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

-- Backfill defaults for existing rows
UPDATE user_preferences
   SET accessibility_json = accessibility_json
       || jsonb_build_object(
            'reader_font_family',     COALESCE(accessibility_json->>'reader_font_family', 'system'),
            'reader_line_height',     COALESCE((accessibility_json->>'reader_line_height')::numeric, 1.4),
            'reader_letter_spacing',  COALESCE((accessibility_json->>'reader_letter_spacing')::numeric, 0.0)
          )
 WHERE accessibility_json->>'reader_font_family' IS NULL
    OR accessibility_json->>'reader_line_height' IS NULL
    OR accessibility_json->>'reader_letter_spacing' IS NULL;

-- Range checks (NOT VALID to keep migration cheap)
ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_font_family
  CHECK (
    (accessibility_json->>'reader_font_family') IN ('system', 'open_dyslexic', 'atkinson')
  ) NOT VALID;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_line_height
  CHECK (
    ((accessibility_json->>'reader_line_height')::numeric BETWEEN 1.2 AND 2.0)
  ) NOT VALID;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_reader_letter_spacing
  CHECK (
    ((accessibility_json->>'reader_letter_spacing')::numeric BETWEEN 0.0 AND 0.08)
  ) NOT VALID;

-- Adoption analytics
CREATE OR REPLACE VIEW v_accessibility_reader_font_adoption AS
SELECT accessibility_json->>'reader_font_family' AS family,
       COUNT(*)::bigint AS users
  FROM user_preferences
 WHERE accessibility_json ? 'reader_font_family'
 GROUP BY 1;

GRANT SELECT ON v_accessibility_reader_font_adoption TO service_role;

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_reader_font_family;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_reader_line_height;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_reader_letter_spacing;
DROP VIEW IF EXISTS v_accessibility_reader_font_adoption;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `a11y:prefs:<user_id>` | full JSON of `accessibility_json` | 5m (shared) |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable. Fonts are bundled in-app, not served from storage.

## 9. Data Retention

- Preferences deleted via existing user-deletion cascade.

## 10. Sample Queries

```sql
-- Read current font prefs
SELECT
  accessibility_json->>'reader_font_family'                      AS family,
  (accessibility_json->>'reader_line_height')::numeric           AS line_height,
  (accessibility_json->>'reader_letter_spacing')::numeric        AS letter_spacing
FROM user_preferences
WHERE user_id = $1;

-- Adoption rollup
SELECT * FROM v_accessibility_reader_font_adoption ORDER BY users DESC;

-- Update family
UPDATE user_preferences
   SET accessibility_json = jsonb_set(
         accessibility_json,
         '{reader_font_family}',
         to_jsonb($2::text),
         true
       ),
       updated_at = now()
 WHERE user_id = $1;
```
