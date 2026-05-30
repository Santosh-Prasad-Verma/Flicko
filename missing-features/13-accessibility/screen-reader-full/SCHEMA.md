# Screen Reader Full Support — Backend Schema

## 1. Tables

This feature is largely client-side. We reuse two existing tables and add **one** small table for caching landmark/label overrides per locale (so we can patch announcement strings hot without an app release).

### `accessibility_announcement_overrides` (new)

```sql
CREATE TABLE accessibility_announcement_overrides (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  surface_key   TEXT NOT NULL,                 -- e.g. "MessageBubble.unread"
  locale        TEXT NOT NULL,                 -- BCP-47, e.g. "en", "es-MX"
  template      TEXT NOT NULL,                 -- ICU-style template
  notes         TEXT,
  created_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (surface_key, locale)
);

CREATE INDEX idx_a11y_overrides_locale ON accessibility_announcement_overrides(locale);
```

### `user_preferences` (existing — extended via JSON)

We add a key under the existing `accessibility_json JSONB` column rather than altering the table:

```jsonc
{
  "verbose_announcements": true,
  "live_region_mode": "polite",
  "landmark_navigation": true,
  "preferred_voice": null
}
```

If `accessibility_json` does not yet exist, migration `252` (see section 4) adds it.

## 2. RLS Policies

```sql
ALTER TABLE accessibility_announcement_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone authenticated can read overrides"
  ON accessibility_announcement_overrides FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "only staff can write overrides"
  ON accessibility_announcement_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()));
```

## 3. Triggers

```sql
CREATE TRIGGER accessibility_overrides_set_updated_at
  BEFORE UPDATE ON accessibility_announcement_overrides
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/252_accessibility_screen_reader.up.sql`
Down: `supabase/migrations/252_accessibility_screen_reader.down.sql`

```sql
-- up
BEGIN;

-- 1) Ensure user_preferences has the JSON column we extend
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS accessibility_json JSONB
  NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_user_prefs_accessibility_gin
  ON user_preferences USING GIN (accessibility_json);

-- 2) Announcement overrides
CREATE TABLE IF NOT EXISTS accessibility_announcement_overrides (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  surface_key   TEXT NOT NULL,
  locale        TEXT NOT NULL,
  template      TEXT NOT NULL,
  notes         TEXT,
  created_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (surface_key, locale)
);

CREATE INDEX IF NOT EXISTS idx_a11y_overrides_locale
  ON accessibility_announcement_overrides(locale);

ALTER TABLE accessibility_announcement_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone authenticated can read overrides"
  ON accessibility_announcement_overrides FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "only staff can write overrides"
  ON accessibility_announcement_overrides FOR ALL
  USING (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()));

CREATE TRIGGER accessibility_overrides_set_updated_at
  BEFORE UPDATE ON accessibility_announcement_overrides
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3) Seed common surfaces
INSERT INTO accessibility_announcement_overrides (surface_key, locale, template) VALUES
  ('MessageBubble.unread', 'en', 'New message from {sender}: {text}'),
  ('MessageBubble.unread', 'es', 'Nuevo mensaje de {sender}: {text}'),
  ('VoiceTile.joined',     'en', 'Joined voice channel {channel}. {count} members.'),
  ('Modal.opened',         'en', '{title}, dialog. {fieldCount} fields.'),
  ('Toast.success',        'en', '{message}'),
  ('Toast.error',          'en', 'Error: {message}. Tap to retry.')
ON CONFLICT (surface_key, locale) DO NOTHING;

COMMIT;
```

```sql
-- down
BEGIN;
DROP TABLE IF EXISTS accessibility_announcement_overrides;
-- Keep the user_preferences.accessibility_json column to avoid data loss.
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `a11y:overrides:<locale>` | JSON map `{surface_key: template}` | 10m |
| `a11y:prefs:<user_id>` | JSON of `accessibility_json` | 5m |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable.

## 9. Data Retention

- `accessibility_announcement_overrides` is reference data; retained indefinitely.
- `user_preferences.accessibility_json` follows existing user-data retention (delete on `users.delete` cascade).

## 10. Sample Queries

```sql
-- Resolve the right announcement template
SELECT template
  FROM accessibility_announcement_overrides
 WHERE surface_key = $1 AND locale = $2;

-- Read prefs
SELECT accessibility_json FROM user_preferences WHERE user_id = $1;

-- Update prefs
UPDATE user_preferences
   SET accessibility_json = accessibility_json || $2::jsonb,
       updated_at = now()
 WHERE user_id = $1;
```
