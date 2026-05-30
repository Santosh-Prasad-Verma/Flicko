# Reminders — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | Migration 165 + model | 1d | Backend |
| 2 | NL time parser + tests (corpus) | 3d | Backend |
| 3 | Service + worker + handlers | 2d | Backend |
| 4 | Slash composer integration | 2d | Mobile |
| 5 | List + snooze + cancel | 2d | Mobile |
| 6 | QA, a11y, load | 2d | QA |
| 7 | Beta -> GA | 14d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/165_reminders.up.sql`
- [ ] Down migration
- [ ] Model `internal/models/reminder.go`
- [ ] NL time parser `services/productivity/reminders/nl_time_parser.go` (regex+rules; no LLM)
- [ ] Test corpus 200 phrases golden
- [ ] Service + worker + recurrence
- [ ] Handlers (REST + slash)
- [ ] Wire routes
- [ ] pg_cron `reminders_tick` 30s
- [ ] Audit log
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: parser corpus, recurrence, perm-revoked DM fallback

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/reminders/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Slash autocomplete entry registered with composer
- [ ] Reminder chip widget (parsed preview)
- [ ] List + detail screens
- [ ] Notification action handlers (Done / Snooze)
- [ ] Routing
- [ ] L10n
- [ ] Tests

## 4. AI / Infra Tasks

Not applicable (rules-based parser). Future: optional Llama 3 8B fallback for misses.

## 5. Files Touched

```
backend/
  internal/services/productivity/reminders/
    service.go
    nl_time_parser.go
    nl_time_parser_test.go
    worker.go
  internal/handlers/reminders/
    handler.go
    slash_handler.go
  internal/models/reminder.go
  internal/repo/reminder_repo.go
  cmd/server/main.go                      (edit)
  api/openapi.yaml                        (edit)
mobile/
  lib/features/productivity/reminders/...
  lib/features/composer/...               (edit: register /remind)
  lib/core/router/app_router.dart         (edit)
  lib/l10n/app_en.arb                     (edit)
supabase/
  migrations/165_reminders.up.sql
  migrations/165_reminders.down.sql
```

## 6. Test Plan

- Unit: parser corpus 95% accuracy; service 80%
- Integration: full flow set -> fire -> snooze
- E2E: Maestro: type /remind, advance clock, see push
- Load: 10k pending; worker drains in 5 min
- A11y: VoiceOver on chip preview; notification actions
- Security: cannot set channel reminder where lacks write

## 7. Rollout & Feature Flags

- Flag `feature.reminders.enabled`
- 1% -> 10% -> 50% -> 100% over 14d

## 8. Rollback Plan

1. Flag flip
2. Pause cron
3. Worker stop
4. Tables stay; pending rows expire

## 9. Dependencies / Blockers

- Depends on: composer, push, message-send pipeline
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Parser misses | M | M | corpus tests; user-facing suggestions |
| Recurrence runaway | L | M | cap 365 |
| Quota abuse | L | L | trigger 100/user |

## 11. Cost Model

| Component | Free tier | $ at 100k DAU |
|-----------|-----------|----------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Parser corpus 95% accuracy
- [ ] p99 fire skew < 60s
- [ ] Beta NPS >= 35
- [ ] Zero P0/P1 in 7d
