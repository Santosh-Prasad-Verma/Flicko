# User Leaderboards Native — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 198 | 1d | Backend |
| 2 | Backend service + aggregator + updater | 5d | Backend |
| 3 | Mobile UI + settings | 4d | Mobile |
| 4 | Wire-up + Centrifugo | 1d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/198_user_leaderboards_native.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/xp.go`
- [ ] Service `backend/internal/services/social/user-leaderboards-native/service.go`
- [ ] Aggregator `backend/internal/services/social/user-leaderboards-native/aggregator.go`
- [ ] Balance updater `backend/internal/services/social/user-leaderboards-native/balance_updater.go`
- [ ] Repo `backend/internal/repo/social/xp_repo.go`
- [ ] Handler `backend/internal/handlers/social/leaderboards_handler.go`
- [ ] Wire routes
- [ ] Centrifugo `xp:server:<sid>` registration
- [ ] Audit log entries (rule changes, season resets)
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/user-leaderboards-native/`
- [ ] DTOs, repository, datasource
- [ ] Domain entities
- [ ] Riverpod providers
- [ ] Presentation: leaderboard_screen, my_rank_card, badges_strip, settings_panel, level_up_sheet
- [ ] Routing
- [ ] L10n keys
- [ ] Tests

## 4. AI / Infra Tasks

- [ ] None in v1
- [ ] Anti-spam classifier deferred to v1.1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/user-leaderboards-native/...   (new tree)
  internal/handlers/social/leaderboards_handler.go        (new)
  internal/models/social/xp.go                            (new)
  internal/repo/social/xp_repo.go                         (new)
  cmd/server/main.go                                      (edit)
mobile/
  lib/features/social/user-leaderboards-native/...        (new tree)
  lib/core/router/app_router.dart                         (edit)
supabase/
  migrations/198_user_leaderboards_native.up.sql          (new)
  migrations/198_user_leaderboards_native.down.sql        (new)
```

## 6. Test Plan

- Unit: aggregator caps, decay math, rules apply; >=85%
- Integration: testcontainers Postgres + NATS with synthetic event stream
- E2E: Maestro send messages -> rank moves up
- Load: k6 5k events/s burst
- Accessibility: leaderboard, self card, settings
- Security: RLS for ledger access; rule edit by non-managers blocked

## 7. Rollout & Feature Flags

- Flag: `feature.user_leaderboards_native.enabled`
- Default OFF in prod
- Beta: 30 servers
- Canary: 1% -> 10% -> 50% -> 100% over 7d

## 8. Rollback Plan

1. Disable flag
2. Hide leaderboard UI
3. Aggregator paused; ledger preserved

## 9. Dependencies / Blockers

- Depends on: messages, voice, votes events
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Spam grinding | M | M | per-minute cap, anti-spam later |
| Rule edit confusion | M | M | banner + audit log + forward-only apply |
| Voice afk inflation | M | M | activity check |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | partitioned | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] In-tree spec files updated
- [ ] Dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
