# AI Semantic Search — TRD

## Architecture
```
new message → NATS flicko.search.embed → embedder worker (nomic-embed via Ollama)
   → upsert vector in Qdrant + metadata in Meilisearch
query path:
  hybrid query → Meilisearch top-100 lexical + Qdrant top-100 vector
  → rerank with cross-encoder (BGE-reranker-base) → top-10
```

## Components
- Backend: `backend/internal/services/ai/semantic_search/{embedder,query_planner,reranker}.go`
- Workers: `embedder` consumes NATS, `reranker` runs in query path.
- Existing search service extended.
- Meilisearch index `messages_v2` with `embedding_id` linkage; Qdrant collection `messages_v1`.

## API
```
GET /search?q=...&mode=hybrid|lexical|semantic&server_id=...&channel_id=...
```

## NFRs
| NFR | Target |
|-----|--------|
| Index lag | <30s |
| Query p99 | <300ms |
| MRR top-10 | ≥0.7 |
| Cost / msg embed | <$0.0001 |

## Observability
- `flicko_semsearch_index_lag_seconds`
- `flicko_semsearch_queries_total{mode}`
- `flicko_semsearch_query_seconds`

## Failure
- Embedder backlog: degrade gracefully to lexical-only.
- Qdrant down: lexical fallback.
- Reranker timeout: skip rerank, return raw merge.

## Privacy
- E2EE channels: never embedded; flag in `messages.embed_eligible`.
- Per-message opt-out via API.
