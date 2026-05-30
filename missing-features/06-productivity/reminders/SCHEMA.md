# Reminders — Backend Schema

## 1. Tables

### `reminders`

```sql
CREATE TABLE reminders (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scope        TEXT NOT NULL CHECK (scope IN ('self','channel','dm')),
  channel_id   UUID REFERENCES channels(id) ON DELETE CASCADE,
  dm_user_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  text         TEXT NOT NULL CHECK (length(text) BETWEEN 1 AND 500),
  fire_at      TIMESTAMPTZ NOT NULL,
  tz           TEXT NOT NULL DEFAULT 'UTC',
  rrule        TEXT,
  state        TEXT NOT NULL DEFAULT 'pending'
                CHECK (state IN ('pending','firing','fired','cancelled','failed')),
  fired_at     TIMESTAMPTZ,
  attempts     INT NOT NULL DEFAULT 0,
  failure_reason TEXT,
  parent_id    UUID REFERENCES reminders(id) ON DELETE SET NULL, -- snooze chain
  source_text  TEXT,                                              -- raw slash body
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT reminders_scope_target CHECK (
    (scope='self'    AND channel_id IS NULL AND dm_user_id IS NULL)
    OR (scope='channel' AND channel_id IS NOT NULL AND dm_user_id IS NULL)
    OR (scope='dm'      AND dm_user_id IS NOT NULL AND channel_id IS NULL)
  )
);

CREATE INDEX idx_reminders_due
  ON reminders(fire_at) WHERE state='pending';
CREATE INDEX idx_reminders_user_state
  ON reminders(user_id, state, fire_at);
```

## 2. RLS Policies

```sql
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY reminders_owner_all ON reminders FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER reminders_set_updated_at
  BEFORE UPDATE ON reminders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Per-user quota 100 active.
CREATE OR REPLACE FUNCTION reminders_quota() RETURNS TRIGGER AS $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM reminders
  WHERE user_id = NEW.user_id AND state = 'pending';
  IF n >= 100 THEN RAISE EXCEPTION 'reminders_quota_exceeded'; END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER reminders_quota_t
  BEFORE INSERT ON reminders
  FOR EACH ROW EXECUTE FUNCTION reminders_quota();
```

## 4. Migration File

Path: `supabase/migrations/165_reminders.up.sql`

```sql
BEGIN;
-- create table, indexes, RLS, triggers
SELECT cron.schedule('reminders_tick','*/30 * * * * *',
  'SELECT process_reminders();');
GRANT SELECT, INSERT, UPDATE, DELETE ON reminders TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `reminders:user:<uid>:list` | JSON | 60s |

## 6. Search Index

Not indexed.

## 7. Object Storage

None.

## 8. Data Retention

- `fired`: 7d
- `cancelled`/`failed`: 7d
- GDPR: cascade with user

## 9. Sample Queries

```sql
-- Worker batch
SELECT id, user_id, scope, channel_id, dm_user_id, text, rrule
FROM reminders
WHERE state='pending' AND fire_at <= now() + interval '30 seconds'
FOR UPDATE SKIP LOCKED
LIMIT 500;

-- My pending
SELECT id, scope, text, fire_at, channel_id, dm_user_id, rrule
FROM reminders
WHERE user_id = $1 AND state = 'pending'
ORDER BY fire_at;
```
