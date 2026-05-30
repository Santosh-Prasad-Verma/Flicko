# Collaborative Docs — Backend Schema

## 1. Tables

### `docs`

```sql
CREATE TABLE docs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 160),
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  default_tier    TEXT NOT NULL DEFAULT 'editor'
                   CHECK (default_tier IN ('editor','commenter','viewer')),
  yjs_state       BYTEA,                                    -- latest snapshot bytes
  yjs_state_size  INT NOT NULL DEFAULT 0,
  rev             BIGINT NOT NULL DEFAULT 0,
  markdown_export TEXT,                                     -- last rendered markdown for search/export
  archived_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_docs_channel ON docs(channel_id) WHERE archived_at IS NULL;
CREATE INDEX idx_docs_server  ON docs(server_id);
CREATE INDEX idx_docs_search  ON docs USING gin (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(markdown_export,'')));
```

### `doc_revisions`

```sql
CREATE TABLE doc_revisions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id      UUID NOT NULL REFERENCES docs(id) ON DELETE CASCADE,
  rev         BIGINT NOT NULL,
  yjs_state   BYTEA NOT NULL,
  markdown    TEXT,
  trigger     TEXT NOT NULL CHECK (trigger IN ('idle','threshold','manual','restore')),
  label       TEXT,                                         -- optional name like "before launch"
  author_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  byte_size   INT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (doc_id, rev)
);

CREATE INDEX idx_doc_revisions_doc ON doc_revisions(doc_id, created_at DESC);
```

### `doc_acls`

```sql
CREATE TABLE doc_acls (
  doc_id     UUID NOT NULL REFERENCES docs(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tier       TEXT NOT NULL CHECK (tier IN ('owner','editor','commenter','viewer')),
  granted_by UUID REFERENCES users(id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (doc_id, user_id)
);
```

### `doc_comments`

```sql
CREATE TABLE doc_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id      UUID NOT NULL REFERENCES docs(id) ON DELETE CASCADE,
  thread_id   UUID NOT NULL,                                -- groups replies; first comment uses its own id
  parent_id   UUID REFERENCES doc_comments(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  body        TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  anchor_from TEXT,                                         -- Yjs Y.RelativePosition encoded
  anchor_to   TEXT,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_doc_comments_doc_thread ON doc_comments(doc_id, thread_id, created_at);
CREATE INDEX idx_doc_comments_open       ON doc_comments(doc_id) WHERE resolved_at IS NULL;
```

### `doc_handshake_tokens`

```sql
CREATE TABLE doc_handshake_tokens (
  jti         UUID PRIMARY KEY,
  doc_id      UUID NOT NULL REFERENCES docs(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tier        TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ
);

CREATE INDEX idx_doc_tokens_expiry ON doc_handshake_tokens(expires_at);
```

## 2. RLS Policies

```sql
ALTER TABLE docs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE doc_acls      ENABLE ROW LEVEL SECURITY;
ALTER TABLE doc_comments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE doc_revisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY docs_channel_member_read ON docs FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id = auth.uid()));

CREATE POLICY docs_owner_write ON docs FOR INSERT
  WITH CHECK (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')
    )
  );

CREATE POLICY doc_acls_self_or_owner ON doc_acls FOR SELECT
  USING (
    user_id = auth.uid()
    OR doc_id IN (SELECT doc_id FROM doc_acls WHERE user_id = auth.uid() AND tier = 'owner')
  );

CREATE POLICY doc_comments_member_read ON doc_comments FOR SELECT
  USING (doc_id IN (SELECT id FROM docs WHERE channel_id IN
         (SELECT channel_id FROM channel_members WHERE user_id = auth.uid())));
```

## 3. Triggers

```sql
CREATE TRIGGER docs_set_updated_at
  BEFORE UPDATE ON docs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Tear down expired handshake tokens.
CREATE OR REPLACE FUNCTION purge_doc_tokens() RETURNS void AS $$
  DELETE FROM doc_handshake_tokens WHERE expires_at < now() - interval '1 hour';
$$ LANGUAGE sql;
SELECT cron.schedule('purge_doc_tokens_hourly','0 * * * *','SELECT purge_doc_tokens();');
```

## 4. Migration File

Path: `supabase/migrations/162_collaborative_docs.up.sql`
Down: `supabase/migrations/162_collaborative_docs.down.sql`

```sql
-- up
BEGIN;
-- create tables, indexes, policies, trigger
GRANT SELECT, INSERT, UPDATE         ON docs           TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON doc_acls       TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON doc_comments   TO authenticated;
GRANT SELECT                          ON doc_revisions TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `docs:presence:<doc_id>` | hash of {user_id: {name,color,cursor}} | 30s |
| `docs:meta:<doc_id>` | JSON metadata | 60s |
| `docs:list:channel:<cid>` | list JSON | 30s |
| `docs:handshake:<jti>` | claims | 30m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "docs",
  "primaryKey": "id",
  "searchableAttributes": ["title", "markdown_export"],
  "filterableAttributes": ["server_id", "channel_id", "archived_at"],
  "sortableAttributes": ["updated_at"]
}
```

## 7. Object Storage (Appwrite)

- Bucket: `doc-images`
- Allowed MIME: image/png, image/jpeg, image/webp, image/gif
- Max file size: 8 MB
- Permission: `read("channel:{channel_id}")`, `write("user:{uploader_id}")`

## 8. Data Retention

- Active docs: indefinite
- Soft-archived: purged after 90 days
- Revisions: keep last 50 + named ones; older auto-pruned
- GDPR: doc owned by server; user delete nulls authors; comments author null'd

## 9. Sample Queries

```sql
-- List docs in a channel
SELECT id, title, updated_at, rev, yjs_state_size
FROM docs
WHERE channel_id = $1 AND archived_at IS NULL
ORDER BY updated_at DESC;

-- Doc with effective tier for current user
SELECT d.*, COALESCE(a.tier, d.default_tier) AS effective_tier
FROM docs d
LEFT JOIN doc_acls a ON a.doc_id = d.id AND a.user_id = $1
WHERE d.id = $2;

-- Last 20 revisions
SELECT rev, label, trigger, byte_size, author_id, created_at
FROM doc_revisions
WHERE doc_id = $1
ORDER BY rev DESC
LIMIT 20;
```
