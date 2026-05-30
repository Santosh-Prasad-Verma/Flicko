# RTL Support — Backend Schema

## 1. Tables

This feature adds two columns to existing `messages`. All other RTL behavior is in-memory or client-side. We also rely on `i18n_locales.rtl` from the `multi-language-50` migration.

### `messages` (column adds)

```sql
ALTER TABLE messages
  ADD COLUMN direction TEXT NOT NULL DEFAULT 'auto'
    CHECK (direction IN ('ltr', 'rtl', 'auto'));

ALTER TABLE messages
  ADD COLUMN direction_override TEXT
    CHECK (direction_override IN ('ltr', 'rtl', 'auto') OR direction_override IS NULL);

CREATE INDEX idx_messages_direction ON messages(direction) WHERE direction <> 'auto';
```

### `profiles` (column add)

Already has `preferred_lang` from `multi-language-50`. Add a numeric-style preference:

```sql
ALTER TABLE profiles
  ADD COLUMN use_arabic_indic_digits BOOLEAN NOT NULL DEFAULT false;
```

### `rtl_audit_log`

Tracks user-initiated direction overrides — useful for product analytics and abuse signals.

```sql
CREATE TABLE rtl_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id  UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  old_dir     TEXT,
  new_dir     TEXT NOT NULL,
  set_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rtl_audit_log_user ON rtl_audit_log(user_id);
CREATE INDEX idx_rtl_audit_log_msg  ON rtl_audit_log(message_id);
```

## 2. RLS Policies

```sql
-- messages.direction read inherits from messages RLS (already in place).
-- Override is author-only:
CREATE POLICY "Author sets direction_override"
  ON messages FOR UPDATE
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

ALTER TABLE rtl_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User reads own audit"
  ON rtl_audit_log FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Service role writes audit"
  ON rtl_audit_log FOR INSERT
  WITH CHECK (auth.role() = 'service_role');
```

## 3. Triggers

```sql
-- On insert, auto-detect direction if not provided
CREATE OR REPLACE FUNCTION messages_detect_direction()
RETURNS TRIGGER AS $$
DECLARE
  first_strong CHAR;
BEGIN
  IF NEW.direction = 'auto' OR NEW.direction IS NULL THEN
    -- Crude SQL-side fallback. Real detection happens in Go service before insert.
    -- This trigger only handles edge cases where Go path skipped detection.
    NEW.direction := CASE
      WHEN NEW.text ~ '[֐-׿؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]'
        AND NEW.text !~ '^[A-Za-z]' THEN 'rtl'
      ELSE 'ltr'
    END;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER messages_set_direction
  BEFORE INSERT ON messages
  FOR EACH ROW
  WHEN (NEW.direction IS NULL OR NEW.direction = 'auto')
  EXECUTE FUNCTION messages_detect_direction();

-- Audit trigger on direction_override change
CREATE OR REPLACE FUNCTION rtl_log_override()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.direction_override IS DISTINCT FROM OLD.direction_override THEN
    INSERT INTO rtl_audit_log(user_id, message_id, old_dir, new_dir)
    VALUES (NEW.sender_id, NEW.id, OLD.direction_override, NEW.direction_override);
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER messages_audit_dir_override
  AFTER UPDATE OF direction_override ON messages
  FOR EACH ROW EXECUTE FUNCTION rtl_log_override();
```

## 4. Migration File

Path: `supabase/migrations/259_rtl_support.up.sql`
Down: `supabase/migrations/259_rtl_support.down.sql`

```sql
-- up
BEGIN;

ALTER TABLE messages ADD COLUMN direction TEXT NOT NULL DEFAULT 'auto'
  CHECK (direction IN ('ltr', 'rtl', 'auto'));

ALTER TABLE messages ADD COLUMN direction_override TEXT
  CHECK (direction_override IN ('ltr', 'rtl', 'auto') OR direction_override IS NULL);

CREATE INDEX idx_messages_direction ON messages(direction) WHERE direction <> 'auto';

ALTER TABLE profiles ADD COLUMN use_arabic_indic_digits BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE rtl_audit_log (...);

-- triggers
CREATE FUNCTION messages_detect_direction() ...;
CREATE TRIGGER messages_set_direction ...;
CREATE FUNCTION rtl_log_override() ...;
CREATE TRIGGER messages_audit_dir_override ...;

-- backfill: existing messages get 'auto' (default)
-- no-op since DEFAULT applies

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS messages_audit_dir_override ON messages;
DROP TRIGGER IF EXISTS messages_set_direction ON messages;
DROP FUNCTION IF EXISTS rtl_log_override();
DROP FUNCTION IF EXISTS messages_detect_direction();
DROP TABLE IF EXISTS rtl_audit_log;
ALTER TABLE profiles DROP COLUMN IF EXISTS use_arabic_indic_digits;
DROP INDEX IF EXISTS idx_messages_direction;
ALTER TABLE messages DROP COLUMN IF EXISTS direction_override;
ALTER TABLE messages DROP COLUMN IF EXISTS direction;
COMMIT;
```

## 5. Cache Keys (Redis)

- No new keys. Direction lives on the message row and is hot in any cache that already caches messages.

## 6. Search Index (Meilisearch)

- Add `direction` as filterable on `messages` index. Lets us answer queries like "all my RTL messages this week".

```jsonc
{
  "uid": "messages",
  "filterableAttributes": ["channel_id", "sender_id", "direction"],
  "sortableAttributes": ["created_at"]
}
```

## 7. Vector Index (Qdrant)

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- `direction` and `direction_override` columns persist with the message indefinitely.
- `rtl_audit_log`: 90d hot, archive to R2 monthly, GDPR cascade on user delete.

## 10. Sample Queries

```sql
-- Distribution of messages by dir per locale
SELECT p.preferred_lang, m.direction, COUNT(*)
FROM messages m JOIN profiles p ON p.user_id = m.sender_id
WHERE m.created_at > now() - INTERVAL '7 days'
GROUP BY p.preferred_lang, m.direction
ORDER BY p.preferred_lang;

-- Users who frequently override direction (potential UX signal)
SELECT user_id, COUNT(*) AS overrides
FROM rtl_audit_log
WHERE set_at > now() - INTERVAL '30 days'
GROUP BY user_id
HAVING COUNT(*) >= 5
ORDER BY overrides DESC;

-- Overall RTL message share (global)
SELECT
  100.0 * SUM(CASE WHEN direction = 'rtl' THEN 1 ELSE 0 END) / COUNT(*) AS rtl_pct
FROM messages
WHERE created_at > now() - INTERVAL '24 hours';
```
