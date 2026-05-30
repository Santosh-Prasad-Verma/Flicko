# Catch-Me-Up — AI Channel Summary — Technical Requirements

## 1. Architecture Overview

```
              ┌──────────────────────────────────────────────┐
              │  Flutter — "✦ Catch me up" pill              │
              │  taps -> POST /api/v1/ai/summary/request     │
              └────────────────────┬─────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│                Go backend (services/ai/message_summary)          │
│                                                                  │
│  1. validate channel ACL                                         │
│  2. ratelimit (Redis ZSET 50/day)                                │
│  3. window = SELECT messages WHERE channel_id=$1                 │
│              AND created_at > $last_read AND <= now()            │
│              AND deleted_at IS NULL                              │
│              ORDER BY created_at LIMIT 500                       │
│  4. cache lookup: summary:<chan>:<anchor>:<latest>               │
│     hit  -> SSE replay                                           │
│     miss -> step 5                                               │
│  5. compress: dedupe near-identical, drop emoji-only             │
│  6. prompt build: prompts/summary.md                             │
│  7. LLM:                                                         │
│       primary  -> Groq llama-3.3-70b   (8s timeout)              │
│       fallback -> Ollama llama3.1:8b   (no timeout)              │
│  8. parse bullets -> resolve message_id citations                │
│  9. stream SSE  ->  Centrifugo summary:<req_id>                  │
│ 10. persist ai_summaries (status=done)                           │
└──────────────────────────────────────────────────────────────────┘
```

Pipeline (input → output):

```
[messages]  →  [filter+compress]  →  [LLM]  →  [bullets+citations]  →  [SSE stream]
                       ↓                                  ↓
                  [token budget                      [resolve msg_id]
                   ~6k context]
```

## 2. Components

### Backend (Go)
- `backend/internal/services/ai/message_summary/service.go`
- `backend/internal/services/ai/message_summary/window.go` — message fetch + filter
- `backend/internal/services/ai/message_summary/compressor.go` — dedupe / emoji-only drop / quote collapsing
- `backend/internal/services/ai/message_summary/llm.go` — shared with chat-assistant via `internal/services/ai/llm`
- `backend/internal/services/ai/message_summary/parser.go` — extract bullets + message_id refs
- `backend/internal/services/ai/message_summary/cache.go`
- `backend/internal/services/ai/message_summary/prompts/summary.md`
- `backend/internal/handlers/ai_summary_handler.go`
- `backend/internal/models/ai_summary.go`
- `backend/internal/repo/ai_summary_repo.go`
- `backend/internal/services/ai/message_summary/evals/run.go` + `golden.jsonl` (40 cases)

### Mobile (Flutter)
- `mobile/lib/features/ai_assistant/summary/data/summary_repository.dart`
- `mobile/lib/features/ai_assistant/summary/data/summary_sse_client.dart`
- `mobile/lib/features/ai_assistant/summary/domain/summary.dart`
- `mobile/lib/features/ai_assistant/summary/application/summary_provider.dart`
- `mobile/lib/features/ai_assistant/summary/presentation/catch_me_up_pill.dart`
- `mobile/lib/features/ai_assistant/summary/presentation/summary_card.dart`
- Hook into `mobile/lib/features/server_channels/text/presentation/channel_messages_screen.dart`

### Infra
- DB: Supabase Postgres (migration `131`)
- Realtime: Centrifugo channel `summary:<request_id>` (ephemeral, anonymous-readable by request owner only)
- Cache: Redis keys
  - `summary:ratelimit:<user_id>` ZSET
  - `summary:answer:<channel_id>:<anchor_msg_id>:<latest_msg_id>:<model>` JSON, TTL 3600s
- AI: Groq + Ollama (shared client)
- Queue: NATS subject `flicko.ai.summary.archive` (writes to R2)

## 3. API Contracts

### REST

```
POST /api/v1/ai/summary/request
  body: { "channel_id": "uuid", "since_ts": "2026-05-29T08:00:00Z" }
  resp: 200 { "request_id": "uuid", "stream_url": "/api/v1/ai/summary/stream/<id>" }

GET  /api/v1/ai/summary/stream/:id      (SSE)
GET  /api/v1/ai/summary/:id             (final persisted)
POST /api/v1/ai/summary/:id/feedback    { "rating": 1|-1, "reason": "..." }
```

### SSE events

```
event: bullet
data: {"index": 0, "text": "@alice and @bob shipped the v2 onboarding flow.",
       "citations": ["msg-uuid", "msg-uuid"]}

event: meta
data: {"participants": ["alice","bob"], "sentiment": "positive",
       "message_count": 142, "window_start": "...", "window_end": "..."}

event: done
data: {"summary_id": "uuid", "tokens_in": 4810, "tokens_out": 312, "model": "groq:llama-3.3-70b"}

event: error
data: {"code": "too_few_messages", "minimum": 5}
```

### Centrifugo
- Channel: `summary:<request_id>` (one-shot)
- Auth: signed JWT contains `request_id` claim; backend grants only to invoking user

## 4. Permissions & Auth

- Required: caller must be member of `channel_id`'s server with `channel.read` permission
- Channel ACL: re-validated server-side every request — read perms can change while window forms
- RLS: `ai_summaries` row readable only by `requested_by`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| First-bullet TTFB p50 | <1.5s |
| First-bullet TTFB p95 | <4s |
| Total time for 5 bullets p95 | <8s |
| Cache hit ratio | ≥45% (popular channels) |
| Throughput | 100 concurrent streams / node |
| Storage cost | <$0.01 per 1k summaries |
| Compute cost | $0 per summary |

## 6. Dependencies

- Existing: `messages` table, channel ACL middleware, Centrifugo, NATS
- New: shared `internal/services/ai/llm` package (built first by chat-assistant)
- External: Groq free tier

## 7. Observability

- Metrics:
  - `flicko_ai_message_summary_invocations_total{outcome,model}`
  - `flicko_ai_message_summary_ttfb_seconds`
  - `flicko_ai_message_summary_window_messages` histogram (p50, p95)
  - `flicko_ai_message_summary_cache_hit_ratio` gauge
  - `flicko_ai_message_summary_citations_resolved_total`, `_unresolved_total`
- Logs: structured with `channel_id`, `window_size`, `tokens_in`, `tokens_out`, `model`
- Traces: `summary.request → summary.window → summary.compress → summary.llm.stream → summary.persist`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Window > 500 msgs | LLM context overflow | hard cap + "this is a partial summary" banner |
| Channel has < 5 msgs | nothing to say | refuse with message_count meta |
| Citation `msg_id` doesn't exist (deleted mid-stream) | broken link | strip from bullet, regenerate that bullet without it |
| Groq down | block | Ollama fallback, log fallback rate |
| User loses connection mid-stream | partial UI | cache final summary keyed by request_id; client refetches via GET on reconnect |
| Spam: same user retriggers identical window | wasted compute | dedupe via cache; ratelimit ZSET still consumes 1 token to prevent abuse |
