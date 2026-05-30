# Channel Notes — Backend Schema

## 1. Tables

### `channel_notes`

```sql
CREATE TABLE channel_notes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      UUID UNIQUE NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  yjs_state       BYTEA,
  yjs_state_size  INT NOT NULL DEFAULT 0,
  rev             BIGINT NOT NULL DEFAULT 0,
  markdown_export TEXT NOT NULL DEFAULT '',
  last_edited_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  last_edited_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_channel_notes_channel ON channel_notes(channel_id);
```

### `channel_notes_handshake_tokens`

```sql
CREATE TABLE channel_notes_handshake_tokens (
  jti         UUID PRIMARY KEY,
  channel_id  UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  can_edit    BOOLEAN NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_cn_tokens_expiry ON channel_notes_handshake_tokens(expires_at);
```

## 2. RLS Policies

```sql
ALTER TABLE channel_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY channel_notes_read ON channel_notes FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id = auth.uid()));

CREATE POLICY channel_notes_write ON channel_notes FOR INSERT
  WITH CHECK (channel_id IN (SELECT channel_id FROM channel_members
                             WHERE user_id = auth.uid() AND can_write = true));

CREATE POLICY channel_notes_update ON channel_notes FOR UPDATE
  USING (channel_id IN (SELECT channel_id FROM channel_members
                        WHERE user_id = auth.uid() AND can_write = true));
```

## 3. Triggers

```sql
CREATE TRIGGER channel_notes_set_updated_at
  BEFORE UPDATE ON channel_notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/170_channel_notes.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
GRANT SELECT, INSERT, UPDATE ON channel_notes TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `cn:meta:<cid>` | { rev, last_edited_at, last_edited_by } | 60s |
| `cn:presence:<cid>` | hash of editors | 30s |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid":"channel_notes",
  "primaryKey":"id",
  "searchableAttributes":["markdown_export"],
  "filterableAttributes":["channel_id"]
}
```

## 7. Object Storage

None.

## 8. Data Retention

- Active: indefinite
- Cascade with channel delete

## 9. Sample Queries

```sql
-- Read meta for channel
SELECT id, rev, last_edited_at, last_edited_by, yjs_state_size
FROM channel_notes
WHERE channel_id = $1;

-- Recent edits across server (for activity feed)
SELECT cn.*, c.name AS channel_name
FROM channel_notes cn
JOIN channels c ON c.id = cn.channel_id
WHERE c.server_id = $1
ORDER BY cn.last_edited_at DESC
LIMIT 20;
```
