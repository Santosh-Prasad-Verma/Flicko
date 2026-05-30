# Scheduled Messages — Backend Schema

## 1. Tables

### `scheduled_messages`

```sql
CREATE TABLE scheduled_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id      UUID REFERENCES channels(id) ON DELETE CASCADE,
  dm_user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  body            TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  attachments     JSONB NOT NULL DEFAULT '[]',
  mentions        JSONB NOT NULL DEFAULT '[]',
  fire_at         TIMESTAMPTZ NOT NULL,
  tz              TEXT NOT NULL DEFAULT 'UTC',
  rrule           TEXT,
  state           TEXT NOT NULL DEFAULT 'pending'
                   CHECK (state IN ('pending','firing','sent','cancelled','failed','expired')),
  fired_at        TIMESTAMPTZ,
  fired_message_id UUID,
  failure_reason  TEXT,
  attempts        INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_target_one_of CHECK (
    (channel_id IS NOT NULL AND dm_user_id IS NULL) OR
    (channel_id IS NULL AND dm_user_id IS NOT NULL)
  )
);

CREATE INDEX idx_sched_msg_due
  ON scheduled_messages(fire_at)
  WHERE state = 'pending';

CREATE INDEX idx_sched_msg_user_state
  ON scheduled_messages(user_id, state, fire_at);
```

## 2. RLS Policies

```sql
ALTER TABLE scheduled_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY sched_msg_owner_all ON scheduled_messages FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER sched_msg_set_updated_at
  BEFORE UPDATE ON scheduled_messages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Quota guard: deny insert when user has >=50 pending in same server.
CREATE OR REPLACE FUNCTION sched_msg_quota() RETURNS TRIGGER AS $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM scheduled_messages
  WHERE user_id = NEW.user_id AND state = 'pending';
  IF n >= 50 THEN
    RAISE EXCEPTION 'scheduled_messages_quota_exceeded';
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER sched_msg_quota_t
  BEFORE INSERT ON scheduled_messages
  FOR EACH ROW EXECUTE FUNCTION sched_msg_quota();
```

## 4. Migration File

Path: `supabase/migrations/163_scheduled_messages.up.sql`
Down: `supabase/migrations/163_scheduled_messages.down.sql`

```sql
BEGIN;
-- create table, indexes, RLS, policies, triggers
SELECT cron.schedule('scheduled_messages_tick','*/30 * * * * *',
  'SELECT process_scheduled_messages();');
GRANT SELECT, INSERT, UPDATE, DELETE ON scheduled_messages TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `sched_msg:user:<uid>` | list JSON | 60s |
| `sched_msg:lock:<id>` | worker lock | 30s |

## 6. Search Index

Not indexed in Meilisearch (private, ephemeral data).

## 7. Object Storage

- Attachments use existing `messages` bucket; copy reference at fire time
- Lifecycle: orphaned attachments cleaned hourly if scheduled cancelled

## 8. Data Retention

- `sent` rows: 30 days then purge
- `cancelled`/`failed`/`expired`: 14 days then purge
- GDPR delete: cascade with user

## 9. Sample Queries

```sql
-- Worker pull batch
SELECT id, user_id, channel_id, dm_user_id, body, attachments, mentions, fire_at, rrule
FROM scheduled_messages
WHERE state = 'pending' AND fire_at <= now() + interval '30 seconds'
FOR UPDATE SKIP LOCKED
LIMIT 200;

-- My pending list
SELECT id, body, fire_at, channel_id, dm_user_id
FROM scheduled_messages
WHERE user_id = $1 AND state = 'pending'
ORDER BY fire_at;
```
