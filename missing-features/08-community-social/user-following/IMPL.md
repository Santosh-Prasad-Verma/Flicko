# User Following — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 193 | 1d | Backend |
| 2 | Backend service + handlers + fanout | 5d | Backend |
| 3 | Mobile UI scaffolding | 4d | Mobile |
| 4 | Wire-up + Centrifugo realtime | 2d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/193_user_following.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/follow.go`
- [ ] Service `backend/internal/services/social/user-following/service.go`
- [ ] Fanout worker `backend/internal/services/social/user-following/fanout.go`
- [ ] Repo `backend/internal/repo/social/follow_repo.go`
- [ ] Handler `backend/internal/handlers/social/follow_handler.go`
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo `user:<uid>` registration
- [ ] Block-prevents-follow check
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/user-following/`
- [ ] DTOs, repository, datasource
- [ ] Domain entities
- [ ] Riverpod providers (follow state, home feed pagination, requests)
- [ ] Presentation: home_feed_screen, follow_button, followers_list, requests_screen, settings
- [ ] Routing: `/home`, `/users/:id`, `/me/followers`, `/me/following`, `/me/follow-requests`
- [ ] L10n keys
- [ ] Tests: widget golden, provider, repository
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] None in v1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/user-following/service.go     (new)
  internal/services/social/user-following/fanout.go      (new)
  internal/handlers/social/follow_handler.go             (new)
  internal/models/social/follow.go                       (new)
  internal/repo/social/follow_repo.go                    (new)
  cmd/server/main.go                                     (edit)
mobile/
  lib/features/social/user-following/...                 (new tree)
  lib/core/router/app_router.dart                        (edit)
  lib/features/profile/presentation/profile_sheet.dart   (edit)
supabase/
  migrations/193_user_following.up.sql                   (new)
  migrations/193_user_following.down.sql                 (new)
```

## 6. Test Plan

- Unit: service, fanout, repo; >=80%
- Integration: testcontainers Postgres + NATS + Centrifugo; fanout under load
- E2E: Maestro follow + post + see in home feed
- Load: k6 1k follow rps, 10k home-feed reads/min
- Accessibility: axe + screen readers
- Security: RLS; block-prevents-follow; private require-approval

## 7. Rollout & Feature Flags

- Flag: `feature.user_following.enabled`
- Default OFF in prod
- Beta: 50 internal users
- Canary: 1% -> 10% -> 50% -> 100% over 7d

## 8. Rollback Plan

1. Disable flag
2. Hide home tab and follow buttons
3. Data preserved
4. Restart fanout when re-enabling

## 9. Dependencies / Blockers

- Depends on: blocks system, posts feature (sources)
- Blocks: friend-suggestions ranking signals

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Influencer fanout storm | M | M | pull-on-read above 5k followers |
| Privacy leak via counts | L | H | strict RLS on counts |
| Notification spam | M | M | per-follow notify level, batching |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | trivial | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] In-tree spec files updated
- [ ] Dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
