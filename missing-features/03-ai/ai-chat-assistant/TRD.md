# Aura — Server-Aware AI Chat Assistant — Technical Requirements

## 1. Architecture Overview

```
                           ┌───────────────────────────────────────┐
                           │           Flutter (mobile/web)         │
                           │   chat input → "@Aura ..." mention    │
                           └───────────────┬───────────────────────┘
                                           │ POST /api/v1/ai/aura/invoke
                                           ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                       Go backend  (chi router)                           │
│  handlers/ai_aura_handler.go  →  services/ai/chat_assistant/service.go   │
│                                                                          │
│   1. rate-limit (Redis ZSET)                                             │
│   2. context build:                                                      │
│       a. Qdrant query (collection=aura_<server_id>) top-k=8             │
│       b. Postgres pinned_messages last 30d top-3                         │
│       c. server FAQ docs already chunked + embedded                      │
│   3. prompt assembly (prompts/system.md + prompts/user.md)               │
│   4. LLM call:                                                           │
│       primary  → Groq llama-3.3-70b-versatile  (api.groq.com)            │
│       fallback → Ollama llama3.1:8b   (http://ollama:11434)              │
│   5. stream tokens → Centrifugo channel `aura:<server_id>:<msg_id>`      │
│   6. persist final → ai_aura_messages                                    │
│   7. emit metric flicko_ai_chat_assistant_replies_total                  │
└──────────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │   Centrifugo (SSE/WS)   │
                              └─────────────┬──────────┘
                                            │ streamed deltas
                                            ▼
                              ┌────────────────────────┐
                              │     Flutter listener    │
                              │   AuraStreamProvider    │
                              └────────────────────────┘
```

Indexing pipeline (async):

```
admin uploads doc
        ▼
NATS subject  flicko.ai.aura.index.requested
        ▼
worker (services/ai/chat_assistant/indexer.go)
   ├── PDF→text via pdfcpu
   ├── chunk @ 512 tokens, 64 overlap
   ├── embed each chunk via Ollama nomic-embed-text (768d)
   ├── upsert to Qdrant collection `aura_<server_id>`
   └── upsert metadata to ai_aura_documents
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/ai/chat_assistant/service.go`
- **Indexer worker:** `backend/internal/services/ai/chat_assistant/indexer.go`
- **LLM client:** `backend/internal/services/ai/chat_assistant/llm.go` (Groq + Ollama interface)
- **Embedder:** `backend/internal/services/ai/chat_assistant/embed.go`
- **Retriever:** `backend/internal/services/ai/chat_assistant/retriever.go`
- **Handler:** `backend/internal/handlers/ai_aura_handler.go`
- **Models:** `backend/internal/models/ai_aura.go`
- **Repo:** `backend/internal/repo/ai_aura_repo.go`
- **Prompts:** `backend/internal/services/ai/chat_assistant/prompts/{system.md,user.md,refuse.md}`
- **Eval harness:** `backend/internal/services/ai/chat_assistant/evals/run.go`

### Mobile (Flutter)
- `mobile/lib/features/ai_assistant/aura/data/aura_repository.dart`
- `mobile/lib/features/ai_assistant/aura/data/aura_sse_client.dart`
- `mobile/lib/features/ai_assistant/aura/domain/aura_message.dart`
- `mobile/lib/features/ai_assistant/aura/application/aura_stream_provider.dart`
- `mobile/lib/features/ai_assistant/aura/presentation/aura_reply_card.dart`
- `mobile/lib/features/ai_assistant/aura/presentation/aura_settings_screen.dart`
- `mobile/lib/features/ai_assistant/aura/presentation/aura_kb_upload_screen.dart`
- Existing screens to extend: `aura_dashboard_screen.dart`, `aura_voice_screen.dart`

### Infra
- **DB:** Supabase Postgres — tables in `SCHEMA.md` (migration `130`).
- **Realtime:** Centrifugo channel `aura:<server_id>:<message_id>` (per-reply, ephemeral).
- **Cache:** Redis keys
  - `aura:ratelimit:<user_id>:<server_id>` — sliding window ZSET, TTL 86400s
  - `aura:answer:<sha256(prompt+ctx)>` — JSON, TTL 600s (deduplicates burst-identical questions)
- **Vector store:** Qdrant collection `aura_<server_id>` (one per server, 768-dim cosine).
- **AI:** Groq SDK `github.com/conneroisu/groq-go v0.0.18` + Ollama HTTP via `github.com/ollama/ollama/api`.
- **Queue:** NATS subjects `flicko.ai.aura.index.requested`, `flicko.ai.aura.index.completed`.
- **Storage:** Appwrite bucket `aura_kb_<server_id>` for raw uploads.

## 3. API Contracts

### REST
```
POST   /api/v1/ai/aura/invoke              fire mention (returns SSE stream)
GET    /api/v1/ai/aura/messages/:id        fetch persisted reply
POST   /api/v1/ai/aura/feedback            { message_id, rating: up|down, reason? }
POST   /api/v1/ai/aura/kb/documents        multipart upload
GET    /api/v1/ai/aura/kb/documents        list per server
DELETE /api/v1/ai/aura/kb/documents/:id    + triggers Qdrant point deletion
GET    /api/v1/ai/aura/settings            { persona, model, rate_limit }
PATCH  /api/v1/ai/aura/settings
```

### SSE stream payload
```jsonc
event: token
data: {"delta": "Hello"}

event: citation
data: {"doc_id": "uuid", "chunk_id": "uuid", "title": "Server Rules", "score": 0.81}

event: done
data: {"message_id": "uuid", "tokens_in": 412, "tokens_out": 88, "model": "groq:llama-3.3-70b"}

event: error
data: {"code": "rate_limited", "retry_after": 42}
```

### Centrifugo
- Channel: `aura:<server_id>:<message_id>`
- Events: `aura.token`, `aura.citation`, `aura.done`, `aura.error`

### Invoke request
```jsonc
{
  "server_id": "uuid",
  "channel_id": "uuid",
  "thread_id": "uuid|null",
  "prompt": "where are the rules?",
  "history_message_ids": ["uuid", "uuid"]
}
```

## 4. Permissions & Auth

- Required scope: `ai.aura.invoke` (granted to all members by default)
- Admin scope: `ai.aura.manage` (model picker, KB upload)
- RLS: only server members can read messages from `ai_aura_messages` for their servers
- KB documents readable by all members of `server_id`; writable by `role.admin` only

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| First-token latency p50 | <1.2s |
| First-token latency p95 | <3.5s |
| Full reply latency p95 | <8s for 200-token reply |
| Throughput | 50 concurrent streams per node |
| Availability | 99.5% (best-effort; AI provider dependent) |
| Storage cost | <$0.01 per server/month (Qdrant + Postgres) |
| Compute cost | $0 (Groq free + Ollama on shared GPU) |
| GDPR | EU servers route to Hetzner-FSN Ollama only |

## 6. Dependencies

- **Existing services:** auth, server-membership, audit-log, centrifugo
- **New libraries:**
  - Go: `github.com/conneroisu/groq-go v0.0.18`, `github.com/ollama/ollama/api v0.5.x`, `github.com/qdrant/go-client v1.12.0`, `github.com/pdfcpu/pdfcpu v0.8.x`
  - Dart: `flutter_riverpod ^2.5.1`, `eventflux ^2.1.0` (SSE)
- **External APIs:** Groq (free 30 req/min/key, pool of 5 keys), Pollinations.ai not used here
- **Models on disk:** `nomic-embed-text` (274 MB), `llama3.1:8b` (4.7 GB) on Ollama node

## 7. Observability

- Metrics:
  - `flicko_ai_chat_assistant_invocations_total{server_id,model,outcome}`
  - `flicko_ai_chat_assistant_ttft_seconds` histogram
  - `flicko_ai_chat_assistant_tokens_in_total`, `_tokens_out_total`
  - `flicko_ai_chat_assistant_refusals_total{reason}`
  - `flicko_ai_chat_assistant_index_duration_seconds`
  - `flicko_ai_chat_assistant_qdrant_recall_at_8` (eval)
- Logs: structured JSON with `trace_id`, `server_id`, `user_id`, `model`, `tokens_in`, `tokens_out`, `latency_ms`
- Traces: OTel span tree `aura.invoke → aura.retrieve → aura.llm.stream → aura.persist`
- Dashboard: Grafana board `ai-aura` with TTFT, error %, fallback %, refusal %, top servers by volume

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Groq 429 rate-limit | reply blocked | round-robin to next key; after 3 fails fallback to Ollama |
| Ollama down | total AI outage | circuit-break for 60s, return graceful "Aura is napping, try again" |
| Qdrant down | no grounding → hallucination risk | refuse to answer, suggest "Aura's memory is rebuilding" |
| Embedding drift after model upgrade | recall drop | versioned collections `aura_<server_id>_v<n>`; backfill before swap |
| Prompt injection in pinned msg ("ignore previous instructions") | jailbreak | sandwich-pattern system prompt + adversarial eval set |
| Doc upload contains malware | infra threat | ClamAV scan in indexer worker before parse |
| Cost spike (key leak) | bill surprise (still $0 for Groq but wastes quota) | per-key daily quota in Redis, alert on >80% |
