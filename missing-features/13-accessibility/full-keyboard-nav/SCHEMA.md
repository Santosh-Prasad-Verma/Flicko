# Full Keyboard Navigation — Backend Schema

## 1. Tables

This feature is largely client-side. Persistent storage is limited to per-user preferences inside the existing `user_preferences.accessibility_json` JSONB column. No new tables are required for v1.

### `user_preferences.accessibility_json` — keys added

```jsonc
{
  "always_show_focus_ring": true,
  "show_shortcut_hints_in_menus": true,
  "open_help_overlay_with_question_mark": true,
  "shortcut_overrides": {
    "send_message": "Ctrl+Enter",
    "open_quick_switcher": "Ctrl+K"
  }
}
```

The `shortcut_overrides` map is reserved for v2; v1 ignores it on read.

## 2. RLS Policies

Existing `user_preferences` RLS — `user_id = auth.uid()`. No changes.

## 3. Triggers

A simple JSON-shape sanity check on write (advisory only):

```sql
ALTER TABLE user_preferences
  ADD CONSTRAINT chk_keyboard_shortcuts_object
  CHECK (
    (accessibility_json->'shortcut_overrides') IS NULL
    OR jsonb_typeof(accessibility_json->'shortcut_overrides') = 'object'
  ) NOT VALID;
```

## 4. Migration File

Path: `supabase/migrations/256_accessibility_keyboard.up.sql`
Down: `supabase/migrations/256_accessibility_keyboard.down.sql`

```sql
-- up
BEGIN;

ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

UPDATE user_preferences
   SET accessibility_json = accessibility_json
       || jsonb_build_object(
            'always_show_focus_ring', COALESCE((accessibility_json->>'always_show_focus_ring')::boolean, true),
            'show_shortcut_hints_in_menus', COALESCE((accessibility_json->>'show_shortcut_hints_in_menus')::boolean, true),
            'open_help_overlay_with_question_mark', COALESCE((accessibility_json->>'open_help_overlay_with_question_mark')::boolean, true)
          )
 WHERE accessibility_json->>'always_show_focus_ring' IS NULL
    OR accessibility_json->>'show_shortcut_hints_in_menus' IS NULL
    OR accessibility_json->>'open_help_overlay_with_question_mark' IS NULL;

ALTER TABLE user_preferences
  ADD CONSTRAINT chk_keyboard_shortcuts_object
  CHECK (
    (accessibility_json->'shortcut_overrides') IS NULL
    OR jsonb_typeof(accessibility_json->'shortcut_overrides') = 'object'
  ) NOT VALID;

CREATE OR REPLACE VIEW v_accessibility_keyboard_adoption AS
SELECT
  COUNT(*) FILTER (WHERE (accessibility_json->>'always_show_focus_ring')::boolean = true)::bigint AS focus_ring_users,
  COUNT(*) FILTER (WHERE (accessibility_json->>'show_shortcut_hints_in_menus')::boolean = true)::bigint AS hint_users,
  COUNT(*)::bigint AS total
  FROM user_preferences
 WHERE accessibility_json ? 'always_show_focus_ring';

GRANT SELECT ON v_accessibility_keyboard_adoption TO service_role;

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE user_preferences DROP CONSTRAINT IF EXISTS chk_keyboard_shortcuts_object;
DROP VIEW IF EXISTS v_accessibility_keyboard_adoption;
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

Not applicable.

## 9. Data Retention

- Preferences deleted via existing user-deletion cascade.

## 10. Sample Queries

```sql
-- Read keyboard prefs
SELECT
  (accessibility_json->>'always_show_focus_ring')::boolean        AS always_show,
  (accessibility_json->>'show_shortcut_hints_in_menus')::boolean  AS show_hints
  FROM user_preferences
 WHERE user_id = $1;

-- Adoption rollup
SELECT * FROM v_accessibility_keyboard_adoption;

-- Set preference
UPDATE user_preferences
   SET accessibility_json = jsonb_set(
         accessibility_json,
         '{always_show_focus_ring}',
         to_jsonb($2::boolean),
         true
       ),
       updated_at = now()
 WHERE user_id = $1;
```
