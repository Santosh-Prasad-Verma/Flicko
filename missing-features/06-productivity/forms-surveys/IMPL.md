# Forms & Surveys — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec | 2d | PM |
| 1 | Migration 169 + models | 1d | Backend |
| 2 | Service + validator + handlers | 4d | Backend |
| 3 | Aggregator + CSV export | 2d | Backend |
| 4 | Builder UI + fill UI | 6d | Mobile |
| 5 | Responses dashboard | 3d | Mobile |
| 6 | Realtime + channel card | 2d | Both |
| 7 | QA, a11y, load | 3d | QA |
| 8 | Beta -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/169_forms.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/form.go`
- [ ] Service + validator
- [ ] Aggregator (per-question stats)
- [ ] CSV streaming export
- [ ] Anonymous hashing (per-form salt)
- [ ] Auto-close cron `forms_auto_close` daily
- [ ] Handlers
- [ ] Wire routes
- [ ] Centrifugo channels
- [ ] Audit log
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: validator, anon hash uniqueness, aggregate accuracy

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/forms_surveys/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Domain entities
- [ ] Riverpod providers
- [ ] Builder screen with reorderable questions
- [ ] Fill screen (one-per-screen on phone)
- [ ] Responses dashboard with charts
- [ ] Channel card widget
- [ ] L10n
- [ ] Tests

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched

```
backend/
  internal/services/productivity/forms/
    service.go validator.go aggregator.go csv_export.go
  internal/handlers/forms/{form_handler,response_handler,export_handler}.go
  internal/models/form.go
  internal/repo/form_repo.go
  cmd/server/main.go                       (edit)
  api/openapi.yaml                         (edit)
mobile/lib/features/productivity/forms_surveys/...
mobile/lib/core/router/app_router.dart     (edit)
mobile/lib/l10n/app_en.arb                 (edit)
supabase/migrations/169_forms.up.sql
supabase/migrations/169_forms.down.sql
```

## 6. Test Plan

- Unit: validator types, anon hash uniqueness
- Integration: full publish -> respond -> aggregate flow
- E2E: Maestro fill on phone
- Load: 200 rps submit; aggregate p99 < 200ms
- A11y: screen reader on fill flow
- Security: cannot fill closed form; cannot retrieve responses without mod role

## 7. Rollout & Feature Flags

- Flag `feature.forms_surveys.enabled`
- 1% -> 10% -> 50% -> 100% over 21d

## 8. Rollback Plan

1. Flag flip
2. Block new publishes; existing remain
3. Tables stay

## 9. Dependencies / Blockers

- Depends on: messages (channel card), audit-log
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Schema mutation post-publish | M | M | edit blocked except labels |
| Anon collision | L | M | per-form salt |
| Large CSV | L | L | stream + cap 100k rows |

## 11. Cost Model

| Component | Free tier | $ at 100k DAU |
|-----------|-----------|----------------|
| Compute | Railway | $0 |
| DB | Supabase | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Aggregates accurate vs raw counts
- [ ] Beta NPS >= 30
- [ ] Zero P0/P1 in 7d
