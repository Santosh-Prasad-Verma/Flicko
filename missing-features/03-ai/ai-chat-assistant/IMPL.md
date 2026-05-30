# Aura — Server-Aware AI Chat Assistant — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration `130_ai_aura.up.sql` | 1d | Backend |
| 2 | Embedding + Qdrant retriever | 3d | Backend |
| 3 | LLM client (Groq + Ollama) with fallback | 2d | Backend |
| 4 | Service + handler + SSE streaming | 4d | Backend |
| 5 | Indexer worker + NATS subjects | 3d | Backend |
| 6 | Mobile UI (reply card + autocomplete) | 4d | Mobile |
| 7 | Settings + KB upload screens | 3d | Mobile |
| 8 | Eval harness + 50-case golden set | 2d | Backend |
| 9 | QA + a11y audit | 2d | QA |
| 10 | Beta rollout (1% → 10%) | 5d | All |
| 11 | GA | 1d | All |

Total: ~32 dev days; ~5 weeks calendar.

## 2. Backend Tasks

- [ ] `supabase/migrations/130_ai_aura.up.sql` (+ `.down.sql`)
- [ ] `backend/internal/models/ai_aura.go` — structs for Settings, Document, Message, Feedback, Chunk
- [ ] `backend/internal/repo/ai_aura_repo.go` — sqlx queries
- [ ] `backend/internal/services/ai/chat_assistant/llm.go` — `Provider` interface, `GroqProvider`, `OllamaProvider`
- [ ] `backend/internal/services/ai/chat_assistant/embed.go` — Ollama nomic-embed-text wrapper
- [ ] `backend/internal/services/ai/chat_assistant/retriever.go` — Qdrant search + Postgres hydrate
- [ ] `backend/internal/services/ai/chat_assistant/service.go` — orchestration: ratelimit → cache → retrieve → prompt → stream → persist
- [ ] `backend/internal/services/ai/chat_assistant/indexer.go` — NATS consumer for `flicko.ai.aura.index.requested`
- [ ] `backend/internal/services/ai/chat_assistant/chunker.go` — 512/64 sliding window tokenizer
- [ ] `backend/internal/services/ai/chat_assistant/prompts/system.md`
- [ ] `backend/internal/services/ai/chat_assistant/prompts/user.md`
- [ ] `backend/internal/services/ai/chat_assistant/prompts/refuse.md`
- [ ] `backend/internal/services/ai/chat_assistant/ratelimit.go` — Redis ZSET sliding window
- [ ] `backend/internal/services/ai/chat_assistant/cache.go` — answer-cache get/set with kb_version salt
- [ ] `backend/internal/services/ai/chat_assistant/circuitbreaker.go` — groq breaker
- [ ] `backend/internal/handlers/ai_aura_handler.go` — `Invoke`, `Feedback`, `KBUpload`, `KBList`, `KBDelete`, `GetSettings`, `UpdateSettings`
- [ ] Service + handler tests, table-driven, ≥80% cov
- [ ] Wire routes in `backend/cmd/server/main.go` under `/api/v1/ai/aura/*`
- [ ] Centrifugo: register channel pattern `aura:*:*` with permission check via `ServerMembershipChecker`
- [ ] Permission middleware reuse: `RequireServerMember`, `RequireServerAdmin`
- [ ] Audit log: emit `ai.aura.invoked`, `ai.aura.kb.uploaded`, `ai.aura.settings.changed`
- [ ] Prometheus metrics in `backend/internal/metrics/ai_aura.go`
- [ ] OpenAPI doc update at `backend/docs/openapi/ai_aura.yaml`
- [ ] `backend/internal/gaming/module.go` style — register `ai/chat_assistant` module in module loader
- [ ] Eval harness `backend/internal/services/ai/chat_assistant/evals/run.go` + `golden.jsonl` (50 cases: 30 in-scope, 20 out-of-scope)

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/ai_assistant/aura/` (subfolder under existing `ai_assistant`)
- [ ] `data/aura_repository.dart` — POST invoke, KB endpoints, settings
- [ ] `data/aura_sse_client.dart` — `eventflux` wrapper, reconnect logic
- [ ] `data/dto/aura_message_dto.dart`, `aura_document_dto.dart`, `aura_settings_dto.dart`
- [ ] `domain/aura_message.dart` (entity with sealed `AuraReplyState`)
- [ ] `domain/usecases/invoke_aura.dart`, `submit_feedback.dart`, `upload_kb_doc.dart`
- [ ] `application/aura_stream_provider.dart` — Riverpod `AsyncNotifier<AuraReplyState>`
- [ ] `application/aura_settings_provider.dart`
- [ ] `application/aura_kb_provider.dart`
- [ ] `presentation/aura_reply_card.dart` (streaming text + cursor + citations)
- [ ] `presentation/aura_mention_autocomplete.dart`
- [ ] `presentation/aura_settings_screen.dart`
- [ ] `presentation/aura_kb_upload_screen.dart`
- [ ] Extend `presentation/aura_dashboard_screen.dart` with new metrics blocks
- [ ] Routing: add `/server/:id/aura/settings`, `/server/:id/aura/kb` to `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (+ es, fr, de, ja stubs)
- [ ] Tests: widget for `AuraReplyCard` (3 states), provider unit, golden for refusal card
- [ ] Empty / error / loading states wired

## 4. AI / Infra Tasks

- [ ] Ollama node: pull `nomic-embed-text` (274MB) and `llama3.1:8b` (4.7GB)
- [ ] Groq: provision 5 free-tier API keys, store in Doppler `GROQ_API_KEYS_CSV`
- [ ] Qdrant: deploy single-node + persistent volume, collection auto-create on first server enable
- [ ] NATS: subjects + consumer config in `backend/configs/nats.yaml`
- [ ] Prompt templates land in repo with version tag in front-matter `version: 2026.05.01`
- [ ] Cost guardrails:
  - server cap: 5,000 invocations/day (denial-of-service brake)
  - per-user cap: 30/day (configurable per server)
  - free-tier Groq quota dashboard alert at 80% daily
- [ ] Eval harness runs nightly via GitHub Action; fails build if recall@8 < 0.7 or refusal F1 < 0.85

## 5. Files Touched (predicted)

```
backend/
  cmd/server/main.go                                              (edit: register routes)
  internal/handlers/ai_aura_handler.go                            (new)
  internal/models/ai_aura.go                                      (new)
  internal/repo/ai_aura_repo.go                                   (new)
  internal/services/ai/chat_assistant/service.go                  (new)
  internal/services/ai/chat_assistant/indexer.go                  (new)
  internal/services/ai/chat_assistant/llm.go                      (new)
  internal/services/ai/chat_assistant/embed.go                    (new)
  internal/services/ai/chat_assistant/retriever.go                (new)
  internal/services/ai/chat_assistant/chunker.go                  (new)
  internal/services/ai/chat_assistant/cache.go                    (new)
  internal/services/ai/chat_assistant/ratelimit.go                (new)
  internal/services/ai/chat_assistant/circuitbreaker.go           (new)
  internal/services/ai/chat_assistant/prompts/system.md           (new)
  internal/services/ai/chat_assistant/prompts/user.md             (new)
  internal/services/ai/chat_assistant/prompts/refuse.md           (new)
  internal/services/ai/chat_assistant/evals/run.go                (new)
  internal/services/ai/chat_assistant/evals/golden.jsonl          (new)
  internal/metrics/ai_aura.go                                     (new)
  docs/openapi/ai_aura.yaml                                       (new)

mobile/
  lib/features/ai_assistant/aura/data/aura_repository.dart        (new)
  lib/features/ai_assistant/aura/data/aura_sse_client.dart        (new)
  lib/features/ai_assistant/aura/data/dto/*.dart                  (new)
  lib/features/ai_assistant/aura/domain/aura_message.dart         (new)
  lib/features/ai_assistant/aura/domain/usecases/*.dart           (new)
  lib/features/ai_assistant/aura/application/*.dart               (new)
  lib/features/ai_assistant/aura/presentation/*.dart              (new)
  lib/features/ai_assistant/presentation/aura_dashboard_screen.dart (edit)
  lib/core/router/app_router.dart                                 (edit)
  lib/l10n/app_en.arb                                             (edit)

supabase/
  migrations/130_ai_aura.up.sql                                   (new)
  migrations/130_ai_aura.down.sql                                 (new)
```

## 6. Test Plan

- **Unit (Go):** ≥80% on `service.go`, `retriever.go`, `chunker.go`, `cache.go`, `ratelimit.go`
- **Unit (Dart):** providers + parsers ≥80%
- **Integration (Go):** Postgres + Redis + Qdrant + mock Ollama via testcontainers; spin Centrifugo dev image
- **Eval:** `evals/run.go` runs 50-case golden set nightly. Pass criteria: recall@8 ≥0.7, citation precision ≥0.8, refusal F1 ≥0.85.
- **E2E (Maestro):** flow `aura_happy.yaml` — type `@Aura where are the rules?`, assert reply card appears with at least 1 citation
- **Load:** k6 — 100 concurrent SSE streams for 5 minutes; assert p95 TTFT <3.5s
- **Accessibility:** axe pass; manual TalkBack/VoiceOver streaming announcement test
- **Security:**
  - Prompt-injection adversarial set (10 cases)
  - RLS test: cross-server read attempt fails with 403
  - Auth: anonymous SSE upgrade rejected
  - Doc upload: upload `eicar.txt` → ClamAV blocks

## 7. Rollout & Feature Flags

- Flag: `feature.ai_chat_assistant.enabled` (Doppler) — global kill switch
- Per-server toggle: `ai_aura_settings.enabled`
- Default OFF in prod; admins must opt in
- Beta: 10 internal servers, 14d
- Canary: 1% (50 servers) → 10% (500) → 50% → 100% over 14d
- Kill-switch tested: in staging, flip flag while a stream is active and confirm graceful close

## 8. Rollback Plan

1. Flip Doppler `feature.ai_chat_assistant.enabled=false` (instant; SSE handler returns 503)
2. Stop NATS consumer `aura-indexer` worker pods (`kubectl scale deploy aura-indexer --replicas=0`)
3. Routes return 503 from middleware
4. Down migration NOT run unless data corruption — tables are cheap to keep; resuming requires only flag flip
5. Qdrant collections preserved
6. Notify admins via in-app "Aura is paused for maintenance" banner

## 9. Dependencies / Blockers

- **Depends on:** Centrifugo 5.x in cluster, Qdrant deployment, Ollama node with GPU, NATS streaming
- **Blocks:** `ai-message-summary` (reuses LLM client + prompt convention), `ai-server-insights` (reuses retriever), `ai-meeting-notes` (reuses streaming pattern)
- **External:** Groq free tier — if rate-limited persistently, must accelerate Ollama scale-up

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Groq permanently rate-limits free tier | Medium | High | Ollama-only mode pre-validated under load |
| Qdrant index corruption on upgrade | Low | High | Versioned aliases + dual-write during migration |
| Hallucination on edge cases hurts trust | Medium | Med | Hard refusal threshold + golden eval gate in CI |
| PII leak in logs (prompt content) | Med | High | Hash prompts in logs, store cleartext only in `ai_aura_messages` (RLS-protected) |
| Embedding model deprecation | Low | Med | Versioned collections, easy reembed flow |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Groq llama-3.3-70b | 30 req/min/key × 5 keys = 9,000 req/hr | $0 (within free tier; spillover to Ollama) |
| Ollama (Hetzner GPU node) | self-hosted | $0 (already owned for other AI features) |
| nomic-embed-text | local | $0 |
| Qdrant | self-hosted, 1× 4GB RAM | $0 (existing infra) |
| Redis | existing cluster | $0 |
| Postgres rows (~50MB at 100k DAU/mo) | Supabase free tier 500MB | $0 |
| Appwrite KB storage (50 docs × 5MB × 10k servers = 2.5TB) | exceeds free | $0.015/GB/mo on R2 = ~$37/mo (offset by archiving) |
| **Total** | | **~$0/mo** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] Migration applied in staging + prod
- [ ] Eval harness CI green for 7 consecutive nights
- [ ] Grafana dashboard `ai-aura` live with TTFT, refusal %, fallback %, top servers
- [ ] Beta feedback ≥4.0/5 across 10 servers
- [ ] Zero P0/P1 bugs in 14-day window
- [ ] Docs updated: `INDEX.md` status flipped from `missing` to `shipped`
- [ ] Aura answer covers "what is Aura?" using its own KB (dogfood)
