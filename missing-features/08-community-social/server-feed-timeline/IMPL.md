# Server Feed Timeline — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 190 | 1d | Backend |
| 2 | Backend service + handlers + worker | 5d | Backend |
| 3 | Mobile UI scaffolding | 4d | Mobile |
| 4 | Wire-up + Centrifugo realtime | 2d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/190_server_feed_timeline.up.sql`
- [ ] Down migration
- [ ] Model `backend/internal/models/social/feed_item.go`
- [ ] Service `backend/internal/services/social/server-feed-timeline/service.go`
- [ ] Ranker `backend/internal/services/social/server-feed-timeline/ranker.go`
- [ ] Backfill worker `backend/internal/services/social/server-feed-timeline/backfill.go`
- [ ] Repo `backend/internal/repo/social/feed_repo.go`
- [ ] Service tests, table-driven, >=80% coverage
- [ ] Handler `backend/internal/handlers/social/feed_handler.go`
- [ ] Handler tests
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo channel `feed:<server_id>` registration
- [ ] Permission middleware `requireManageFeed`
- [ ] Audit log entries for pin/hide
- [ ] Metrics counters and histograms
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/server-feed-timeline/`
- [ ] Data: `feed_dto.dart`, `feed_repository.dart`, `feed_remote_source.dart`
- [ ] Domain: `feed_item.dart`, `feed_filter.dart`, `usecases/get_feed.dart`, `mark_read.dart`, `pin_item.dart`
- [ ] Application: `feed_provider.dart`, `feed_unread_provider.dart`
- [ ] Presentation: `feed_screen.dart`, `widgets/feed_card.dart`, `widgets/catch_up_banner.dart`
- [ ] Routing: add `/server/:id/feed` to `app_router.dart`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`
- [ ] Tests: widget, provider, golden for card variants
- [ ] Empty/error/loading states
- [ ] Hive box `feed_cache_v1` for offline reads

## 4. AI / Infra Tasks

- [ ] No AI in v1. Ranker is rule-based.
- [ ] Eval harness for ranker producing golden order on synthetic dataset

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/server-feed-timeline/service.go         (new)
  internal/services/social/server-feed-timeline/ranker.go          (new)
  internal/services/social/server-feed-timeline/backfill.go        (new)
  internal/handlers/social/feed_handler.go                         (new)
  internal/models/social/feed_item.go                              (new)
  internal/repo/social/feed_repo.go                                (new)
  cmd/server/main.go                                               (edit)
mobile/
  lib/features/social/server-feed-timeline/...                     (new tree)
  lib/core/router/app_router.dart                                  (edit)
supabase/
  migrations/190_server_feed_timeline.up.sql                       (new)
  migrations/190_server_feed_timeline.down.sql                     (new)
```

## 6. Test Plan

- Unit: service, ranker, backfill, repo; >=80%
- Integration: Postgres + Redis + Centrifugo via testcontainers
- E2E: Maestro flow opens feed, pins item, observes ws push
- Load: k6 holding 500 rps for 5m on `GET /feed`
- Accessibility: axe + manual screen reader pass on Talkback and VoiceOver
- Security: RLS tests for cross-server leakage; permission matrix for pin/hide

## 7. Rollout & Feature Flags

- Flag: `feature.server_feed_timeline.enabled` in Doppler
- Default OFF in prod
- Beta: 10 internal servers
- Canary: 1% -> 10% -> 50% -> 100% over 7 days
- Kill switch validated in staging via chaos test

## 8. Rollback Plan

1. Disable flag instantly
2. Stop backfill worker
3. Revert handler routes
4. Tables remain; data not corrupt
5. If rollback after pin migration ran, re-enable flag still safe

## 9. Dependencies / Blockers

- Depends on: existing forum, events, announcements, `votes` table from sibling feature
- Blocks: nothing
- External: none

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hot servers flood feed | M | M | per-author cap of 3/day, owner override |
| Ranker bias toward older popular items | M | M | recency decay tuned, A/B with control |
| Cache stampede on viral pin | L | H | request coalescing in service layer |
| RLS slow on huge servers | L | H | partial indexes, materialized fast-path |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | reuses existing | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] In-tree spec files updated, INDEX status flipped to "Built"
- [ ] Grafana dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
