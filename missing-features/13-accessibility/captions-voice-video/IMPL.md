# Captions for Voice/Video — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec + ASR eval (LibriSpeech WER, Groq vs faster-whisper) | 4d | AI/PM |
| 1 | Migration 258 + models | 1d | Backend |
| 2 | Caption pipeline + ASR client | 4d | Backend |
| 3 | Centrifugo publisher + consent flow | 2d | Backend |
| 4 | SRT exporter + janitor | 1d | Backend |
| 5 | Mobile data + provider | 2d | Mobile |
| 6 | Captions overlay widget + drag-to-reposition | 3d | Mobile |
| 7 | Settings screen + admin server toggle | 2d | Mobile |
| 8 | Tests: unit + integration + Patrol | 4d | QA |
| 9 | Beta with deaf testers | 7d | All |
| 10 | GA + cost dashboards | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/258_accessibility_captions.up.sql`
- [ ] Down migration
- [ ] Model `backend/internal/models/caption.go`
- [ ] Repo `backend/internal/repo/caption_repo.go`
- [ ] Service `backend/internal/services/accessibility/captions/service.go`
- [ ] Pipeline `backend/internal/services/accessibility/captions/pipeline.go` (VAD + chunk)
- [ ] Publisher `backend/internal/services/accessibility/captions/publisher.go` (Centrifugo)
- [ ] ASR client `backend/internal/services/ai/asr/streaming_client.go`
- [ ] ASR backends: `groq.go`, `faster_whisper.go`
- [ ] Service tests (table-driven, ≥80% cov)
- [ ] Handler `backend/internal/handlers/accessibility/captions_handler.go`
  - GET /captions, GET /captions.srt, POST /captions/consent, server admin enable/disable
- [ ] Handler tests
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo channel registration `voice:<channel_id>:captions`
- [ ] Permission middleware: members for read; host/admin for export
- [ ] Audit log entries on server-level enable/disable
- [ ] Metrics counters `flicko_captions_*`
- [ ] OpenAPI doc update
- [ ] Janitor cron: drop partitions >7d, evict Redis stream after 30 min
- [ ] SRT writer with consent-gap handling

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/accessibility/captions/`
- [ ] Data: `captions_repository.dart`, `caption_segment_dto.dart`, `captions_websocket.dart`
- [ ] Domain: `caption_segment.dart`, `caption_speaker.dart`
- [ ] Application: `captions_provider.dart`, `speaker_palette_provider.dart`, `srt_exporter.dart`
- [ ] Presentation:
  - `presentation/widgets/captions_overlay.dart`
  - `presentation/widgets/captions_toggle_button.dart`
  - `presentation/widgets/caption_position_picker.dart`
  - `presentation/widgets/caption_size_picker.dart`
  - `presentation/widgets/speaker_color_chip.dart`
  - `presentation/widgets/consent_banner.dart`
  - `presentation/screens/captions_settings_screen.dart`
  - `presentation/screens/admin_captions_settings_screen.dart`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys
- [ ] Cross-cutting:
  - `mobile/lib/features/voice/.../voice_call_screen.dart` — overlay
  - `mobile/lib/features/voice/.../voice_controls_bar.dart` — CC button
  - `mobile/lib/features/calling/.../video_call_screen.dart` — overlay
- [ ] Tests: widget + provider + golden + Patrol full-call flow
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] Groq Whisper streaming endpoint configured (key in Doppler)
- [ ] faster-whisper local container for dev
- [ ] WER eval harness `backend/cmd/captions_eval/main.go` against LibriSpeech subset
- [ ] Cost guardrails: per-server $30/day cap
- [ ] Privacy review: ensure no PII logged in caption text traces

## 5. Files Touched (predicted)

```
backend/
  internal/services/accessibility/captions/service.go        (new)
  internal/services/accessibility/captions/pipeline.go       (new)
  internal/services/accessibility/captions/publisher.go      (new)
  internal/services/accessibility/captions/service_test.go   (new)
  internal/services/ai/asr/streaming_client.go               (new)
  internal/services/ai/asr/groq.go                           (new)
  internal/services/ai/asr/faster_whisper.go                 (new)
  internal/handlers/accessibility/captions_handler.go        (new)
  internal/handlers/accessibility/captions_handler_test.go   (new)
  internal/models/caption.go                                 (new)
  internal/repo/caption_repo.go                              (new)
  cmd/server/main.go                                         (edit)
  cmd/captions_eval/main.go                                  (new)

mobile/
  lib/features/accessibility/captions/...                    (new tree)
  lib/features/voice/.../voice_call_screen.dart              (edit)
  lib/features/voice/.../voice_controls_bar.dart             (edit)
  lib/features/calling/.../video_call_screen.dart            (edit)
  lib/core/router/app_router.dart                            (edit)
  lib/l10n/app_en.arb                                        (edit)

supabase/
  migrations/258_accessibility_captions.up.sql               (new)
  migrations/258_accessibility_captions.down.sql             (new)
```

## 6. Test Plan

- **Unit:** ≥80% coverage on pipeline, publisher, repo, SRT writer, palette mapping.
- **Integration:** Postgres + Redis + NATS + Centrifugo via testcontainers; play canned WAV through SFU stub, assert captions arrive within 2s.
- **E2E:** Patrol — start call, speak via injected audio, expect captions; toggle position; export SRT.
- **Load:** k6 — 50 concurrent calls × 5 speakers each for 5 min; assert p99 latency.
- **Accessibility:** captions overlay passes screen reader live region.
- **Security:** consent enforcement tested (publish without consent → no DB rows).

## 7. Rollout & Feature Flags

- Flag: `feature.captions_voice_video.enabled` (default OFF — server admin opt-in).
- Sub-flag: `feature.captions_voice_video.persist.enabled` (default OFF; controls SRT export availability).
- Beta: 10 internal servers + 5 deaf-tester servers.
- Canary: 5% → 25% → 100% over 7 days.
- Kill switch: turning the flag off disables ASR pipeline; UI hides CC button.

## 8. Rollback Plan

1. Disable flag — pipeline workers stop accepting new calls.
2. In-flight captions cease at next call end.
3. Existing data remains readable.
4. Down migration only if data corruption found.

## 9. Dependencies / Blockers

- Depends on: `voice_service` (SFU), `centrifugo`, `nats_publisher`, `safety_service`.
- Blocks: WCAG SC 1.2.4 conformance.
- External: Groq Whisper streaming quota.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WER above target on noisy mics | Med | Med | Show partial in italic; let users disable |
| Cost overrun | Med | High | Daily cap; warn admins |
| Privacy: caption persisted without consent | Low | High | Strict consent gate; tabletop threat model |
| Speaker mis-attribution | Med | Med | Use SFU publisher token; flag mismatches |
| ASR API outage | Med | Low | faster-whisper fallback |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (caption pipeline workers) | Railway | $200/mo |
| DB (partitioned segments) | Supabase | $30/mo |
| AI (Groq Whisper streaming, ~$0.0006/min × ~200k voice-min/day) | partial | ~$3.6k/mo |
| Storage (Appwrite SRT) | partial | ~$30/mo |
| **Total** | | **~$3.9k/mo** at scale; below targeted $0.0006/voice-min |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] WER <8% on benchmark
- [ ] p99 latency <3.5 s
- [ ] Cost dashboards live with per-server breakdown
- [ ] Consent ledger audit-clean
- [ ] Beta feedback ≥4.5/5 from deaf cohort
- [ ] Zero P0/P1 bugs in 14-day window post-GA
- [ ] WCAG SC 1.2.4 conformance documented
