# Disappearing Messages — Backend Schema

## 1. Tables

### `messages` (extension)

Existing table, additive change:

```sql
ALTER TABLE messages
  ADD COLUMN expires_at TIMESTAMPTZ,
  ADD COLUMN ttl_seconds INT;  -- denormalized for analytics buckets

CREATE INDEX idx_messages_expires_at
  ON messages (expires_at)
  WHERE expires_at IS NOT NULL;

-- Partition-friendly: if messages already partitioned by month, the index lands per-partition.
```

### `dm_disappearing_defaults`

Per-DM default TTL chosen by either participant.

```sql
CREATE TABLE dm_disappearing_defaults (
  dm_id        UUID NOT NULL REFERENCES dms(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ttl_seconds  INT NOT NULL CHECK (ttl_seconds IN (300, 3600, 86400, 604800)),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (dm_id, user_id)
);
```

### `disappearing_audit_log`

Privacy-preserving audit; never stores content.

```sql
CREATE TABLE disappearing_audit_log (
  id            BIGSERIAL PRIMARY KEY,
  message_id    UUID NOT NULL,
  channel_id    UUID NOT NULL,
  ttl_seconds   INT NOT NULL,
  expired_at    TIMESTAMPTZ NOT NULL,
  swept_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  reason        TEXT NOT NULL CHECK (reason IN ('expired', 'sender_delete', 'mod_delete'))
);

CREATE INDEX idx_disappearing_audit_channel ON disappearing_audit_log(channel_id, swept_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE dm_disappearing_defaults ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self read/write defaults"
  ON dm_disappearing_defaults FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE disappearing_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channel members can read audit"
  ON disappearing_audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM channel_members
      WHERE channel_id = disappearing_audit_log.channel_id
        AND user_id = auth.uid()
    )
  );
```

## 3. Sweeper Function

```sql
CREATE OR REPLACE FUNCTION sweep_expired_messages()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_swept INT := 0;
  r RECORD;
BEGIN
  FOR r IN
    SELECT id, channel_id, ttl_seconds, expires_at
    FROM messages
    WHERE expires_at IS NOT NULL
      AND expires_at <= now()
    LIMIT 5000
    FOR UPDATE SKIP LOCKED
  LOOP
    INSERT INTO disappearing_audit_log
      (message_id, channel_id, ttl_seconds, expired_at, reason)
      VALUES (r.id, r.channel_id, r.ttl_seconds, r.expires_at, 'expired');

    -- enqueue attachment delete for worker (NATS publish via trigger or LISTEN/NOTIFY)
    PERFORM pg_notify('disappearing_sweep_attachments', r.id::text);

    -- enqueue search-index delete
    PERFORM pg_notify('disappearing_sweep_search', r.id::text);

    DELETE FROM messages WHERE id = r.id;
    v_swept := v_swept + 1;
  END LOOP;

  RETURN v_swept;
END;
$$;

REVOKE ALL ON FUNCTION sweep_expired_messages() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sweep_expired_messages() TO postgres;
```

## 4. pg_cron schedule

```sql
SELECT cron.schedule(
  'disappearing_sweep',
  '* * * * *',
  $$ SELECT sweep_expired_messages(); $$
);
```

## 5. Migration File

Path: `supabase/migrations/216_disappearing_messages.up.sql`
Down: `supabase/migrations/216_disappearing_messages.down.sql`

```sql
-- 216_disappearing_messages.up.sql
BEGIN;
ALTER TABLE messages ADD COLUMN expires_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN ttl_seconds INT;
CREATE INDEX idx_messages_expires_at ON messages(expires_at) WHERE expires_at IS NOT NULL;

CREATE TABLE dm_disappearing_defaults (...);
CREATE TABLE disappearing_audit_log (...);

ALTER TABLE dm_disappearing_defaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE disappearing_audit_log    ENABLE ROW LEVEL SECURITY;
-- policies ...

CREATE FUNCTION sweep_expired_messages() RETURNS INT ...;
SELECT cron.schedule('disappearing_sweep', '* * * * *', $$ SELECT sweep_expired_messages(); $$);

COMMIT;
```

Down migration: unschedule cron, drop function, drop tables, drop columns.

## 6. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `channel:<id>:messages:page:<n>` | JSON list | 30s |
| `dm:<id>:default_ttl:<user_id>` | int seconds | 5m |

Sweeper invalidates `channel:<id>:messages:*` for any channel touched.

## 7. Search Index (Meilisearch)

Listener on Postgres NOTIFY `disappearing_sweep_search` removes the doc by id.

## 8. Object Storage (Appwrite)

Listener on Postgres NOTIFY `disappearing_sweep_attachments` runs in a Go worker that:
1. Reads the attachment list for `message_id` (kept briefly via foreign-keyed `attachments` row whose CASCADE on `messages` we override to defer).
2. Deletes each blob from Appwrite.
3. Deletes `attachments` row.

## 9. Data Retention

- Message content: deleted at `expires_at`.
- Audit log row (no content): retained 1 year for support diagnostics, then archived to R2 cold storage.
- DM default TTL settings: retained per user; cascade on `users.delete`.

## 10. Sample Queries

```sql
-- send with TTL
INSERT INTO messages (channel_id, sender_id, content, ttl_seconds, expires_at)
VALUES ($1, $2, $3, $4, now() + ($4 || ' seconds')::interval)
RETURNING *;

-- per-DM default TTL
SELECT ttl_seconds
FROM dm_disappearing_defaults
WHERE dm_id = $1 AND user_id = auth.uid();

-- count of pending sweeps in next minute
SELECT COUNT(*) FROM messages
WHERE expires_at BETWEEN now() AND now() + interval '1 minute';
```
