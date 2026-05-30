# Audio Descriptions — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + prompt eval (n=200 images) | 3d | AI/PM |
| 1 | Migration 255 + models | 1d | Backend |
| 2 | NSFW filter wiring + vision client (Groq + Ollama) | 2d | Backend |
| 3 | Worker + NATS + Centrifugo plumbing | 2d | Backend |
| 4 | Author override + report endpoints | 1d | Backend |
| 5 | Mobile UI: describe button, sheet, alt-text editor | 3d | Mobile |
| 6 | TTS integration + auto-play setting | 1d | Mobile |
| 7 | Tests: unit, integration, hallucination QA | 3d | QA |
| 8 | Beta with screen-reader cohort | 5d | All |
| 9 | GA + cost dashboards | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/255_audio_descriptions.up.sql`
- [ ] Down migration
- [ ] Model `backend/internal/models/audio_desc.go`
- [ ] Repo `backend/internal/repo/audio_desc_repo.go`
- [ ] Service `backend/internal/services/accessibility/audio_desc/service.go`
- [ ] Worker `backend/internal/services/accessibility/audio_desc/worker.go`
- [ ] NSFW wrapper `backend/internal/services/accessibility/audio_desc/nsfw.go`
- [ ] Prompt template `backend/internal/services/accessibility/audio_desc/prompts/v1.txt`
- [ ] Vision client `backend/internal/services/ai/vision/client.go` with Groq + Ollama backends
- [ ] Service tests (table-driven, ≥80% cov)
- [ ] Handler `backend/internal/handlers/accessibility/audio_desc_handler.go`
- [ ] Handler tests
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo channel hookup `attachment:<id>`
- [ ] Permission middleware: viewer-read, owner+admin-write
- [ ] Audit log entries on author override and report
- [ ] Metrics counters (latency, cost, cache-hit)
- [ ] OpenAPI doc update
- [ ] Janitor cron for stuck "running" jobs (>60s)

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/accessibility/audio_descriptions/`
- [ ] Data: `audio_desc_repository.dart`, dto, datasource
- [ ] Domain: `audio_description.dart`, `audio_desc_source.dart`
- [ ] Application: `audio_desc_provider.dart`, `tts_player_controller.dart`
- [ ] Presentation:
  - `presentation/widgets/describe_button.dart`
  - `presentation/widgets/alt_text_editor.dart`
  - `presentation/widgets/audio_desc_inline_banner.dart`
  - `presentation/screens/description_sheet.dart`
  - `presentation/screens/audio_desc_settings_screen.dart`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys
- [ ] Cross-cutting:
  - `mobile/lib/features/server_channels/.../message_attachment.dart` — wire describe button
  - `mobile/lib/features/server_channels/.../upload_sheet.dart` — alt-text field
- [ ] Tests: widget + provider + golden + Patrol describe-and-listen flow
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] Ollama LLaVA-NeXT-7B local (dev)
- [ ] Groq vision endpoint configured (Llama 3.2 11B)
- [ ] Prompt templates with golden eval set (n=50 manually verified)
- [ ] Cost guardrails: per-server $5/day cap (Doppler config)
- [ ] Eval harness `backend/cmd/audio_desc_eval/main.go` with golden cases
- [ ] Hallucination scoring: cosine similarity vs. ground-truth alt-text on dev set

## 5. Files Touched (predicted)

```
backend/
  internal/services/accessibility/audio_desc/service.go             (new)
  internal/services/accessibility/audio_desc/worker.go              (new)
  internal/services/accessibility/audio_desc/nsfw.go                (new)
  internal/services/accessibility/audio_desc/prompts/v1.txt         (new)
  internal/services/accessibility/audio_desc/service_test.go        (new)
  internal/services/ai/vision/client.go                             (new)
  internal/services/ai/vision/groq.go                               (new)
  internal/services/ai/vision/ollama.go                             (new)
  internal/handlers/accessibility/audio_desc_handler.go             (new)
  internal/handlers/accessibility/audio_desc_handler_test.go        (new)
  internal/models/audio_desc.go                                     (new)
  internal/repo/audio_desc_repo.go                                  (new)
  cmd/server/main.go                                                (edit)
  cmd/audio_desc_eval/main.go                                       (new tool)

mobile/
  lib/features/accessibility/audio_descriptions/...                 (new tree)
  lib/features/server_channels/.../message_attachment.dart          (edit)
  lib/features/server_channels/.../upload_sheet.dart                (edit)
  lib/core/router/app_router.dart                                   (edit)
  lib/l10n/app_en.arb                                               (edit)

supabase/
  migrations/255_audio_descriptions.up.sql                          (new)
  migrations/255_audio_descriptions.down.sql                        (new)
```

## 6. Test Plan

- **Unit:** ≥80% on service/worker/repo; mocks for vision client and NSFW.
- **Integration:** Postgres + Redis + NATS + Centrifugo via testcontainers; end-to-end describe flow.
- **E2E:** Patrol — upload, wait <5 s, describe button reads "A …".
- **Hallucination QA:** weekly sample of 50 descriptions vs. manual labels; track precision.
- **Load:** k6 — 50 image uploads/s for 5 minutes; expect p99 < 5 s.
- **Accessibility:** describe button + sheet pass screen reader.
- **Security:** force re-run rate-limited; manual override authz on owner/admin only.

## 7. Rollout & Feature Flags

- Flag: `feature.audio_descriptions.enabled` (default OFF, server-by-server opt-in).
- Sub-flag: `feature.audio_descriptions.auto_play_on_focus` (user pref default OFF).
- Beta: 10 internal servers + 5 self-id'd blind tester servers.
- Canary: 5% → 25% → 100% over 7 days.
- Kill switch: turning flag off skips NATS publish; UI hides describe button.

## 8. Rollback Plan

1. Disable flag.
2. Worker drains NATS queue without LLM calls.
3. Existing descriptions remain readable (cached).
4. Down migration only if data corruption found; else leave columns in place.

## 9. Dependencies / Blockers

- Depends on: `attachment_service`, `safety_service` (NSFW), `nats_publisher`, `centrifugo`.
- Blocks: WCAG AA conformance claim depends on this.
- External: Groq vision API quota (apply for higher tier 1 week ahead).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hallucinations | High | Med | Author override; report flow; cap temperature |
| Cost overrun | Med | High | Per-server cap; cache; degrade to no-desc |
| Vision API outage | Med | Low | Fallback "image, no description"; retry; circuit-breaker |
| Privacy concerns about content sent to Groq | Med | Med | Hash logging only; opt-out per server flag |
| NSFW false negative | Low | High | Manual override + report queue |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (worker) | Railway free | $0 |
| DB (cache rows) | Supabase free | $0 |
| AI (Groq vision @ ~$0.0008/call, ~30% non-cached) | partial | ~$72/day |
| Storage | n/a | $0 |
| **Total** | | **~$2.2k/mo** at scale; below targeted $0.005/AT-user/day |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Hallucination rate <3% in weekly QA sample
- [ ] p99 latency <5 s
- [ ] Cost dashboards live with per-server breakdown
- [ ] Beta feedback ≥4.4/5 from blind testers
- [ ] Zero P0/P1 bugs in 14-day window post-GA
- [ ] WCAG SC 1.1.1 conformance documented
