# Server Map — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + privacy review | 3d | PM/Privacy/Design |
| 1 | DB schema + migration 196 | 1d | Backend |
| 2 | Backend service + handlers | 5d | Backend |
| 3 | Mobile UI + MapLibre integration | 5d | Mobile |
| 4 | Wire-up + privacy controls | 2d | Both |
| 5 | QA + privacy/accessibility audit | 3d | QA + Privacy |
| 6 | Beta rollout | 4d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/196_server_map.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/member_location.go`
- [ ] Service `backend/internal/services/social/server-map/service.go`
- [ ] Geohash utilities `geohash.go`
- [ ] K-anon enforcement `kanon.go`
- [ ] Repo `backend/internal/repo/social/map_repo.go`
- [ ] Handler `backend/internal/handlers/social/map_handler.go`
- [ ] Security-definer function `get_server_clusters`
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Cron jobs: expiry, MV rebuild, minor coarsening
- [ ] Audit log for opt-in/opt-out
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/server-map/`
- [ ] DTOs, repository, datasource
- [ ] Domain entities (precision enum, consent state)
- [ ] Riverpod providers (clusters, opt-in state)
- [ ] Presentation: map_screen (MapLibre), consent_sheet, privacy_controls_screen, list_view
- [ ] Geohash encoding client-side via `dart_geohash`
- [ ] OS permission handling
- [ ] Routing
- [ ] L10n keys
- [ ] Tests: widget golden, provider, repository
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] None in v1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/server-map/service.go    (new)
  internal/services/social/server-map/geohash.go    (new)
  internal/services/social/server-map/kanon.go      (new)
  internal/handlers/social/map_handler.go           (new)
  internal/models/social/member_location.go         (new)
  internal/repo/social/map_repo.go                  (new)
  cmd/server/main.go                                (edit)
mobile/
  lib/features/social/server-map/...                (new tree)
  lib/core/router/app_router.dart                   (edit)
supabase/
  migrations/196_server_map.up.sql                  (new)
  migrations/196_server_map.down.sql                (new)
```

## 6. Test Plan

- Unit: geohash encoding, k-anon coarsening, age gating; >=85%
- Integration: testcontainers Postgres + materialized view rebuild
- E2E: Maestro flow for opt-in, revoke, minor coarsen
- Privacy testing: simulated inference attacks; verify no precise leak
- Accessibility: list view fully usable; screen-reader for map labels
- Security: RLS leakage; raw rows must never be selected by other users

## 7. Rollout & Feature Flags

- Flag: `feature.server_map.enabled`
- Default OFF in prod
- Beta: 10 owner-volunteer servers with privacy ack signed
- Canary: 1% -> 10% -> 50% -> 100% over 10d (slower for privacy)

## 8. Rollback Plan

1. Disable flag
2. Hide map UI
3. Delete materialized view rebuild job
4. If privacy issue found, run purge of `member_locations` to be safe
5. Down migration is supported

## 9. Dependencies / Blockers

- Depends on: account age data
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Inference attack | M | H | k-anon=5, jitter, never expose raw |
| Minor location leak | L | H | server-side coarsen + age gate |
| Tile provider rate limit | M | L | local cache, fallback provider |
| Privacy regression | M | H | privacy review checkpoint each phase |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| Tiles | OSM free | $0 |
| Storage | trivial | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] Privacy review signed off
- [ ] In-tree spec files updated
- [ ] Dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 privacy or security incidents in 14-day window
