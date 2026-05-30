# Rich Polls — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec | 2d | PM |
| 1 | Migration 171 + models | 1d | Backend |
| 2 | Service + handlers + anti-abuse | 4d | Backend |
| 3 | IRV tabulator + tests (golden) | 3d | Backend |
| 4 | Composer UI | 4d | Mobile |
| 5 | Channel widget + voting UX | 3d | Mobile |
| 6 | Results screen + IRV chart | 3d | Mobile |
| 7 | v1 -> v2 read shim | 2d | Backend |
| 8 | QA, a11y, load | 3d | QA |
| 9 | Beta -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/171_polls_v2.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/poll_v2.go`
- [ ] Service + validator
- [ ] IRV tabulator with deterministic tie-break
- [ ] Anti-abuse: account age, rate limit
- [ ] Anonymous hashing per poll
- [ ] Auto-close cron `polls_v2_auto_close`
- [ ] Handlers
- [ ] Wire routes
- [ ] Centrifugo channels
- [ ] Audit log
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] v1 polls read-shim
- [ ] Tests: IRV golden corpus, anon hash uniqueness, lock-on-vote trigger

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/polls_rich/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Domain entities
- [ ] Riverpod providers
- [ ] Composer screen with reorderable questions
- [ ] Channel widget with compact and expanded modes
- [ ] Voting UX (single, multi, ranked drag, scale)
- [ ] Results screen with IRV chart
- [ ] Routing, deep link
- [ ] L10n
- [ ] Tests: IRV chart widget golden; ranked drag interactions

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched

```
backend/
  internal/services/productivity/polls_v2/
    service.go irv_tabulator.go anti_abuse.go
  internal/handlers/polls_v2/{poll_handler,vote_handler,results_handler}.go
  internal/models/poll_v2.go
  internal/repo/poll_v2_repo.go
  cmd/server/main.go                       (edit)
  api/openapi.yaml                         (edit)
mobile/lib/features/productivity/polls_rich/...
mobile/lib/core/router/app_router.dart    (edit)
mobile/lib/l10n/app_en.arb                (edit)
supabase/migrations/171_polls_v2.up.sql
supabase/migrations/171_polls_v2.down.sql
```

## 6. Test Plan

- Unit: IRV golden cases (Wikipedia + bespoke ties); anti-abuse
- Integration: full create -> vote -> close -> tabulate
- E2E: ranked vote drag on phone
- Load: 500 votes/sec sustained
- Security: cannot vote twice; anon hash collision-proof
- A11y: keyboard reorder

## 7. Rollout & Feature Flags

- Flag `feature.polls_rich.enabled`
- v1 polls UI remains fallback
- 1% -> 10% -> 50% -> 100% over 21d

## 8. Rollback Plan

1. Flag flip -> compose hides advanced types
2. Existing v2 polls continue to work read-only
3. Tables stay

## 9. Dependencies / Blockers

- Depends on: messages, channels, audit-log
- Replaces v1 polls UI

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| IRV bug | M | H | golden corpus + manual review |
| Anon collision | L | M | per-poll salt |
| UX overwhelm | M | M | hide advanced toggles behind "More options" |

## 11. Cost Model

| Component | Free | $ at 100k DAU |
|-----------|------|----------------|
| Compute | Railway | $0 |
| DB | Supabase | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] IRV golden corpus passing
- [ ] Beta NPS >= 35
- [ ] Zero P0/P1 in 7d
