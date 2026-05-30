# Karaoke Night — Implementation

## Phase 0 — Foundation (week 0)
- Feature flag `activities.karaoke.enabled`.
- Migration `122_karaoke.sql`.
- Seed catalog: 100 PD/CC songs with curated LRC + MIDI guides via `scripts/seed_karaoke_catalog.go`.
- Provision Fly.io free VM for pitch worker (`flicko-karaoke-worker`).
- Env: `LIVEKIT_EGRESS_API`, `APPWRITE_BUCKET_KK_RECORDINGS`, `WORKER_REDIS_URL`.

## Phase 1 — Backend Skeleton (week 1)
- Module: `backend/internal/activities/karaoke/`
  - `module.go`
  - `handler.go`
  - `service.go`
  - `catalog.go`
  - `queue.go`
  - `repo.go`
  - `redis.go`
  - `egress.go`
  - `events.go`
- REST: sessions create/join/leave, signups, song search/get.

## Phase 2 — Catalog + Egress (week 2)
- Catalog admin endpoints: `POST /admin/songs/review`.
- LiveKit Egress wiring: track-egress per singer's mic, output to Appwrite via S3-compat.
- Test loop: simulated singer publishes a 30 s WAV, recording lands in bucket.

## Phase 3 — Pitch Worker (week 3)
- New repo path: `services/karaoke-worker/`
  - `worker.py`
  - `pitch.py` (librosa pyin + DTW)
  - `dockerfile`
  - `requirements.txt`
  - `fly.toml`
- Worker pulls job from Redis, downloads WAV, computes score, posts back via signed JWT.
- Reference pitch from `guide.mid` parsed at boot per song (cache in memory).

## Phase 4 — Mobile Client (week 4)
- Files:
  - `mobile/lib/features/activities/karaoke/presentation/kk_lobby_screen.dart`
  - `mobile/lib/features/activities/karaoke/presentation/kk_song_picker_screen.dart`
  - `mobile/lib/features/activities/karaoke/presentation/kk_singing_screen.dart`
  - `mobile/lib/features/activities/karaoke/presentation/kk_score_reveal_screen.dart`
  - `mobile/lib/features/activities/karaoke/presentation/widgets/lyric_scroller.dart`
  - `mobile/lib/features/activities/karaoke/presentation/widgets/mic_meter.dart`
  - `mobile/lib/features/activities/karaoke/presentation/widgets/cheer_overlay.dart`
  - `mobile/lib/features/activities/karaoke/providers/kk_session_provider.dart`
  - `mobile/lib/features/activities/karaoke/providers/kk_song_provider.dart`
  - `mobile/lib/features/activities/karaoke/providers/kk_score_provider.dart`
  - `mobile/lib/features/activities/karaoke/data/kk_repository.dart`
  - `mobile/lib/features/activities/karaoke/data/lrc_parser.dart`
- Lyric scroller renders LRC; anchor msgs from LK adjust line index live.

## Phase 5 — Sync + Cheers (week 5)
- LK data channel `kk-sync` for LyricAnchor + cue + cheer + score_ready.
- Cheer overlay with rate limit (10/s/user).
- Drift fallback: every 4 s anchor when no line transition.

## Phase 6 — Observability + Hardening (week 6)
- Prometheus counters in API and Python worker.
- Grafana dashboard `kk-overview`.
- Worker queue-depth alert.
- Load test: 8 concurrent sessions x 1 singer with 25 listeners.
- Soak: 50 songs sequentially through worker, assert p95 < 8 s.

## Phase 7 — Rollout (week 7)
- Internal dogfood (Flicko team karaoke night).
- 5% prod via flag.
- Watch songs/session, score job latency, drift p95.
- Ramp 25% → 50% → 100% over 10 days.

## Backend Task List
- [ ] sqlc gen for tables.
- [ ] Catalog admin review endpoints + minimal Retool-style admin page (basic HTML in Go).
- [ ] LK Egress trigger on `start`, finalize on `stop`.
- [ ] Egress S3 credentials → Appwrite bucket via S3 compat.
- [ ] Score job dispatcher + Redis queue.
- [ ] Score result handler with HMAC-signed callback from worker.
- [ ] Catalog full-text search using Postgres GIN.
- [ ] Rate limiters for search/signup/cheer.
- [ ] Cron: cleanup ended sessions; cheer aggregate.
- [ ] Cron: leaderboards weekly snapshot.

## Mobile Task List
- [ ] Add packages: `livekit_client`, `audioplayers`, `just_audio`, `permission_handler`, `flutter_riverpod`.
- [ ] Mic permission request flow with explainer modal.
- [ ] LRC parser + tests.
- [ ] Lyric scroller widget driven by line_index stream.
- [ ] Mic meter using `flutter_sound` for amplitude (publishing handled by LK).
- [ ] Score reveal screen with digit roll-up animation.
- [ ] Stealth mode toggle plumbing.
- [ ] Leaderboard widget on lobby.
- [ ] Route wired in `app_router.dart`: `/activities/karaoke/:sessionId`.

## Worker Task List
- [ ] Dockerfile (python:3.11-slim, librosa, ffmpeg).
- [ ] Job consumer with idempotency (job_id dedupe).
- [ ] Pitch pipeline with VAD, pyin, DTW.
- [ ] HMAC sign result before posting back.
- [ ] Healthcheck endpoint for Fly.io.
- [ ] Graceful shutdown on SIGTERM.

## Test Plan
- **Unit (Go)**: queue position math, Egress trigger logic, score callback verification.
- **Unit (Dart)**: LRC parser, scroller line transitions, score animation.
- **Unit (Python)**: pitch extraction on golden WAVs (3 known scores ±5).
- **Integration**: stub LK Egress → upload sample WAV → worker → score back.
- **E2E**: Patrol simulating singer + 3 listeners.
- **Soak**: 50 songs, queue depth never > 5.
- **Chaos**: kill worker mid-job, assert retry; drop singer mic, assert auto-stop.
- **Manual**: 8-person karaoke night dogfood.

## Rollout Plan
| Day | Audience | Gate |
|---|---|---|
| 0 | Flicko team | crash-free > 99% |
| 3 | 5% prod | worker p95 < 10 s |
| 7 | 25% prod | drift p95 < 350 ms |
| 10 | 50% prod | songs/session > 3 |
| 14 | 100% | sustained SLOs 48 h |

Rollback: flag off; in-flight songs complete, no new sessions.

## Cost Model ($0)
- LiveKit Cloud free: voice channel already used; Egress free for limited minutes (50/mo). Mitigation: only enable Egress when at least one signer signed up (avoid recording empty rooms).
- Supabase free: tables small; LRC + MIDI not stored in DB.
- Appwrite Storage: 2 GB free. Recordings auto-purged after 7 d. ~3 MB/song; 600 songs/mo cap fits in 2 GB.
- Upstash Redis free: queue depth low; ~10 ops/song.
- Fly.io free VM (256 MB): pitch worker. Single concurrency; queue handles bursts.
- Centrifugo on Fly.io free VM (shared with watch-together).
- Total: $0 within free tiers; first paid trigger is LK Egress minutes if usage explodes — cap at 50 sessions/mo via flag if needed.
