# Server Soundboard — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, design review, ffmpeg + LiveKit data-track spike | 2d | PM/Design + 1 BE |
| 1 | DB migration `127_server_soundboard` | 1d | Backend |
| 2 | Service + handler + cooldown + permissions | 2d | Backend |
| 3 | Transcode worker (NATS + ffmpeg) | 1.5d | Backend |
| 4 | Default clips: curate 24 clips, seed table, ingest job | 1.5d | Content + BE |
| 5 | LiveKit data-track wire-up (server publish + client subscribe) | 1d | Both |
| 6 | Mobile soundboard sheet (extend existing stub) | 2d | Mobile |
| 7 | Mobile upload + manage screens | 1.5d | Mobile |
| 8 | Mobile in-call visual indicator + audio mixer | 1.5d | Mobile |
| 9 | Mod settings + role perms UI | 1d | Mobile |
| 10 | QA + load + a11y audit | 2d | QA |
| 11 | Beta → GA rollout | 5d | All |

Total: ~22 working days.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/127_server_soundboard.up.sql` and `.down.sql`.
- [ ] Model `backend/internal/models/soundboard.go`.
- [ ] Repo `backend/internal/repo/soundboard_repo.go`.
- [ ] Cooldown helper `backend/internal/services/soundboard/cooldown.go`.
- [ ] Service `backend/internal/services/soundboard_service.go`:
  - `ListClips`, `Upload`, `Update`, `Delete`, `Play`.
  - `GetSettings`, `UpdateSettings`.
  - `Report`.
- [ ] Audio normalize helper `backend/internal/services/soundboard/audio_normalize.go` (ffmpeg wrapper).
- [ ] Transcode worker `backend/internal/services/soundboard/transcode_worker.go`.
- [ ] Auto-disable worker `backend/internal/services/soundboard/autodisable_worker.go` (cron 1m).
- [ ] Handler `backend/internal/handlers/soundboard_handler.go`.
- [ ] Wire routes in `backend/cmd/server/main.go`.
- [ ] Permission middleware: extend `permissions_service.go::HasServerPermission` to accept `SOUNDBOARD_PLAY|UPLOAD|MANAGE`.
- [ ] LiveKit publish helper `backend/internal/services/voice/livekit_data.go::PublishSoundboardPlay`.
- [ ] Centrifugo publishes for library updates.
- [ ] Audit log entries on every state change.
- [ ] Metrics + Sentry tags.
- [ ] OpenAPI doc update.
- [ ] Service test: ≥80% cov.
- [ ] Handler test: permission matrix, cooldown, 429 retry-after, 422 disabled.
- [ ] Default clips loader `backend/internal/services/soundboard/default_loader.go` runs at boot if `soundboard_default_clips` row count = 0; reads `backend/migrations/data/sb_default_clips.json`.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/server_soundboard/`.
- [ ] Data: dto + repository + datasource (HTTPS + LiveKit data subscribe).
- [ ] Domain: entity (`SoundboardClip`, `Cooldown`, `PlayResult`), usecases.
- [ ] Application:
  - `soundboardClipsProvider(serverId)`,
  - `cooldownProvider(serverId, userId)`,
  - `playClipProvider`,
  - `recentClipsProvider(roomSid)`.
- [ ] Presentation:
  - extend `mobile/lib/features/voice/presentation/soundboard_sheet.dart`,
  - new `clip_upload_screen.dart`, `clip_manage_screen.dart`, `soundboard_settings_screen.dart`,
  - widgets: `clip_chip.dart`, `cooldown_ring.dart`, `recent_clips_drawer.dart`, `visual_play_indicator.dart`.
- [ ] Audio mixer `mobile/lib/features/voice/services/soundboard_audio_mixer.dart`:
  - subscribes to LiveKit data-track topic `soundboard.play`,
  - resolves signed URL, plays via `just_audio`,
  - ducks the LiveKit voice mix by 25% during playback,
  - never plays clip the local user just triggered (avoids double-fire).
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (~22 strings).
- [ ] Tests: widget, provider, golden, mixer integration.
- [ ] States: empty (defaults always present), loading, cooldown, forbidden, upload-progress, processing, error.

## 4. AI / Infra Tasks

- [ ] Appwrite bucket `soundboard-clips` with policies.
- [ ] NATS subjects:
  - `flicko.soundboard.transcode`,
  - `flicko.soundboard.transcode.dlq`.
- [ ] Cloudflare in front for opus egress.
- [ ] Grafana dashboard `soundboard`.
- [ ] Sentry tags + alerts.
- [ ] Curate 24 default clips (Flicko-original sounds, royalty-free) under `backend/migrations/data/sb_default_clips/*.opus`.

## 5. Files Touched (predicted)

```
backend/
  internal/models/soundboard.go                                 (new)
  internal/repo/soundboard_repo.go                              (new)
  internal/services/soundboard_service.go                       (new)
  internal/services/soundboard_service_test.go                  (new)
  internal/services/soundboard/cooldown.go                      (new)
  internal/services/soundboard/audio_normalize.go               (new)
  internal/services/soundboard/transcode_worker.go              (new)
  internal/services/soundboard/autodisable_worker.go            (new)
  internal/services/soundboard/default_loader.go                (new)
  internal/services/voice/livekit_data.go                       (edit)
  internal/services/permissions_service.go                      (edit)
  internal/handlers/soundboard_handler.go                       (new)
  internal/handlers/soundboard_handler_test.go                  (new)
  cmd/server/main.go                                            (edit)
  migrations/data/sb_default_clips.json                         (new)
  migrations/data/sb_default_clips/*.opus                       (new ×24)
mobile/
  lib/features/server_soundboard/...                            (new tree)
  lib/features/voice/presentation/soundboard_sheet.dart         (rewrite)
  lib/features/voice/services/soundboard_audio_mixer.dart       (new)
  lib/core/router/app_router.dart                               (edit)
  lib/l10n/app_en.arb                                           (edit)
  test/features/server_soundboard/...                           (new)
supabase/
  migrations/127_server_soundboard.up.sql                       (new)
  migrations/127_server_soundboard.down.sql                     (new)
```

## 6. Test Plan

- Unit: service ≥80%, cooldown ≥95%, normalize ≥80%.
- Integration: Postgres + Redis + NATS + LiveKit-test-server (containerized) — full upload→transcode→play→fan-out.
- Golden: chip grid in dark/light/AMOLED at 4 cell sizes.
- E2E (Patrol): mod uploads, member plays in voice room, verifies all peers hear.
- Load: k6 — 200 plays/sec sustained 5 min; verify p95 latency.
- Audio quality: a11y team subjectively confirms loudness consistency on 5 sample clips at -16 LUFS.
- Accessibility: TalkBack labels for chips include duration + cooldown remaining; visual indicator visible during play.
- Security: malformed audio (non-audio with `audio/mpeg` MIME), exif bombs (n/a), SHA collision check.
- Privacy: confirm transcoded files have no id3 metadata.

## 7. Rollout & Feature Flags

- Flag: `feature.server_soundboard.enabled` (Doppler / `flicko_feature_flags`).
- Default OFF in prod.
- Beta cohort: 3 internal staff servers + 30 invited.
- Canary: 1% of servers (24h) → 10% (24h) → 50% (24h) → 100% over 4 days.
- Per-server kill switch: `soundboard_settings.global_play_rate=0` halts plays.

## 8. Rollback Plan

1. Disable `feature.server_soundboard.enabled` flag — UI hides; backend stops accepting POSTs.
2. Existing clips remain in DB; safe to leave on disable.
3. Stop transcode workers (reduce noise; in-flight rows mark `failed` after retry).
4. Down migration only if data corruption — drops blob references; orphaned blobs cleaned by 24h cron.

## 9. Dependencies / Blockers

- Depends on: LiveKit (live), Redis (live), Appwrite (live), `voice_service`, `permissions_service`, `moderation_service` hash check.
- Blocks: nothing critical.
- External: ffmpeg system package on Railway image (already present for voice transcode).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Spam plays even with cooldown | M | M | Per-server global rate cap; auto-disable on reports |
| LiveKit data-track loss in giant rooms | L | M | Server logs play; `recent` endpoint as fallback |
| ffmpeg crash on malformed file | M | M | Process isolation; 8s hard timeout; retry once |
| NSFW audio uploaded | M | H | Hash check + report flow + auto-disable |
| Cooldown Redis flush | L | L | In-process fallback cap 5s/user |
| Mobile `just_audio` plugin collision with LiveKit audio session | M | M | Mixer service centralizes both; manual session category set |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU / 5k servers |
|-----------|-----------|--------------------------------------|
| Compute (POST + workers) | Railway free | $0 (low rps) |
| Postgres rows | Supabase free | $0 (<50MB) |
| Appwrite storage (5k servers × 12 clips × 32 KB opus) | Appwrite free | $0 (<2 GB) |
| Egress (CDN cached aggressively) | Cloudflare free | $0 |
| LiveKit data tracks | included | $0 |
| **Total** | | **<$1/mo** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Migration applied to staging and dogfood.
- [ ] 24 default clips seeded and loadable.
- [ ] LiveKit data-track end-to-end tested with 4 peers.
- [ ] Code merged to main behind flag.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥ 4.0/5 (n ≥ 30 servers).
- [ ] Zero P0/P1 bugs in 7-day window.
- [ ] L10n strings translated for the top 6 locales.
- [ ] Loudness on default clips verified consistent at -16 LUFS.
