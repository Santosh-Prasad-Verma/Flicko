# Whiteboard — Backend Schema

## 1. Tables

### `whiteboards`

```sql
CREATE TABLE whiteboards (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  voice_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  yjs_state       BYTEA,
  yjs_state_size  INT NOT NULL DEFAULT 0,
  rev             BIGINT NOT NULL DEFAULT 0,
  archived_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_whiteboards_channel ON whiteboards(channel_id) WHERE archived_at IS NULL;
CREATE INDEX idx_whiteboards_voice   ON whiteboards(voice_channel_id) WHERE voice_channel_id IS NOT NULL;
```

### `whiteboard_revisions`

```sql
CREATE TABLE whiteboard_revisions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  whiteboard_id UUID NOT NULL REFERENCES whiteboards(id) ON DELETE CASCADE,
  rev         BIGINT NOT NULL,
  yjs_state   BYTEA NOT NULL,
  png_id      TEXT,                                  -- Appwrite file id
  trigger     TEXT NOT NULL CHECK (trigger IN ('idle','threshold','manual')),
  label       TEXT,
  byte_size   INT NOT NULL,
  author_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (whiteboard_id, rev)
);
```

### `whiteboard_acls`

```sql
CREATE TABLE whiteboard_acls (
  whiteboard_id UUID NOT NULL REFERENCES whiteboards(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tier          TEXT NOT NULL CHECK (tier IN ('owner','editor','viewer')),
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (whiteboard_id, user_id)
);
```

### `whiteboard_handshake_tokens`

```sql
CREATE TABLE whiteboard_handshake_tokens (
  jti           UUID PRIMARY KEY,
  whiteboard_id UUID NOT NULL REFERENCES whiteboards(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tier          TEXT NOT NULL,
  expires_at    TIMESTAMPTZ NOT NULL,
  revoked_at    TIMESTAMPTZ
);

CREATE INDEX idx_wb_tokens_expiry ON whiteboard_handshake_tokens(expires_at);
```

## 2. RLS Policies

```sql
ALTER TABLE whiteboards     ENABLE ROW LEVEL SECURITY;
ALTER TABLE whiteboard_acls ENABLE ROW LEVEL SECURITY;

CREATE POLICY wb_member_read ON whiteboards FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id = auth.uid()));

CREATE POLICY wb_mod_write ON whiteboards FOR INSERT
  WITH CHECK (server_id IN (
    SELECT server_id FROM server_members
    WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')));
```

## 3. Triggers

```sql
CREATE TRIGGER wb_set_updated_at
  BEFORE UPDATE ON whiteboards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/168_whiteboard.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
GRANT SELECT, INSERT, UPDATE         ON whiteboards          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON whiteboard_acls      TO authenticated;
GRANT SELECT                          ON whiteboard_revisions TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `wb:presence:<id>` | hash of users | 30s |
| `wb:meta:<id>` | JSON | 60s |

## 6. Search Index

Not searchable; titles only via channel-scope.

## 7. Object Storage (Appwrite)

- Bucket: `whiteboard-exports`
- Allowed MIME: image/png
- Max size: 8 MB (large rendered canvas tiled)
- Permission: `read("channel:{channel_id}")`, `write("server")`

## 8. Data Retention

- Active: indefinite
- Archived: 90 days
- Revisions: keep last 20 + named

## 9. Sample Queries

```sql
-- Channel whiteboards
SELECT id, title, updated_at FROM whiteboards
WHERE channel_id = $1 AND archived_at IS NULL
ORDER BY updated_at DESC;

-- Voice channel attachment
SELECT * FROM whiteboards
WHERE voice_channel_id = $1 AND archived_at IS NULL;
```
