# Gartic Phone — Implementation

## 1. Phases
| Phase | Goal | Days |
|-------|------|------|
| 0 | Spec freeze | 2 |
| 1 | Schema + migration 123 | 1 |
| 2 | Backend service + handlers + advance worker | 5 |
| 3 | Mobile lobby + canvas + caption screens | 6 |
| 4 | LiveKit data-channel sync + reveal | 3 |
| 5 | QA + a11y + golden tests | 3 |
| 6 | Beta on internal servers | 3 |
| 7 | GA | 1 |

## 2. Backend Tasks
- [ ] `supabase/migrations/123_gartic_phone.up.sql` (+down)
- [ ] `backend/internal/models/gartic.go`
- [ ] `backend/internal/services/activities/gartic/service.go`
- [ ] `backend/internal/services/activities/gartic/advance_worker.go` (1 s tick, advances phase on deadline)
- [ ] `backend/internal/handlers/gartic_handler.go` (POST /activities/gartic/sessions, /:id/join, /:id/start, /:id/prompts, /:id/drawings, /:id/captions, /:id/end)
- [ ] LiveKit data-channel publisher in `livekit_service.go` extension: `BroadcastGarticState(sessionID)`
- [ ] Permission: requires CONNECT + SPEAK in voice channel
- [ ] Audit log entries on session start/end
- [ ] Metrics: `flicko_gartic_sessions_started_total`, `flicko_gartic_round_seconds`, `flicko_gartic_active_sessions`
- [ ] Tests: table-driven service tests; integration test with testcontainers Postgres

## 3. Mobile Tasks
- [ ] `mobile/lib/features/activities/gartic_phone/` tree (data/domain/application/presentation)
- [ ] DTOs: GarticSession, GarticChain, GarticArtifact
- [ ] Repository: `GarticRepository` calling REST + listening to LiveKit data-channel
- [ ] Riverpod providers: `garticSessionProvider(sessionId)`, `garticPhaseProvider`
- [ ] Screens: `GarticLobbyScreen`, `GarticPromptScreen`, `GarticDrawingScreen`, `GarticCaptionScreen`, `GarticRevealScreen`
- [ ] Widgets: `DrawingCanvas` (using `signature` package), `CountdownBar`, `ChainCarousel`
- [ ] Routing in `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys
- [ ] Hive autosave for in-progress drawing every 2 s

## 4. Files Touched
```
backend/internal/services/activities/gartic/...      (new)
backend/internal/handlers/gartic_handler.go          (new)
backend/internal/models/gartic.go                    (new)
backend/cmd/server/main.go                           (edit: routes)
mobile/lib/features/activities/gartic_phone/...      (new)
mobile/lib/core/router/app_router.dart               (edit)
supabase/migrations/123_gartic_phone.up.sql          (new)
supabase/migrations/123_gartic_phone.down.sql        (new)
```

## 5. Test Plan
- Unit: ≥80 % service cov.
- Integration: 4-player simulated session on testcontainers.
- E2E: Patrol scenario "4 phones complete a 4-round game".
- Load: k6 — 200 concurrent sessions ×4 players (~800 sockets) for 10 min.
- A11y: TalkBack walkthrough of lobby + reveal.
- Security: drawings rejected if >512 KB; PNG header validated.

## 6. Rollout
- Flag `feature.gartic_phone.enabled`. Default OFF.
- Beta: 5 internal servers.
- Canary 1 % → 10 % → 50 % → 100 % over 7 days.

## 7. Rollback
1. Disable flag.
2. Stop advance worker.
3. Remove route registration.
4. Tables retained (cheap).

## 8. Dependencies
- Existing voice channel infra.
- Appwrite bucket creation.
- LiveKit data-channel pub/sub.

## 9. Risks
| Risk | L | I | Mitigation |
|------|---|---|------------|
| Drawings flood storage | M | M | size cap + per-user/day limit + 30 d purge |
| Phase desync | M | H | server-authoritative deadlines, client clock-skew correction |
| NSFW drawings | M | H | optional NSFW classifier, mod-report flow |

## 10. Cost (100 k DAU)
| Component | Cost |
|-----------|------|
| Compute | $0 (existing pods) |
| DB | $0 (Supabase free tier) |
| Storage | <$1 (1 % play, 200 KB avg, 30 d retention) |
| LiveKit data | $0 (existing) |
| **Total** | **<$1/mo** |

## 11. Done Definition
- All tasks ✓
- Coverage ≥80 %
- Beta NPS ≥4.0/5
- Zero P0 in 7 d
- Metrics dashboard live
