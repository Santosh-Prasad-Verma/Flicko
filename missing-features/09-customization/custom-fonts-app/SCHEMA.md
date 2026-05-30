# Custom Fonts — Backend Schema

## 1. Tables

### `font_choices`

```sql
CREATE TABLE font_choices (
  user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  body_family    TEXT NOT NULL DEFAULT 'Inter',
  header_family  TEXT NOT NULL DEFAULT 'Inter',
  mono_family    TEXT NOT NULL DEFAULT 'JetBrainsMono',
  use_system     BOOLEAN NOT NULL DEFAULT FALSE,
  uploaded_url   TEXT,
  uploaded_kind  TEXT CHECK (uploaded_kind IN ('ttf','otf','woff2')),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

The set of valid values for `body_family`/`header_family`/`mono_family` is enforced server-side by an in-process whitelist (kept in code, not DB) so adding fonts is a code change, not a DB migration.

## 2. RLS Policies

```sql
ALTER TABLE font_choices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Self read"
  ON font_choices FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Self write"
  ON font_choices FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER font_choices_set_updated_at
  BEFORE UPDATE ON font_choices
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/208_font_choices.up.sql`
Down: `supabase/migrations/208_font_choices.down.sql`

```sql
-- up
BEGIN;
CREATE TABLE font_choices (
  user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  body_family    TEXT NOT NULL DEFAULT 'Inter',
  header_family  TEXT NOT NULL DEFAULT 'Inter',
  mono_family    TEXT NOT NULL DEFAULT 'JetBrainsMono',
  use_system     BOOLEAN NOT NULL DEFAULT FALSE,
  uploaded_url   TEXT,
  uploaded_kind  TEXT CHECK (uploaded_kind IN ('ttf','otf','woff2')),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE font_choices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Self read on font_choices" ON font_choices FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Self write on font_choices" ON font_choices FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON font_choices TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `font_choice:<uid>` | row JSON | 1h |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

(v2)
- Bucket: `user_fonts`
- Allowed MIME: `font/ttf`, `font/otf`, `font/woff2`
- Max file size: 2 MB
- Permission: `read("user:{ownerId}")`, `write("user:{ownerId}")`

## 9. Data Retention

- Persistent for the user's lifetime.
- v2 uploaded fonts kept until user deletes; cascade on user delete.

## 10. Sample Queries

```sql
-- read effective font choice
SELECT body_family, header_family, mono_family, use_system, uploaded_url
FROM font_choices
WHERE user_id = $1;

-- adoption (admin)
SELECT body_family, count(*)
FROM font_choices
GROUP BY 1
ORDER BY count(*) DESC;
```
