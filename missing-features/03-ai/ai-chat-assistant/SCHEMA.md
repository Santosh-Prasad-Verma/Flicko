# Aura — Server-Aware AI Chat Assistant — Backend Schema

## 1. Tables

### `ai_aura_settings`

```sql
CREATE TABLE ai_aura_settings (
  server_id        UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled          BOOLEAN NOT NULL DEFAULT false,
  model            TEXT    NOT NULL DEFAULT 'groq:llama-3.3-70b-versatile',
  fallback_model   TEXT    NOT NULL DEFAULT 'ollama:llama3.1:8b',
  persona          TEXT    NOT NULL DEFAULT 'Friendly server assistant. Reply concisely, cite sources.',
  daily_user_cap   INT     NOT NULL DEFAULT 30,
  refusal_score    REAL    NOT NULL DEFAULT 0.55,    -- min retrieval score
  kb_version       BIGINT  NOT NULL DEFAULT 1,        -- bumps on doc add/remove
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `ai_aura_documents`

```sql
CREATE TABLE ai_aura_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  uploaded_by     UUID NOT NULL REFERENCES users(id),
  title           TEXT NOT NULL,
  source_type     TEXT NOT NULL CHECK (source_type IN ('upload','pinned','channel_topic')),
  appwrite_id     TEXT,                              -- bucket file id; null for pinned
  source_ref      TEXT,                              -- pinned message_id or channel_id
  mime_type       TEXT,
  byte_size       BIGINT,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','indexing','indexed','failed','deleted')),
  status_error    TEXT,
  chunk_count     INT NOT NULL DEFAULT 0,
  content_sha256  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  indexed_at      TIMESTAMPTZ,
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_aura_docs_server ON ai_aura_documents(server_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_aura_docs_status ON ai_aura_documents(status);
CREATE UNIQUE INDEX idx_aura_docs_sha
  ON ai_aura_documents(server_id, content_sha256)
  WHERE content_sha256 IS NOT NULL AND deleted_at IS NULL;
```

### `ai_aura_messages`

```sql
CREATE TABLE ai_aura_messages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id           UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id          UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  thread_id           UUID,
  invoking_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invoking_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  prompt              TEXT NOT NULL,
  prompt_sha256       TEXT NOT NULL,
  reply               TEXT,                          -- null if errored
  model_used          TEXT NOT NULL,
  tokens_in           INT,
  tokens_out          INT,
  ttft_ms             INT,
  total_ms            INT,
  outcome             TEXT NOT NULL DEFAULT 'pending'
                      CHECK (outcome IN ('pending','done','refused','error','rate_limited')),
  refusal_reason      TEXT,
  citations           JSONB NOT NULL DEFAULT '[]'::jsonb,
                      -- [{doc_id, chunk_id, title, score}]
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at         TIMESTAMPTZ
);

CREATE INDEX idx_aura_msg_server_time   ON ai_aura_messages(server_id, created_at DESC);
CREATE INDEX idx_aura_msg_user          ON ai_aura_messages(invoking_user_id, created_at DESC);
CREATE INDEX idx_aura_msg_outcome       ON ai_aura_messages(outcome);
CREATE INDEX idx_aura_msg_prompt_sha    ON ai_aura_messages(server_id, prompt_sha256);
```

### `ai_aura_feedback`

```sql
CREATE TABLE ai_aura_feedback (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id   UUID NOT NULL REFERENCES ai_aura_messages(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating IN (-1, 1)),
  reason       TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id)
);

CREATE INDEX idx_aura_feedback_msg ON ai_aura_feedback(message_id);
```

### `ai_aura_chunks` (lightweight metadata mirror of Qdrant)

```sql
CREATE TABLE ai_aura_chunks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id  UUID NOT NULL REFERENCES ai_aura_documents(id) ON DELETE CASCADE,
  server_id    UUID NOT NULL,
  ord          INT NOT NULL,
  text         TEXT NOT NULL,
  token_count  INT NOT NULL,
  qdrant_point_id UUID NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (document_id, ord)
);

CREATE INDEX idx_aura_chunks_doc ON ai_aura_chunks(document_id);
CREATE INDEX idx_aura_chunks_qpid ON ai_aura_chunks(qdrant_point_id);
```

## 2. RLS Policies

```sql
ALTER TABLE ai_aura_settings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_documents   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_messages    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_feedback    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_chunks      ENABLE ROW LEVEL SECURITY;

-- settings: server admins only
CREATE POLICY aura_settings_admin_rw ON ai_aura_settings
  FOR ALL USING (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid()
        AND role IN ('owner','admin')
    )
  );

-- documents: members read (knowing what's indexed), admins write
CREATE POLICY aura_docs_member_read ON ai_aura_documents
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );
CREATE POLICY aura_docs_admin_write ON ai_aura_documents
  FOR ALL USING (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid()
        AND role IN ('owner','admin')
    )
  );

-- messages: members of the server can read; only invoking user (or admin) can read their own prompt content
CREATE POLICY aura_msg_member_read ON ai_aura_messages
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );
CREATE POLICY aura_msg_self_insert ON ai_aura_messages
  FOR INSERT WITH CHECK (invoking_user_id = auth.uid());

-- feedback: any member can rate; one rating per message per user
CREATE POLICY aura_feedback_self ON ai_aura_feedback
  FOR ALL USING (user_id = auth.uid());

-- chunks: members read for citation modal
CREATE POLICY aura_chunks_member_read ON ai_aura_chunks
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );
```

## 3. Triggers

```sql
CREATE TRIGGER aura_settings_set_updated_at
  BEFORE UPDATE ON ai_aura_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Bump kb_version on doc add/remove → invalidates Redis answer cache
CREATE OR REPLACE FUNCTION bump_aura_kb_version() RETURNS trigger AS $$
BEGIN
  UPDATE ai_aura_settings
  SET kb_version = kb_version + 1, updated_at = now()
  WHERE server_id = COALESCE(NEW.server_id, OLD.server_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aura_docs_bump_kb_version
  AFTER INSERT OR UPDATE OF status OR DELETE ON ai_aura_documents
  FOR EACH ROW EXECUTE FUNCTION bump_aura_kb_version();
```

## 4. Migration File

Path: `supabase/migrations/130_ai_aura.up.sql`
Down: `supabase/migrations/130_ai_aura.down.sql`

```sql
-- 130_ai_aura.up.sql
BEGIN;

CREATE TABLE ai_aura_settings  (...);    -- as above
CREATE TABLE ai_aura_documents (...);
CREATE TABLE ai_aura_messages  (...);
CREATE TABLE ai_aura_feedback  (...);
CREATE TABLE ai_aura_chunks    (...);

-- indexes (as above)

ALTER TABLE ai_aura_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_messages  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_feedback  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_aura_chunks    ENABLE ROW LEVEL SECURITY;

-- policies (as above)
-- triggers (as above)

GRANT SELECT, INSERT, UPDATE, DELETE ON ai_aura_settings,
      ai_aura_documents, ai_aura_messages, ai_aura_feedback, ai_aura_chunks
  TO authenticated;

COMMIT;
```

```sql
-- 130_ai_aura.down.sql
BEGIN;
DROP TABLE IF EXISTS ai_aura_chunks    CASCADE;
DROP TABLE IF EXISTS ai_aura_feedback  CASCADE;
DROP TABLE IF EXISTS ai_aura_messages  CASCADE;
DROP TABLE IF EXISTS ai_aura_documents CASCADE;
DROP TABLE IF EXISTS ai_aura_settings  CASCADE;
DROP FUNCTION IF EXISTS bump_aura_kb_version();
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `aura:ratelimit:<user_id>:<server_id>` | ZSET of timestamps | 86400s |
| `aura:answer:<sha256(server_id+kb_version+prompt)>` | JSON {reply, citations, tokens, model} | 600s |
| `aura:settings:<server_id>` | JSON of `ai_aura_settings` row | 300s |
| `aura:circuitbreaker:groq` | INT (open=1, half=2, closed=0) | 60s |
| `aura:keyquota:groq:<key_idx>` | INT used today | until midnight UTC |
| `aura:reindex:lock:<server_id>` | "1" | 300s |

## 6. Search Index (Meilisearch)

Not used for Aura answers. The `ai_aura_messages.reply` is fed into the existing `messages` Meilisearch index when `outcome='done'` so admins can search past Aura answers via the standard chat search.

## 7. Vector Index (Qdrant)

```jsonc
{
  "collection": "aura_<server_id>",
  "vectors": { "size": 768, "distance": "Cosine" },
  "payload_schema": {
    "server_id":   "keyword",
    "document_id": "keyword",
    "chunk_id":    "keyword",
    "title":       "text",
    "ord":         "integer",
    "source_type": "keyword"
  },
  "hnsw_config": { "m": 16, "ef_construct": 100 },
  "optimizers_config": { "indexing_threshold": 10000 },
  "shard_number": 1,
  "replication_factor": 1
}
```

Versioned during model upgrade: `aura_<server_id>_v2` is built then atomically swapped via Qdrant alias `aura_<server_id>`.

## 8. Object Storage (Appwrite)

- Bucket per server: `aura_kb_<server_id>` (created lazily on first doc upload)
- Allowed MIME: `text/markdown`, `text/plain`, `application/pdf`
- Max file size: 5 MB
- Permission: `read("team:<server_id>:admin")`, `write("team:<server_id>:admin")`
- Encryption: at-rest via Appwrite default; bucket-level lifecycle deletes after `ai_aura_documents.deleted_at + 30d`

## 9. Data Retention

- `ai_aura_messages`: hot 90d in primary, then archive to R2 `r2://flicko-archive/aura/<yyyymm>/<server_id>.parquet`
- `ai_aura_documents`: kept until admin deletes; soft-delete via `deleted_at`, hard-delete after 30d
- `ai_aura_chunks`: cascades from documents
- `ai_aura_feedback`: kept indefinitely (small, useful for eval)
- GDPR `users.delete`:
  - cascades user-authored prompts via `invoking_user_id` FK
  - feedback rows cascade
  - server-owned documents persist (server is the data controller)

## 10. Sample Queries

```sql
-- Top questions in a server last 7 days (for dashboard)
SELECT prompt, COUNT(*) AS asks, AVG(ttft_ms) AS avg_ttft
FROM ai_aura_messages
WHERE server_id = $1
  AND created_at > now() - interval '7 days'
  AND outcome = 'done'
GROUP BY prompt
ORDER BY asks DESC
LIMIT 10;

-- Thumbs ratio per model
SELECT m.model_used,
       SUM((f.rating =  1)::int)::float / NULLIF(COUNT(f.id),0) AS up_ratio,
       COUNT(f.id) AS rated
FROM ai_aura_messages m
JOIN ai_aura_feedback f ON f.message_id = m.id
WHERE m.server_id = $1 AND m.created_at > now() - interval '30 days'
GROUP BY m.model_used;

-- Refusal % last 24h
SELECT COUNT(*) FILTER (WHERE outcome='refused')::float / COUNT(*) AS refusal_rate
FROM ai_aura_messages
WHERE server_id = $1 AND created_at > now() - interval '24 hours';

-- Daily quota check (also enforced in Redis but DB is source of truth for billing audit)
SELECT COUNT(*) FROM ai_aura_messages
WHERE invoking_user_id = $1
  AND server_id = $2
  AND created_at > date_trunc('day', now() AT TIME ZONE 'UTC');
```
