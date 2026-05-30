# Post Upvote/Downvote Global — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 1d | PM/Design |
| 1 | DB schema + migration 191 | 1d | Backend |
| 2 | Backend service + brigade guard | 4d | Backend |
| 3 | Mobile UI scaffolding | 3d | Mobile |
| 4 | Wire-up + Centrifugo realtime | 1d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/191_votes_global.up.sql`
- [ ] Down migration
- [ ] Model `backend/internal/models/social/vote.go`
- [ ] Service `backend/internal/services/social/post-upvote-downvote-global/service.go`
- [ ] Brigade guard `brigade_guard.go`
- [ ] Repo `backend/internal/repo/social/vote_repo.go`
- [ ] Handler `backend/internal/handlers/social/votes_handler.go`
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo `votes:<channel_id>` registration
- [ ] Permission middleware + account-age check
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update
- [ ] Channel settings extend with `votes_enabled`, `disable_downvote`

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/post-upvote-downvote-global/`
- [ ] DTOs, repository, datasource
- [ ] Domain entity + cast/retract usecase
- [ ] Riverpod provider with optimistic UI
- [ ] `VoteArrows` widget integrated into message bubble and forum post header
- [ ] Hive offline outbox
- [ ] L10n keys
- [ ] Tests: widget golden, provider, repository

## 4. AI / Infra Tasks

- [ ] No AI in v1
- [ ] Brigade detector is rules-based; ML uplift parked for v1.1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/post-upvote-downvote-global/service.go         (new)
  internal/services/social/post-upvote-downvote-global/brigade_guard.go   (new)
  internal/handlers/social/votes_handler.go                               (new)
  internal/models/social/vote.go                                          (new)
  internal/repo/social/vote_repo.go                                       (new)
  cmd/server/main.go                                                      (edit)
mobile/
  lib/features/social/post-upvote-downvote-global/...                     (new tree)
  lib/features/messaging/presentation/widgets/message_bubble.dart         (edit)
  lib/features/forum/presentation/widgets/forum_post_header.dart          (edit)
supabase/
  migrations/191_votes_global.up.sql                                      (new)
  migrations/191_votes_global.down.sql                                    (new)
```

## 6. Test Plan

- Unit: service, brigade guard, repo; >=85%
- Integration: Postgres + Redis via testcontainers; 1k cast burst
- E2E: Maestro tap-vote, observe count
- Load: k6 sustained 2k rps on POST /votes
- Accessibility: axe + manual screen reader for arrows
- Security: RLS for vote audit; rate-limit bypass attempts; idempotency

## 7. Rollout & Feature Flags

- Flag: `feature.votes_global.enabled`
- Default OFF in prod
- Beta: 20 internal servers
- Canary: 1% -> 10% -> 50% -> 100% over 7d
- Kill switch tested in staging

## 8. Rollback Plan

1. Disable flag instantly
2. UI hides arrows; backend rejects new casts
3. Existing data preserved
4. Re-enable later without migration changes

## 9. Dependencies / Blockers

- Depends on: messages, forum, channel_settings table
- Blocks: feed timeline ranker, leaderboards

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hot-row contention | M | M | batched count rebuilder |
| Brigade false positives | M | M | mod review path; threshold tunable |
| Vote spam DDoS | L | H | per-IP and per-account rate limits |
| Negative score harassment | M | M | per-server disable downvote flag |

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
