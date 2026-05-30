# Server Reviews — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 192 | 1d | Backend |
| 2 | Backend service + handlers | 4d | Backend |
| 3 | Mobile UI scaffolding | 4d | Mobile |
| 4 | Wire-up + Centrifugo realtime | 2d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/192_server_reviews.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/server_review.go`
- [ ] Service `backend/internal/services/social/server-reviews/service.go`
- [ ] Eligibility `backend/internal/services/social/server-reviews/eligibility.go`
- [ ] Repo `backend/internal/repo/social/server_review_repo.go`
- [ ] Handler `backend/internal/handlers/social/server_reviews_handler.go`
- [ ] Aggregator worker (refresh materialized view)
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo `reviews:<server_id>` registration
- [ ] Audit log entries for hide/remove/report
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/server-reviews/`
- [ ] Data: dto, repository, datasource
- [ ] Domain: review entity, eligibility result, sort enum
- [ ] Application: paginated provider, eligibility provider
- [ ] Presentation: review_list_screen, compose_screen, owner_reply_sheet
- [ ] Routing: `/discovery/server/:id/reviews`, `/reviews/compose`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`
- [ ] Tests: widget, provider, golden cards
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] Optional: profanity classifier as moderation hint (Groq Llama 3 small) — defer to v1.1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/server-reviews/service.go            (new)
  internal/services/social/server-reviews/eligibility.go        (new)
  internal/handlers/social/server_reviews_handler.go            (new)
  internal/models/social/server_review.go                       (new)
  internal/repo/social/server_review_repo.go                    (new)
  cmd/server/main.go                                            (edit)
mobile/
  lib/features/social/server-reviews/...                        (new tree)
  lib/features/discovery/presentation/server_card.dart          (edit)
  lib/core/router/app_router.dart                               (edit)
supabase/
  migrations/192_server_reviews.up.sql                          (new)
  migrations/192_server_reviews.down.sql                        (new)
```

## 6. Test Plan

- Unit: service, eligibility, repo; >=80%
- Integration: Postgres + Redis testcontainers
- E2E: Maestro flow compose+submit+see card
- Load: k6 100 rps reads, 10 rps writes
- Accessibility: axe + screen reader on stars and histogram
- Security: RLS leakage tests, eligibility bypass attempts

## 7. Rollout & Feature Flags

- Flag: `feature.server_reviews.enabled`
- Default OFF in prod
- Beta: 30 public servers with owner consent
- Canary: 1% -> 10% -> 50% -> 100% over 7d

## 8. Rollback Plan

1. Disable flag instantly
2. Hide reviews tab from discovery
3. Backend retains data; safe re-enable later

## 9. Dependencies / Blockers

- Depends on: server_members, messages, mod tooling
- Blocks: discovery ranking improvements

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Brigading | M | M | brigade guard, mod action |
| Hostile reviews | M | M | report, hide, remove |
| Owner retaliation | L | M | rate limited replies, audit |
| Aggregates drift | L | M | nightly rebuild |

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
