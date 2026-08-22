# Watch Together — Implementation

## Phase 0 — Foundation (week 0)
- Add feature flag `activities.watch_together.enabled` in Supabase `feature_flags`.
- Migration `120_watch_together.sql` applied.
- Azure ACS project room template `wt-room` configured with data-channel grants.
- Add structured logger fields `feature=wt`.

## Phase 1 — Backend Skeleton (week 1)
- Module: `backend/internal/activities/watchtogether/`
  - `module.go` — Chi router, DI wiring.
  - `handler.go` — REST endpoints.
  - `service.go` — domain logic.
  - `repo.go` — Postgres queries (sqlc).
  - `redis.go` — hot-state cache.
  - `azure_acs.go` — token mint + grants.
  - `events.go` — Centrifugo publishers.
- Implement `POST /sessions`, `POST /join`, `GET /sessions/:id`, `DELETE /sessions/:id`.
- Wire into `backend/internal/gaming/module.go` registration pattern (mirror existing module loader).

## Phase 2 — Sync Engine (week 2)
- Anchor publish endpoint `POST /sessions/:id/anchor` (rate-limited 60/min).
- Anchor read endpoint `GET /sessions/:id/anchor` for late joiners.
- Define `SyncFrame` msgpack schema in `backend/pkg/wtproto/syncframe.go`.
- Generate Dart equivalent in `mobile/lib/features/activities/watch_together/proto/sync_frame.dart`.
- Drift correction utility `mobile/lib/features/activities/watch_together/sync/drift_engine.dart`.

## Phase 3 — Mobile Player (week 3)
- Files:
  - `mobile/lib/features/activities/watch_together/presentation/wt_picker_screen.dart`
  - `mobile/lib/features/activities/watch_together/presentation/wt_source_screen.dart`
  - `mobile/lib/features/activities/watch_together/presentation/wt_player_screen.dart`
  - `mobile/lib/features/activities/watch_together/presentation/widgets/sync_indicator.dart`
  - `mobile/lib/features/activities/watch_together/presentation/widgets/reaction_overlay.dart`
  - `mobile/lib/features/activities/watch_together/providers/wt_session_provider.dart`
  - `mobile/lib/features/activities/watch_together/providers/wt_player_controller.dart`
  - `mobile/lib/features/activities/watch_together/data/wt_repository.dart`
  - `mobile/lib/features/activities/watch_together/data/azure_acs_data_channel.dart`
- Use `youtube_player_iframe` for YT, `video_player` for MP4/HLS, `webview_flutter` for Vimeo.
- Riverpod state: `wtSessionProvider`, `wtPlayerProvider`, `wtParticipantsProvider`.

## Phase 4 — Host Election + Handoff (week 4)
- Azure ACS webhook endpoint `POST /webhooks/azure_acs` parses `participant_left`.
- Election job using Redis `SETNX wt:s:{id}:host_lock` 5 s.
- Manual handoff `POST /sessions/:id/host`.
- Mobile: "You're the host now" modal + control unlock.

## Phase 5 — Reactions + Polish (week 5)
- `POST /sessions/:id/reactions` (rate-limited 30/min).
- LK fanout via `wt-sync` type=reaction.
- Reaction overlay animation (rive or pure Flutter implicit anim).
- Captions toggle for HTML5 sources.
- Battery-saver heartbeat tuning.

## Phase 6 — Observability + Hardening (week 6)
- Prometheus counters wired in `service.go` and `drift_engine.dart` (via analytics provider).
- Grafana dashboard `wt-overview` JSON.
- Load test: 100 concurrent sessions x 12 viewers using k6 + headless mock client.
- Chaos: kill host mid-session; assert election < 4 s.

## Phase 7 — Rollout (week 7)
- Internal dogfood (Flicko team, 1 week).
- 5% production rollout via flag.
- Monitor drift p95, completion rate, error logs daily.
- 25% → 50% → 100% over 10 days.

## Backend Task List
- [ ] sqlc gen for new tables.
- [ ] Implement service functions: `CreateSession`, `JoinSession`, `LeaveSession`, `EndSession`, `PublishAnchor`, `GetAnchor`, `TransferHost`, `RunElection`.
- [ ] Token mint with `canPublishData` grant only for host.
- [ ] Webhook handler for LK participant events.
- [ ] Centrifugo publisher util for `room:{id}:wt`.
- [ ] Rate limiter middleware using Redis `INCR` + EXPIRE.
- [ ] Allowlist validator for media URLs.
- [ ] Cron job (every 5 min): purge `state IN ('ended')` older than 24 h.

## Mobile Task List
- [ ] Add packages to `pubspec.yaml`: `youtube_player_iframe`, `video_player`, `azure_communication_calling`, `msgpack_dart`.
- [ ] Wire route `/activities/watch-together/:sessionId` in `app_router.dart`.
- [ ] Implement source picker with allowlist validation client-side.
- [ ] Implement drift engine with rate-correction and hard-seek tiers.
- [ ] Build host vs viewer UI variants.
- [ ] Persist last 5 sources per room locally for "Recent" tab.
- [ ] Reduce-motion accessibility branch in reaction overlay.
- [ ] Integration test using `patrol` for create + join + sync.

## Test Plan
- **Unit (Go)**: drift math, election tie-break, allowlist regex, rate limiter.
- **Unit (Dart)**: SyncFrame encode/decode, drift_engine state transitions.
- **Integration**: end-to-end with a stub LK server using `azure_acs-server` Docker.
- **E2E**: Patrol test scripts on Android emulator and iOS simulator.
- **Soak**: 12 viewers, 90 min movie, drift p95 logged.
- **Chaos**: random LK disconnects every 30 s, assert auto-recovery.
- **Manual**: 5-person multi-region (US, EU, IN) playtest.

## Rollout Plan
| Day | Audience | Gate |
|---|---|---|
| 0 | Flicko team | Crash-free > 99% |
| 3 | 5% prod | drift p95 < 350 ms |
| 7 | 25% prod | completion rate > 50% |
| 10 | 50% prod | error rate < 0.5% |
| 14 | 100% prod | Sustain SLOs 48 h |

Rollback: flip `activities.watch_together.enabled = false`. Existing sessions complete; no new ones start.

## Cost Model ($0)
- Azure ACS Cloud free tier: 100 monthly active participants, 10 GB bandwidth — covers ~150 sessions/mo.
- Supabase free: 500 MB DB; tables write < 1 MB/session.
- Upstash Redis free: 10k commands/day; ~1 anchor/5 s × 12 viewers × 100 sessions ≈ 28k/day at peak. Mitigation: anchor only on Postgres, not Redis writes for every heartbeat; use Redis only for hot state (4 writes/session lifecycle).
- Appwrite Storage free: 2 GB; user-uploaded recordings opt-in.
- Centrifugo self-hosted on Fly.io free VM (256 MB).
- Total: $0/mo within free-tier ceilings; first paid trigger is LK bandwidth above 10 GB (~150 sessions). Set quota alert at 80%.
