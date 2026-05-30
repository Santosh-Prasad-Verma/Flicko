# Notion / Linear Integration — Backend Schema

## 1. Tables

### `integrations`

```sql
CREATE TABLE integrations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id         UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  provider          TEXT NOT NULL CHECK (provider IN ('linear','notion')),
  external_account  TEXT NOT NULL,                            -- workspace id / org name
  encrypted_token   BYTEA NOT NULL,                           -- envelope-encrypted access+refresh
  token_kid         TEXT NOT NULL,                            -- KMS key id ref
  token_expires_at  TIMESTAMPTZ,
  scopes            TEXT[] NOT NULL DEFAULT '{}',
  state             TEXT NOT NULL DEFAULT 'active'
                     CHECK (state IN ('active','paused','needs_reinstall','removed')),
  installed_by      UUID NOT NULL REFERENCES users(id),
  webhook_secret    BYTEA,                                    -- for verifying provider webhooks
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, provider, external_account)
);

CREATE INDEX idx_integrations_state ON integrations(state);
```

### `integration_mappings`

```sql
CREATE TABLE integration_mappings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id  UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
  source_filter   JSONB NOT NULL,                              -- { team_id, view_id, db_id, filter }
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  board_id        UUID REFERENCES kanban_boards(id) ON DELETE SET NULL,
  status_map      JSONB NOT NULL DEFAULT '{}',                 -- { external_status -> flicko_status }
  reverse_sync    BOOLEAN NOT NULL DEFAULT true,
  backfill_window_days INT NOT NULL DEFAULT 30,
  state           TEXT NOT NULL DEFAULT 'active'
                   CHECK (state IN ('active','paused','syncing','error')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_integration_mappings_int ON integration_mappings(integration_id);
```

### `integration_links`

```sql
-- Maps an external entity to a Flicko task; the source of truth for two-way sync.
CREATE TABLE integration_links (
  integration_id  UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
  external_id     TEXT NOT NULL,
  external_type   TEXT NOT NULL,                          -- 'issue' | 'page' | ...
  task_id         UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  last_external_updated_at TIMESTAMPTZ,
  last_synced_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (integration_id, external_type, external_id),
  UNIQUE (task_id)
);

CREATE INDEX idx_int_links_task ON integration_links(task_id);
```

### `integration_outbox`

```sql
CREATE TABLE integration_outbox (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id  UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
  task_id         UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  payload         JSONB NOT NULL,
  state           TEXT NOT NULL DEFAULT 'pending'
                   CHECK (state IN ('pending','sending','sent','failed')),
  attempts        INT NOT NULL DEFAULT 0,
  last_error      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at         TIMESTAMPTZ
);

CREATE INDEX idx_int_outbox_pending
  ON integration_outbox(created_at) WHERE state='pending';
```

### `integration_audit`

```sql
CREATE TABLE integration_audit (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id  UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
  direction       TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
  external_id     TEXT,
  task_id         UUID,
  result          TEXT NOT NULL CHECK (result IN ('ok','conflict_external_won','error','skipped_dup')),
  detail          JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_int_audit_int_time ON integration_audit(integration_id, created_at DESC);
```

### `integration_idempotency`

```sql
-- Stores hash of (provider:event_id) for 24h to avoid replay/loop.
CREATE TABLE integration_idempotency (
  key         TEXT PRIMARY KEY,
  expires_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_int_idemp_expiry ON integration_idempotency(expires_at);
```

## 2. RLS Policies

```sql
ALTER TABLE integrations         ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration_audit    ENABLE ROW LEVEL SECURITY;

CREATE POLICY integrations_admin_only ON integrations FOR ALL
  USING (server_id IN (
    SELECT server_id FROM server_members
    WHERE user_id = auth.uid() AND role IN ('owner','admin')
  ));

CREATE POLICY integration_mappings_admin_only ON integration_mappings FOR ALL
  USING (integration_id IN (SELECT id FROM integrations));

CREATE POLICY integration_audit_admin_read ON integration_audit FOR SELECT
  USING (integration_id IN (SELECT id FROM integrations));
```

## 3. Triggers

```sql
CREATE TRIGGER integrations_set_updated_at
  BEFORE UPDATE ON integrations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/166_integrations.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
SELECT cron.schedule('integration_idempotency_purge','0 * * * *',
  'DELETE FROM integration_idempotency WHERE expires_at < now();');
GRANT SELECT, INSERT, UPDATE, DELETE ON integrations         TO service_role;
GRANT SELECT                          ON integration_audit   TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `integ:<id>:tokens` | decrypted token (memory only) | 5m |
| `integ:webhook:rate:<id>` | rolling counter | 60s |

## 6. Search Index

Not searchable; audit only.

## 7. Object Storage

None.

## 8. Data Retention

- Audit: 90 days
- Idempotency: 24h
- Outbox sent rows: 7 days
- GDPR: server-owned; cascade on server delete

## 9. Sample Queries

```sql
-- Find Flicko task for a Linear issue
SELECT t.* FROM integration_links l
JOIN tasks t ON t.id = l.task_id
WHERE l.integration_id = $1
  AND l.external_type = 'issue' AND l.external_id = $2;

-- Outbox batch
SELECT id, integration_id, task_id, payload
FROM integration_outbox
WHERE state='pending'
ORDER BY created_at
FOR UPDATE SKIP LOCKED
LIMIT 100;
```
