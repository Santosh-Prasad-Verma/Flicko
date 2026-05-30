# Auto-Translate — Inline Per-Message Translation — Technical Requirements

## 1. Architecture Overview

```
              Flutter (long-press a msg)
                       │
                       ▼  POST /api/v1/ai/translate {text, src?, tgt}
   ┌──────────────────────────────────────────────────────────────┐
   │  Go backend  services/ai/auto_translate                      │
   │                                                              │
   │  1. ratelimit  (Redis ZSET 1000/day/user)                    │
   │  2. detect src if missing (fastText lid.176.bin)             │
   │  3. apply server glossary (placeholder substitution)         │
   │  4. cache lookup translations:<sha(text)>:<src>:<tgt>        │
   │     hit  -> return                                           │
   │     miss -> step 5                                           │
   │  5. provider routing:                                        │
   │       (en<->ja, en<->ko, en<->zh)  -> DeepL free quota       │
   │       all others                    -> LibreTranslate (self) │
   │       fail/quota                    -> the OTHER provider    │
   │  6. restore glossary placeholders                            │
   │  7. cache SETEX 30d                                          │
   │  8. return + persist translations row                        │
   └──────────────────────────────────────────────────────────────┘
                       │
                       ▼  200 { translated_text, src, tgt, provider }
              Flutter renders inline
```

Pipeline (input → output):

```
[message.text] -> [lid] -> [glossary mask] -> [LibreTranslate|DeepL]
              -> [glossary unmask] -> [translated_text]
```

## 2. Components

### Backend (Go)
- `backend/internal/services/ai/auto_translate/service.go`
- `backend/internal/services/ai/auto_translate/lid.go` — fastText cgo binding via `github.com/golangci/lid` (or pure-Go `github.com/abadojack/whatlanggo` fallback)
- `backend/internal/services/ai/auto_translate/libre_client.go`
- `backend/internal/services/ai/auto_translate/deepl_client.go`
- `backend/internal/services/ai/auto_translate/router.go` — picks provider per pair
- `backend/internal/services/ai/auto_translate/glossary.go` — mask/unmask
- `backend/internal/services/ai/auto_translate/cache.go`
- `backend/internal/services/ai/auto_translate/ratelimit.go`
- `backend/internal/handlers/ai_translate_handler.go`
- `backend/internal/models/ai_translate.go`
- `backend/internal/repo/ai_translate_repo.go`
- `backend/internal/services/ai/auto_translate/evals/run.go` + `golden.jsonl` (60 cases)

### Mobile (Flutter)
- `mobile/lib/features/ai_assistant/translate/data/translate_repository.dart`
- `mobile/lib/features/ai_assistant/translate/domain/translation.dart`
- `mobile/lib/features/ai_assistant/translate/application/translate_provider.dart`
- `mobile/lib/features/ai_assistant/translate/application/user_lang_pref_provider.dart`
- `mobile/lib/features/ai_assistant/translate/presentation/translate_inline_button.dart`
- `mobile/lib/features/ai_assistant/translate/presentation/translation_bubble_overlay.dart`
- `mobile/lib/features/ai_assistant/translate/presentation/translate_settings_screen.dart`
- `mobile/lib/features/ai_assistant/translate/presentation/glossary_admin_screen.dart`
- Hook into `chat_bubble.dart` to show inline button

### Infra
- DB: Supabase Postgres (migration `132`)
- Cache: Redis
- LibreTranslate: self-hosted Docker container `libretranslate/libretranslate:1.6.x` on Hetzner-EU + Hetzner-US
- DeepL: free API key, env `DEEPL_API_KEY`
- fastText model: `lid.176.bin` (126MB) baked into backend Docker image
- No Centrifugo (sync API)
- No Qdrant
- No NATS (stateless)

## 3. API Contracts

### REST

```
POST /api/v1/ai/translate
  body: {
    "text": "こんにちは",
    "src": "auto" | "ja" | "...",
    "tgt": "en",
    "context": { "server_id": "uuid", "channel_id": "uuid", "message_id": "uuid" }
  }
  resp: {
    "translated": "Hello",
    "src": "ja",
    "tgt": "en",
    "provider": "libre" | "deepl",
    "cached": true,
    "confidence": 0.97
  }

POST /api/v1/ai/translate/batch    (max 50 texts)
GET  /api/v1/ai/translate/glossary?server_id=
POST /api/v1/ai/translate/glossary
DELETE /api/v1/ai/translate/glossary/:id
GET  /api/v1/ai/translate/settings/me
PATCH /api/v1/ai/translate/settings/me
```

### Centrifugo
Not used. Translations are sync.

### Errors
- `400 invalid_pair` — src=tgt or unsupported pair
- `413 text_too_long` — >5000 chars
- `429 rate_limited`
- `503 providers_down` — both fail

## 4. Permissions & Auth

- Required: server membership for `context.server_id`
- Glossary CRUD: `role.admin`
- RLS: translation rows readable only by `requested_by`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Latency p50 (cache miss) | <350ms |
| Latency p95 (cache miss) | <900ms |
| Cache hit p99 | <30ms |
| Throughput | 200 req/s/node |
| Cache hit ratio | ≥60% |
| Cost per translation | $0 (LibreTranslate self-host) |
| Storage | <$0.005 per user/month |

## 6. Dependencies

- Existing: messages model, server membership middleware
- New libraries:
  - Go: `github.com/abadojack/whatlanggo v1.0.1` (LID), custom DeepL client (HTTP)
  - Dart: nothing new
- External: DeepL Free API (500k chars/mo), LibreTranslate (self-hosted)
- Infra: 2 LibreTranslate replicas (4GB RAM each, ~30 lang pairs preloaded)

## 7. Observability

- Metrics:
  - `flicko_ai_translate_requests_total{src,tgt,provider,outcome}`
  - `flicko_ai_translate_latency_seconds` histogram (`provider` label)
  - `flicko_ai_translate_cache_hits_total`, `_misses_total`
  - `flicko_ai_translate_lid_confidence` histogram
  - `flicko_ai_translate_provider_failures_total{provider}`
  - `flicko_ai_translate_deepl_quota_remaining` gauge (scraped daily)
- Logs: redacted text (only first 32 chars + sha256)
- Traces: `translate.lid → translate.glossary.mask → translate.provider → translate.glossary.unmask`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| LibreTranslate down | feature broken in EU | route to DeepL (US) for non-EU; show banner "EU translate paused" for EU |
| DeepL quota exhausted | en↔ja quality drops | route ja pairs to LibreTranslate, log quality regression |
| LID misdetects | wrong target language | confidence threshold 0.5; if below, ask user "pick source" |
| 5000-char overflow | rejection | client-side char counter + truncation hint |
| Glossary substitution corrupts text | bad translation | placeholder format `__GLO_<n>__` chosen to be untranslated; round-trip test in CI |
| Backslashes / emoji break LibreTranslate | garbled output | preserve emoji as ZWJ-protected; backslash-escape passthrough |
| Provider returns 200 with empty body | UI shows "" | retry once with the other provider |
