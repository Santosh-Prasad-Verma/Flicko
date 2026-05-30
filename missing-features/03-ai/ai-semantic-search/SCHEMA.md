# AI Semantic Search — SCHEMA

```sql
CREATE TABLE search_embeddings_meta (
  message_id    UUID PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
  collection    TEXT NOT NULL DEFAULT 'messages_v1',
  embedding_id  TEXT NOT NULL,
  model         TEXT NOT NULL,
  embedded_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  text_hash     TEXT NOT NULL
);
CREATE INDEX idx_seb_collection ON search_embeddings_meta(collection);

ALTER TABLE messages ADD COLUMN IF NOT EXISTS embed_eligible BOOLEAN NOT NULL DEFAULT true;
-- E2EE messages set embed_eligible=false.

CREATE TABLE search_queries_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID,
  server_id   UUID,
  query_hash  TEXT NOT NULL,
  mode        TEXT NOT NULL,
  results     INT,
  latency_ms  INT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sql_recent ON search_queries_log(created_at DESC);
```

## Qdrant collection (out-of-DB)
```jsonc
{
  "collection": "messages_v1",
  "vectors": { "size": 768, "distance": "Cosine" },
  "payload_schema": {
    "server_id": "keyword",
    "channel_id": "keyword",
    "user_id": "keyword",
    "created_at": "integer",
    "lang": "keyword"
  }
}
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `semsearch:q:<hash>:<server>` | top-10 | 60s |

## Migration: `supabase/migrations/140_ai_semantic_search.up.sql`

## RLS
Already inherits message access via existing RLS; query handler enforces server/channel membership before returning.
