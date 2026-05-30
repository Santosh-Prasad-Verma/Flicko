# Message Themes — Backend Schema

## 1. Tables

### `message_theme_settings`

```sql
CREATE TABLE message_theme_settings (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  shape       TEXT NOT NULL DEFAULT 'square'
              CHECK (shape IN ('square','rounded','classic')),
  show_tail   BOOLEAN NOT NULL DEFAULT FALSE,
  density     TEXT NOT NULL DEFAULT 'cozy'
              CHECK (density IN ('compact','cozy','comfy')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE message_theme_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Self read"
  ON message_theme_settings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Self upsert"
  ON message_theme_settings FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Self update"
  ON message_theme_settings FOR UPDATE
  USING (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER message_theme_settings_set_updated_at
  BEFORE UPDATE ON message_theme_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Tail off when shape is classic.
CREATE OR REPLACE FUNCTION mt_normalize_tail() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.shape = 'classic' THEN
    NEW.show_tail := FALSE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER message_theme_settings_normalize
  BEFORE INSERT OR UPDATE ON message_theme_settings
  FOR EACH ROW EXECUTE FUNCTION mt_normalize_tail();
```

## 4. Migration File

Path: `supabase/migrations/210_message_theme_settings.up.sql`
Down: `supabase/migrations/210_message_theme_settings.down.sql`

```sql
-- up
BEGIN;
CREATE TABLE message_theme_settings (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  shape       TEXT NOT NULL DEFAULT 'square'
              CHECK (shape IN ('square','rounded','classic')),
  show_tail   BOOLEAN NOT NULL DEFAULT FALSE,
  density     TEXT NOT NULL DEFAULT 'cozy'
              CHECK (density IN ('compact','cozy','comfy')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE message_theme_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Self read on message_theme_settings" ON message_theme_settings
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Self upsert on message_theme_settings" ON message_theme_settings
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Self update on message_theme_settings" ON message_theme_settings
  FOR UPDATE USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON message_theme_settings TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `msg_theme:<uid>` | row JSON | 1h |

## 6. Search Index (Meilisearch)

Not applicable.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

Not applicable.

## 9. Data Retention

- Persistent for the user's lifetime.
- Cascade on user delete.

## 10. Sample Queries

```sql
-- read effective settings
SELECT shape, show_tail, density
FROM message_theme_settings
WHERE user_id = $1;

-- adoption rollup
SELECT shape, density, count(*)
FROM message_theme_settings
GROUP BY 1, 2
ORDER BY count(*) DESC;
```
