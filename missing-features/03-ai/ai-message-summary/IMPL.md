# Catch-Me-Up — AI Channel Summary — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 1d | PM/Design |
| 1 | DB migration `131_ai_summaries` | 1d | Backend |
| 2 | Window + compressor + parser | 3d | Backend |
| 3 | Service + handler + SSE | 3d | Backend |
| 4 | Mobile pill + card | 3d | Mobile |
| 5 | Citation peek sheet | 1d | Mobile |
| 6 | Eval harness (40 cases) | 2d | Backend |
| 7 | QA + a11y | 2d | QA |
| 8 | Beta + GA | 5d | All |

Total: ~21 dev days; ~3.5 weeks.

## 2. Backend Tasks

- [ ] `supabase/migrations/131_ai_summaries.up.sql` (+ `.down.sql`)
- [ ] `backend/internal/models/ai_summary.go`
- [ ] `backend/internal/repo/ai_summary_repo.go`
- [ ] `backend/internal/services/ai/message_summary/window.go` — fetch + filter messages
- [ ] `backend/internal/services/ai/message_summary/compressor.go` — emoji-only filter, dedupe, quote collapsing, truncation to 6k tokens
- [ ] `backend/internal/services/ai/message_summary/parser.go` — extract `• <text> [#msg-id]` bullets
- [ ] `backend/internal/services/ai/message_summary/cache.go` — get/set with composite key
- [ ] `backend/internal/services/ai/message_summary/ratelimit.go` — Redis ZSET 50/day
- [ ] `backend/internal/services/ai/message_summary/service.go` — orchestrator
- [ ] `backend/internal/services/ai/message_summary/prompts/summary.md` — bullet output format
- [ ] `backend/internal/services/ai/message_summary/warmer.go` — periodic top-channel warmer
- [ ] `backend/internal/handlers/ai_summary_handler.go` — `Request`, `Stream`, `Get`, `Feedback`
- [ ] Service + handler tests, table-driven, ≥80% cov
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Reuse shared `internal/services/ai/llm` from chat-assistant
- [ ] Centrifugo channel registration `summary:*`
- [ ] Audit log: `ai.summary.invoked`
- [ ] Prometheus metrics in `backend/internal/metrics/ai_summary.go`
- [ ] OpenAPI doc `backend/docs/openapi/ai_summary.yaml`
- [ ] Eval harness `evals/run.go` + 40-case `golden.jsonl`

## 3. Mobile Tasks

- [ ] `mobile/lib/features/ai_assistant/summary/data/summary_repository.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/data/summary_sse_client.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/data/dto/*.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/domain/summary.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/application/summary_provider.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/presentation/catch_me_up_pill.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/presentation/summary_card.dart`
- [ ] `mobile/lib/features/ai_assistant/summary/presentation/citation_peek_sheet.dart`
- [ ] Insert pill into `channel_messages_screen.dart` above unread separator
- [ ] Long-press menu item in `message_actions.dart` → "Summarize from here"
- [ ] Channel header `⋯` action in `channel_header.dart` → "Summarize last 24h"
- [ ] Routing: deep link `/channel/:id/summary` to focus pill
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`
- [ ] Tests: widget for `SummaryCard` (4 states), provider unit, golden for refusal card

## 4. AI / Infra Tasks

- [ ] Reuse Groq + Ollama clients from chat-assistant
- [ ] Prompt template tuned for bullet+citation output (front-matter `version: 2026.05.01`)
- [ ] Token budget: max 6k context (Groq llama3.3 has 8k); reject if compressor cannot fit window
- [ ] Cost guardrails:
  - per-user 50/day cap
  - per-channel 200/day cap (anti-abuse)
  - Groq quota dashboard alert at 80% daily
- [ ] Eval harness:
  - 40 golden windows (10 small, 20 medium, 10 large)
  - Metrics: bullet count 3-7 (must pass), citation precision ≥0.9, ROUGE-L vs human-written reference ≥0.35
  - Runs nightly via GitHub Action; fails build on regression

## 5. Files Touched (predicted)

```
backend/
  cmd/server/main.go                                                (edit)
  internal/handlers/ai_summary_handler.go                           (new)
  internal/models/ai_summary.go                                     (new)
  internal/repo/ai_summary_repo.go                                  (new)
  internal/services/ai/message_summary/service.go                   (new)
  internal/services/ai/message_summary/window.go                    (new)
  internal/services/ai/message_summary/compressor.go                (new)
  internal/services/ai/message_summary/parser.go                    (new)
  internal/services/ai/message_summary/cache.go                     (new)
  internal/services/ai/message_summary/ratelimit.go                 (new)
  internal/services/ai/message_summary/warmer.go                    (new)
  internal/services/ai/message_summary/prompts/summary.md           (new)
  internal/services/ai/message_summary/evals/run.go                 (new)
  internal/services/ai/message_summary/evals/golden.jsonl           (new)
  internal/metrics/ai_summary.go                                    (new)
  docs/openapi/ai_summary.yaml                                      (new)

mobile/
  lib/features/ai_assistant/summary/data/summary_repository.dart    (new)
  lib/features/ai_assistant/summary/data/summary_sse_client.dart    (new)
  lib/features/ai_assistant/summary/data/dto/*.dart                 (new)
  lib/features/ai_assistant/summary/domain/summary.dart             (new)
  lib/features/ai_assistant/summary/application/summary_provider.dart (new)
  lib/features/ai_assistant/summary/presentation/catch_me_up_pill.dart (new)
  lib/features/ai_assistant/summary/presentation/summary_card.dart  (new)
  lib/features/ai_assistant/summary/presentation/citation_peek_sheet.dart (new)
  lib/features/server_channels/text/presentation/channel_messages_screen.dart (edit)
  lib/features/server_channels/text/presentation/widgets/message_actions.dart (edit)
  lib/core/router/app_router.dart                                   (edit)
  lib/l10n/app_en.arb                                               (edit)

supabase/
  migrations/131_ai_summaries.up.sql                                (new)
  migrations/131_ai_summaries.down.sql                              (new)
```

## 6. Test Plan

- **Unit (Go):** ≥80% on `compressor`, `parser`, `service`, `ratelimit`
- **Unit (Dart):** providers + parsers ≥80%
- **Integration:** Postgres + Redis + mocked LLM via `httptest`
- **Eval:** runs nightly; gates merges
- **E2E (Maestro):** `summary_happy.yaml` — open channel with seeded 100 msgs, tap pill, assert ≥3 bullets and at least one citation
- **Load:** k6 — 200 concurrent SSE for 5 minutes; assert TTFB p95 <4s
- **Accessibility:** axe + manual TalkBack on bullet streaming
- **Security:**
  - cross-channel ACL bypass test
  - SSE auth check (anonymous JWT denied)
  - prompt-injection messages cannot exfil other channels' content

## 7. Rollout & Feature Flags

- Flag: `feature.ai_message_summary.enabled` (Doppler)
- Default OFF
- Beta: 5% DAU
- Canary: 5% → 25% → 100% over 14d
- Per-server kill: `server.feature_flags.ai_summary_disabled` for sensitive servers

## 8. Rollback Plan

1. Toggle Doppler flag → handler 503
2. Pill stays hidden via Remote Config
3. Cron warmer paused
4. Tables retained; no down migration needed unless data corruption

## 9. Dependencies / Blockers

- **Depends on:** chat-assistant's shared `internal/services/ai/llm` package, Centrifugo, NATS
- **Blocks:** `ai-server-insights` (reuses bullet parser)
- **External:** Groq free tier

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Bullet parser misses edge format | Med | Med | strict prompt + regex + retry-once |
| Hallucinated participant names | Low | Med | resolve participants only from window's actual senders |
| Channels with code blocks confuse model | Med | Low | preserve fenced code as `<code>...</code>` placeholder |
| Groq quota exhaustion at peak | Med | Med | warmer pre-pays popular channels, Ollama fallback |

## 11. Cost Model

| Component | Free tier? | $ at 100k DAU |
|-----------|-----------|---------------|
| Groq llama-3.3-70b | yes | $0 |
| Ollama (shared GPU) | self-hosted | $0 |
| Postgres (~80MB/mo at 100k DAU) | Supabase free | $0 |
| Redis | shared | $0 |
| R2 archive (~1 GB/mo) | first 10GB free | $0 |
| **Total** | | **$0/mo** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Migration applied in staging + prod
- [ ] Eval harness CI green for 7 nights
- [ ] Grafana board `ai-summary` live
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 in 14-day window
- [ ] `INDEX.md` flipped to `shipped`
