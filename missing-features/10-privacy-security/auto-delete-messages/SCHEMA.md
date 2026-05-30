# Auto-Delete Messages — Backend Schema

## 1. Tables

### `channel_auto_delete_settings`

```sql
CREATE TABLE channel_auto_delete_settings (
  channel_id      UUID PRIMARY KEY REFERENCES channels(id) ON DELETE CASCADE,
  ttl_seconds     INT NOT NULL CHECK (ttl_seconds IN (3600, 21600, 86400, 604800, 2592000)),
  exempt_pinned   BOOLEAN NOT NULL DEFAULT TRUE,
  exempt_system   BOOLEAN NOT NULL DEFAULT TRUE,
  enabled         BOOLEAN NOT NULL DEFAULT TRUE,
  set_by          UUID NOT NULL REFERENCES users(id),
  set_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `channel_auto_delete_audit`

```sql
CREATE TABLE channel_auto_delete_audit (
  id              BIGSERIAL PRIMARY KEY,
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  action          TEXT NOT NULL CHECK (action IN ('enable', 'disable', 'update_ttl', 'sweep')),
  old_ttl_seconds INT,
  new_ttl_seconds INT,
  swept_count     INT,
  actor_id        UUID REFERENCES users(id),
  occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_auto_delete_audit_channel_time
  ON channel_auto_delete_audit(channel_id, occurred_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE channel_auto_delete_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channel members read"
  ON channel_auto_delete_settings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM channel_members
      WHERE channel_id = channel_auto_delete_settings.channel_id
        AND user_id = auth.uid()
    )
  );

CREATE POLICY "mods write"
  ON channel_auto_delete_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM channel_members cm
      JOIN server_members sm USING (server_id, user_id)
      WHERE cm.channel_id = channel_auto_delete_settings.channel_id
        AND sm.user_id = auth.uid()
        AND sm.role_flags & 2 = 2
    )
  );

ALTER TABLE channel_auto_delete_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channel members read audit"
  ON channel_auto_delete_audit FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM channel_members
      WHERE channel_id = channel_auto_delete_audit.channel_id
        AND user_id = auth.uid()
    )
  );
```

## 3. Sweeper Function

```sql
CREATE OR REPLACE FUNCTION sweep_auto_delete_messages()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total INT := 0;
  v_swept INT;
  c RECORD;
BEGIN
  FOR c IN
    SELECT channel_id, ttl_seconds, exempt_pinned, exempt_system
    FROM channel_auto_delete_settings
    WHERE enabled = TRUE
  LOOP
    WITH victims AS (
      SELECT id, channel_id
      FROM messages m
      WHERE m.channel_id = c.channel_id
        AND m.created_at < now() - (c.ttl_seconds || ' seconds')::interval
        AND (NOT c.exempt_pinned OR NOT EXISTS (
              SELECT 1 FROM message_pins p
              WHERE p.channel_id = m.channel_id AND p.message_id = m.id))
        AND (NOT c.exempt_system OR m.kind <> 'system')
        AND m.expires_at IS NULL  -- per-message TTL handled elsewhere
      LIMIT 5000
      FOR UPDATE SKIP LOCKED
    )
    DELETE FROM messages
    USING victims
    WHERE messages.id = victims.id;

    GET DIAGNOSTICS v_swept = ROW_COUNT;

    IF v_swept > 0 THEN
      INSERT INTO channel_auto_delete_audit
        (channel_id, action, new_ttl_seconds, swept_count)
        VALUES (c.channel_id, 'sweep', c.ttl_seconds, v_swept);

      PERFORM pg_notify('auto_delete_sweep_attachments', c.channel_id::text);
      PERFORM pg_notify('auto_delete_sweep_search', c.channel_id::text);
    END IF;

    v_total := v_total + v_swept;
  END LOOP;

  RETURN v_total;
END;
$$;
```

## 4. pg_cron schedule

```sql
SELECT cron.schedule(
  'auto_delete_sweep',
  '* * * * *',
  $$ SELECT sweep_auto_delete_messages(); $$
);
```

## 5. Migration File

Path: `supabase/migrations/222_auto_delete_messages.up.sql`
Down: `supabase/migrations/222_auto_delete_messages.down.sql`

```sql
-- 222_auto_delete_messages.up.sql
BEGIN;
CREATE TABLE channel_auto_delete_settings (...);
CREATE TABLE channel_auto_delete_audit (...);

ALTER TABLE channel_auto_delete_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_auto_delete_audit    ENABLE ROW LEVEL SECURITY;
-- policies ...

CREATE FUNCTION sweep_auto_delete_messages() RETURNS INT ...;
SELECT cron.schedule('auto_delete_sweep', '* * * * *', $$ SELECT sweep_auto_delete_messages(); $$);

COMMIT;
```

Down migration: unschedule cron, drop function, drop tables.

## 6. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `auto_delete:channel:<id>` | `{ttl_seconds, exempt_pinned, exempt_system, enabled}` | 5m |
| `auto_delete:server:<id>:enabled_channels` | set of channel_ids | 10m |

Settings change publishes invalidation event consumed by all reading processes.

## 7. Search Index (Meilisearch)

Sweeper publishes `auto_delete_sweep_search` NOTIFY → indexer worker removes the deleted message ids from Meilisearch.

## 8. Object Storage (Appwrite)

`auto_delete_sweep_attachments` NOTIFY → attachment-sweeper worker (shared with `disappearing-messages`).

## 9. Data Retention

- Settings rows: persist while channel exists.
- Audit log: 1 year hot, then archived to R2 cold storage.
- Swept content: hard-deleted (the whole point).

## 10. Sample Queries

```sql
-- mod sets TTL
INSERT INTO channel_auto_delete_settings
  (channel_id, ttl_seconds, exempt_pinned, exempt_system, set_by)
VALUES ($1, 86400, TRUE, TRUE, auth.uid())
ON CONFLICT (channel_id) DO UPDATE
  SET ttl_seconds   = EXCLUDED.ttl_seconds,
      exempt_pinned = EXCLUDED.exempt_pinned,
      exempt_system = EXCLUDED.exempt_system,
      updated_at    = now(),
      set_by        = auth.uid();

-- members see badge data
SELECT ttl_seconds FROM channel_auto_delete_settings
WHERE channel_id = $1 AND enabled = TRUE;

-- recent sweep counts
SELECT swept_count, occurred_at FROM channel_auto_delete_audit
WHERE channel_id = $1 AND action = 'sweep'
ORDER BY occurred_at DESC LIMIT 50;

-- count of messages eligible for next sweep (planning)
SELECT COUNT(*) FROM messages m
JOIN channel_auto_delete_settings s ON s.channel_id = m.channel_id
WHERE s.enabled
  AND m.created_at < now() - (s.ttl_seconds || ' seconds')::interval
  AND m.expires_at IS NULL
  AND (NOT s.exempt_system OR m.kind <> 'system')
  AND (NOT s.exempt_pinned OR NOT EXISTS (
        SELECT 1 FROM message_pins p WHERE p.message_id = m.id));
```
