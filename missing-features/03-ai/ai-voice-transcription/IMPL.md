# Live Voice Captions — Whisper.cpp Transcription — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 2d | PM/Design |
| 1 | DB migration `133` | 1d | Backend |
| 2 | Azure ACS Track Egress sink | 3d | Voice |
| 3 | whisper.cpp cgo wrapper + pool | 4d | Backend |
| 4 | silero-vad ONNX runtime | 2d | Backend |
| 5 | Segmenter + publisher | 3d | Backend |
| 6 | REST handlers + sessions | 2d | Backend |
| 7 | Mobile overlay + settings | 4d | Mobile |
| 8 | Late-join modal + export | 2d | Mobile |
| 9 | WER eval harness | 3d | Backend |
| 10 | a11y review + QA | 3d | QA |
| 11 | Beta + GA | 7d | All |

Total: ~36 dev days; ~6 weeks.

## 2. Backend Tasks

- [ ] `supabase/migrations/133_ai_voice_captions.up.sql` (+ down)
- [ ] `backend/internal/models/voice_transcript.go`
- [ ] `backend/internal/repo/voice_transcript_repo.go`
- [ ] `backend/internal/services/ai/voice_transcription/azure_acs_egress.go` — connect as Egress sink, decode Opus → PCM
- [ ] `backend/internal/services/ai/voice_transcription/vad.go` — silero-vad ONNX
- [ ] `backend/internal/services/ai/voice_transcription/whisper_pool.go` — worker pool wrapping whisper.cpp cgo
- [ ] `backend/internal/services/ai/voice_transcription/segmenter.go`
- [ ] `backend/internal/services/ai/voice_transcription/publisher.go`
- [ ] `backend/internal/services/ai/voice_transcription/worker.go` — long-lived per-channel worker
- [ ] `backend/internal/services/ai/voice_transcription/orchestrator.go` — listens to NATS `flicko.voice.session.*`, spawns/kills workers
- [ ] `backend/internal/services/ai/voice_transcription/profanity.go` — wordlist + regex masker
- [ ] `backend/internal/services/ai/voice_transcription/archive.go` — nightly export to R2
- [ ] `backend/internal/handlers/ai_captions_handler.go`
- [ ] `cmd/server/main.go` register routes
- [ ] Worker process: `cmd/captions-worker/main.go` (separate binary deployed as Kubernetes deployment)
- [ ] Dockerfile: install whisper.cpp + onnxruntime + models
- [ ] Audit log: `ai.captions.session.started/ended`, `ai.captions.enabled/disabled`
- [ ] Prometheus metrics in `internal/metrics/ai_captions.go`
- [ ] OpenAPI doc
- [ ] WER eval harness: 50 audio clips with reference transcripts; CI gate WER < 12% en

## 3. Mobile Tasks

- [ ] `mobile/lib/features/ai_assistant/captions/data/captions_repository.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/data/captions_centrifugo_client.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/domain/caption.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/application/captions_provider.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/application/captions_user_pref_provider.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/presentation/captions_overlay.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/presentation/captions_settings_sheet.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/presentation/captions_admin_screen.dart`
- [ ] `mobile/lib/features/ai_assistant/captions/presentation/late_join_transcript_modal.dart`
- [ ] Hook into `voice_channel_screen.dart` — toggle button + overlay slot
- [ ] Routing: `/channel/:id/captions/admin`, `/channel/:id/transcript/:session_id`
- [ ] L10n
- [ ] Tests: provider, widget, golden for overlay states

## 4. AI / Infra Tasks

- [ ] whisper.cpp v1.7.x compiled with AVX2/F16C; baked into worker image
- [ ] Models on shared NFS volume (or downloaded on pod start with sha256 verification)
  - `models/whisper-tiny.en.bin` 75MB
  - `models/whisper-small.en.bin` 488MB
  - `models/whisper-small.bin` (multi) 488MB
- [ ] silero-vad.onnx 1.7MB committed in repo
- [ ] No LLM cost
- [ ] Cost guardrails:
  - max 8 concurrent channels per worker pod
  - `tiny.en` fallback under load
  - per-channel cap 6h continuous (auto-stop with notice)
- [ ] WER eval (50 clips, 5 langs) nightly

## 5. Files Touched

```
backend/
  cmd/server/main.go                                                        (edit)
  cmd/captions-worker/main.go                                               (new)
  internal/handlers/ai_captions_handler.go                                  (new)
  internal/models/voice_transcript.go                                       (new)
  internal/repo/voice_transcript_repo.go                                    (new)
  internal/services/ai/voice_transcription/orchestrator.go                  (new)
  internal/services/ai/voice_transcription/worker.go                        (new)
  internal/services/ai/voice_transcription/azure_acs_egress.go                (new)
  internal/services/ai/voice_transcription/vad.go                           (new)
  internal/services/ai/voice_transcription/whisper_pool.go                  (new)
  internal/services/ai/voice_transcription/segmenter.go                     (new)
  internal/services/ai/voice_transcription/publisher.go                     (new)
  internal/services/ai/voice_transcription/profanity.go                     (new)
  internal/services/ai/voice_transcription/archive.go                       (new)
  internal/services/ai/voice_transcription/evals/run.go                     (new)
  internal/services/ai/voice_transcription/evals/clips/                     (new dir, audio + ref)
  internal/metrics/ai_captions.go                                           (new)
  docs/openapi/ai_captions.yaml                                             (new)
  Dockerfile.captions-worker                                                (new)

mobile/
  lib/features/ai_assistant/captions/data/captions_repository.dart                  (new)
  lib/features/ai_assistant/captions/data/captions_centrifugo_client.dart           (new)
  lib/features/ai_assistant/captions/domain/caption.dart                            (new)
  lib/features/ai_assistant/captions/application/*.dart                             (new)
  lib/features/ai_assistant/captions/presentation/*.dart                            (new)
  lib/features/server_channels/voice/presentation/voice_channel_screen.dart         (edit)
  lib/core/router/app_router.dart                                                   (edit)
  lib/l10n/app_en.arb                                                               (edit)

supabase/
  migrations/133_ai_voice_captions.up.sql                                   (new)
  migrations/133_ai_voice_captions.down.sql                                 (new)

infra/
  k8s/captions-worker-deployment.yaml                                       (new)
  k8s/captions-worker-hpa.yaml                                              (new)
```

## 6. Test Plan

- Unit (Go): VAD framing, segmenter, profanity masker, publisher
- Integration: in-memory PCM fixture → whisper → assert text within edit-distance
- Eval (nightly): WER on 50 clips
- E2E (Maestro): join voice room with synthetic playback → assert ≥3 captions emitted
- Load: spin 32 sim channels per pod for 30 min; assert no OOM, p95 latency <2s
- Accessibility: TalkBack/VoiceOver streaming announcement, color contrast at all sizes
- Security: Centrifugo subscription requires server-issued JWT with channel claim

## 7. Rollout & Feature Flags

- Flag: `feature.ai_voice_transcription.enabled`
- Per-channel toggle defaults OFF
- Beta: 5 internal voice channels, 7d
- Canary: 5% → 25% → 100% over 14d
- Kill switch tested: orchestrator stops all workers on flag flip

## 8. Rollback Plan

1. Doppler flag → orchestrator stops spawning, kills active workers
2. Mobile UI: CC toggle hidden via remote config
3. Tables retained
4. Workers scale to 0

## 9. Dependencies / Blockers

- Depends on: Azure ACS Track Egress, Centrifugo, NATS
- Blocks: `ai-meeting-notes` (reuses transcripts)
- External: none

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CPU cost balloon | High | Med | tiny.en fallback + HPA + per-channel concurrency cap |
| Whisper hallucination on silence | Med | Low | strict VAD + min duration + min confidence |
| Mis-attribution due to track confusion | Low | High | per-track Egress tested in integration |
| GDPR concern over transcripts | Med | High | retention 30d default, per-channel override, GDPR cascade |
| Multilingual drift on auto-language | Med | Med | language-detect first 10s, sticky thereafter |

## 11. Cost Model

| Component | Free tier? | $ at 100k DAU |
|-----------|-----------|---------------|
| Whisper.cpp (CPU) | self-hosted | ~$80/mo for 4 dedicated nodes (existing) |
| silero-vad | local | $0 |
| Postgres (~500MB/mo if 1k channels active) | shared | $0 |
| R2 archive (~10GB/mo) | first 10GB free | $0 |
| **Total** | | **$0 incremental** (existing CPU budget) |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Migration applied prod
- [ ] WER < 12% en for 7 nights
- [ ] Grafana board live
- [ ] Beta accessibility user signoff
- [ ] Zero P0/P1 in 14d
- [ ] `INDEX.md` flipped to shipped
