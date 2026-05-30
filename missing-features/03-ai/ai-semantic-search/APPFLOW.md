# AI Semantic Search — APPFLOW

```mermaid
sequenceDiagram
    participant M as Message
    participant N as NATS
    participant E as Embedder
    participant Q as Qdrant
    participant ME as Meilisearch
    participant U as User
    participant API as Backend

    M->>N: created (if embed_eligible)
    N->>E: consume
    E->>E: nomic-embed-text
    E->>Q: upsert vector
    E->>ME: index keyword fields
    Note over Q,ME: durable, idempotent
    U->>API: GET /search?q=...&mode=hybrid
    API->>ME: lexical top-100
    API->>Q: vector top-100
    API->>API: merge + rerank top-100→10
    API-->>U: results
```

## State Machine
```
embedding job: queued → embedding → indexed | failed
query: planning → fetching → reranking → returning
```

## Edge Cases
- Edited message: re-embed on edit.
- Deleted message: tombstone Qdrant + ME.
- Long message: split into 1k-token chunks; query merges chunks.
- Multilingual queries: nomic-embed-text v1.5 supports 100 langs.

## Background
- Embedder consumer durable name `semsearch-embedder`.
- Re-index sweeper if model version bumps.

## Notifications
- None.
