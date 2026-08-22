# Music Party — Implementation

## Phase 0 — Foundation (week 0)
- Feature flag `activities.music_party.enabled`.
- Migration `121_music_party.sql` applied.
- Spotify Developer app registered; redirect URIs whitelisted (mobile deep link + web callback).
- Env vars: `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_TOKEN_KEY`, `SPOTIFY_REDIRECT_URI`.

## Phase 1 — Backend Skeleton (week 1)
- Module: `backend/internal/activities/musicparty/`
  - `module.go`
  - `handler.go`
  - `service.go`
  - `queue.go`
  - `rotation.go`
  - `repo.go`
  - `redis.go`
  - `spotify_client.go`
  - `events.go`
- REST: create/join/leave/end + queue add/list/reorder/remove.
- Spotify OAuth callback handler at `/api/v1/mp/spotify/oauth/callback`.

## Phase 2 — Sync + Anchor (week 2)
- Anchor publish/get endpoints.
- voice data channel `mp-sync` with TrackAnchor msgpack.
- Drift logic on listener client.

## Phase 3 — Mobile Player (week 3)
- Files:
  - `mobile/lib/features/activities/music_party/presentation/mp_now_playing_screen.dart`
  - `mobile/lib/features/activities/music_party/presentation/mp_search_screen.dart`
  - `mobile/lib/features/activities/music_party/presentation/mp_settings_sheet.dart`
  - `mobile/lib/features/activities/music_party/presentation/widgets/now_playing_card.dart`
  - `mobile/lib/features/activities/music_party/presentation/widgets/queue_list.dart`
  - `mobile/lib/features/activities/music_party/presentation/widgets/dj_badge.dart`
  - `mobile/lib/features/activities/music_party/providers/mp_session_provider.dart`
  - `mobile/lib/features/activities/music_party/providers/mp_queue_provider.dart`
  - `mobile/lib/features/activities/music_party/providers/spotify_auth_provider.dart`
  - `mobile/lib/features/activities/music_party/data/mp_repository.dart`
  - `mobile/lib/features/activities/music_party/data/spotify_remote_adapter.dart`
- Spotify SDK integration via `flutter_spotify_remote` (Android/iOS); fallback `audioplayers` for previews.

## Phase 4 — Queue + Rotation (week 4)
- Implement add/reorder/remove with Redis sorted set, write-through Postgres.
- Round-robin and listener-vote rotation modes.
- Vote-skip aggregation: 5 s window via Redis pub/sub + LK broadcast.

## Phase 5 — Reactions + DJ Polish (week 5)
- Vibes endpoint and overlay.
- DJ handoff modal with eligibility check (Premium + room member).
- Album-art proxy/cache via Appwrite.

## Phase 6 — Observability + Hardening (week 6)
- Prometheus counters in `service.go` and Dart analytics provider.
- Grafana dashboard `mp-overview`.
- Load test: 50 sessions x 25 listeners using k6 simulating Spotify SDK ack.
- Chaos: revoke Spotify token mid-session; assert rotation.

## Phase 7 — Rollout (week 7)
- Internal dogfood.
- 5% prod rollout via flag.
- Watch metrics: tracks/session, drift p95, Spotify error rate.
- Ramp 25% → 50% → 100% over 10 days.

## Backend Task List
- [ ] sqlc gen for queue, sessions, vibes.
- [ ] Spotify OAuth flow with PKCE; encrypt tokens (libsodium).
- [ ] Token refresher cron (every minute, refresh tokens expiring within 60 s).
- [ ] Rotation engine with Redis lock.
- [ ] Vote-skip aggregator with sliding window.
- [ ] Rate limiter middleware (per-user adds, vibes).
- [ ] Spotify client wrapper with retry-after handling.
- [ ] LK token mint with `canPublishData=true` only for current DJ.
- [ ] Webhook for LK participant events.
- [ ] Prometheus counters & alerts.
- [ ] Cron: purge ended sessions older than 24 h.

## Mobile Task List
- [ ] Add packages: `flutter_spotify_remote`, `audioplayers`, `azure_communication_calling`, `msgpack_dart`.
- [ ] Spotify auth provider with token storage in secure storage.
- [ ] Now playing screen: DJ vs Listener variants.
- [ ] Queue list with drag-handle reorder (DJ only).
- [ ] Search screen with Spotify search API call (server-proxied to keep client secret safe).
- [ ] Drift correction on listener using Spotify SDK position polling (every 2 s).
- [ ] Free-tier preview adapter using `audioplayers`.
- [ ] Vibe overlay with reduce-motion branch.
- [ ] Settings sheet for rotation mode and threshold.
- [ ] Route wired in `app_router.dart`: `/activities/music-party/:sessionId`.

## Test Plan
- **Unit (Go)**: rotation tie-break, vote threshold math, Redis sorted-set queue ops, allowlist URI parsing.
- **Unit (Dart)**: drift_engine for music, queue ordering, Spotify auth state machine.
- **Integration**: wiremock Spotify API + azure_acs-server Docker.
- **E2E**: Patrol test creates session, adds 3 tracks, plays, vote-skips.
- **Soak**: 25 listeners, 60 min, drift p95 logged.
- **Chaos**: kill DJ, revoke token, network drop; assert recovery.
- **Manual**: Premium + free mix in same session.

## Rollout Plan
| Day | Audience | Gate |
|---|---|---|
| 0 | Flicko team | crash-free > 99% |
| 3 | 5% prod | drift p95 < 500 ms |
| 7 | 25% prod | tracks/session > 4 |
| 10 | 50% prod | Spotify err rate < 1% |
| 14 | 100% | Sustain SLOs 48 h |

Rollback: flag off, in-flight sessions complete, no new ones.

## Cost Model ($0)
- Spotify Web Playback / App Remote: free for end users with their own accounts.
- Azure ACS Cloud free tier: 100 MAU + 10 GB bandwidth (data channel ≪ video; ample headroom).
- Supabase free: tables small (track rows < 500 B).
- Upstash Redis free: ~5 ops/track + 1 anchor/4 s × 25 listeners × 50 sessions ≈ 25k ops/day at peak. Stay under 10k/day on average by skipping anchor writes when state unchanged.
- Appwrite Storage free: 2 GB; album-art cache fits comfortably.
- Centrifugo on Fly.io free VM.
- Total: $0 within free tiers; first paid trigger is Upstash if anchor cadence is too tight; mitigate with 4 s minimum and "no-op skip" when delta within 250 ms.
