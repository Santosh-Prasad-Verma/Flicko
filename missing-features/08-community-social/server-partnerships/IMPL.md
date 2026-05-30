# Server Partnerships — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 195 | 1d | Backend |
| 2 | Backend service + handlers | 4d | Backend |
| 3 | Mobile UI scaffolding | 4d | Mobile |
| 4 | Wire-up + Centrifugo realtime | 1d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/195_server_partnerships.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/partnership.go`
- [ ] Service `backend/internal/services/social/server-partnerships/service.go`
- [ ] Metrics aggregator `backend/internal/services/social/server-partnerships/metrics.go`
- [ ] Repo `backend/internal/repo/social/partnership_repo.go`
- [ ] Handler `backend/internal/handlers/social/partnerships_handler.go`
- [ ] Wire routes
- [ ] Centrifugo `partner:<server_id>` registration
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update
- [ ] Invite revocation listener

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/server-partnerships/`
- [ ] DTOs, repository, datasource
- [ ] Domain entity, status enum
- [ ] Riverpod providers (list, inbox, propose form, metrics)
- [ ] Presentation: partners_list, propose_dialog, inbox_screen, analytics_panel, partners_about_section
- [ ] Routing
- [ ] L10n keys
- [ ] Tests

## 4. AI / Infra Tasks

- [ ] None in v1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/server-partnerships/service.go    (new)
  internal/services/social/server-partnerships/metrics.go    (new)
  internal/handlers/social/partnerships_handler.go           (new)
  internal/models/social/partnership.go                      (new)
  internal/repo/social/partnership_repo.go                   (new)
  cmd/server/main.go                                         (edit)
mobile/
  lib/features/social/server-partnerships/...                (new tree)
  lib/features/server_settings/...                           (edit nav)
  lib/core/router/app_router.dart                            (edit)
supabase/
  migrations/195_server_partnerships.up.sql                  (new)
  migrations/195_server_partnerships.down.sql                (new)
```

## 6. Test Plan

- Unit: service, normalizer, repo; >=80%
- Integration: testcontainers Postgres
- E2E: propose -> accept -> partner appears
- Load: low traffic; smoke 50 rps
- Accessibility: list and dialog
- Security: RLS for non-managers, abuse rate-limit

## 7. Rollout & Feature Flags

- Flag: `feature.server_partnerships.enabled`
- Default OFF in prod
- Beta: 30 owner-volunteers
- Canary: 1% -> 10% -> 50% -> 100% over 7d

## 8. Rollback Plan

1. Disable flag
2. Hide settings section + about-tab
3. Existing partnerships dormant; data preserved

## 9. Dependencies / Blockers

- Depends on: invites system, perms model
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Partnership farming | M | M | cap 25, activity gate |
| Owner-change abuse | L | M | re-confirm prompt |
| Spam proposals | M | L | rate limit 5/day |

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
