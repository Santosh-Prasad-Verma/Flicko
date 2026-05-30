# Scheduled Messages — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | Migration 163 + model | 1d | Backend |
| 2 | Service + worker + handler | 3d | Backend |
| 3 | Mobile sheet + list | 3d | Mobile |
| 4 | Wire-up + audit log + metrics | 1d | Both |
| 5 | QA, a11y, load | 2d | QA |
| 6 | Beta -> GA | 14d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/163_scheduled_messages.up.sql`
- [ ] Down migration
- [ ] Model `internal/models/scheduled_message.go`
- [ ] Repo `internal/repo/scheduled_message_repo.go`
- [ ] Service `services/productivity/scheduled_messages/service.go`
- [ ] Worker `services/productivity/scheduled_messages/worker.go` with `FOR UPDATE SKIP LOCKED`
- [ ] Recurrence helper using `rrule-go` (shared with calendar)
- [ ] Handler `handlers/scheduled_messages/handler.go`
- [ ] Wire routes
- [ ] pg_cron `scheduled_messages_tick` every 30s
- [ ] Quota trigger
- [ ] Audit log on schedule, edit, cancel, fire
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: worker happy path, perm-denied path, channel-gone path, recurrence next-step, quota trigger

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/scheduled_messages/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Domain entities
- [ ] Composer integration (clock icon -> sheet)
- [ ] ScheduleSheet with quick pills + custom picker + recurrence
- [ ] ScheduledListScreen
- [ ] ScheduleDetailScreen (edit body + time)
- [ ] Routing additions
- [ ] L10n keys
- [ ] Tests: provider tests on schedule + cancel; widget tests on sheet; one golden empty state

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched

```
backend/
  internal/services/productivity/scheduled_messages/
    service.go
    worker.go
  internal/handlers/scheduled_messages/handler.go
  internal/models/scheduled_message.go
  internal/repo/scheduled_message_repo.go
  cmd/server/main.go                            (edit)
  api/openapi.yaml                              (edit)
mobile/
  lib/features/productivity/scheduled_messages/...
  lib/core/router/app_router.dart               (edit)
  lib/l10n/app_en.arb                           (edit)
  lib/features/composer/...                     (edit: add clock icon)
supabase/
  migrations/163_scheduled_messages.up.sql
  migrations/163_scheduled_messages.down.sql
```

## 6. Test Plan

- Unit: 80% coverage; recurrence golden across DST transitions
- Integration: testcontainers Postgres + cron + worker fires under 60s
- E2E: Maestro: compose, schedule, advance clock, see sent message
- Load: schedule 10k pending; worker drains under 5 min
- A11y: VoiceOver on sheet (time picker)
- Security: cannot schedule into a channel where user lacks write

## 7. Rollout & Feature Flags

- Flag `feature.scheduled_messages.enabled`
- 1% -> 10% -> 50% -> 100% over 14d
- Kill switch flips flag and pauses cron

## 8. Rollback Plan

1. Flip flag
2. Pause cron
3. Stop worker
4. Tables stay; pending rows expire harmlessly

## 9. Dependencies / Blockers

- Depends on: messages send pipeline, audit-log
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cron skew | M | M | 30s tick + look-ahead window 30s |
| Worker double-fire | L | H | UNIQUE on `fired_message_id`; state transitions |
| Recurrence runaway | L | M | Hard cap 365 occurrences |
| Quota abuse | M | L | Trigger blocks at 50 pending |

## 11. Cost Model

| Component | Free tier | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Worker fires under 60s p99
- [ ] Recurrence DST tests green
- [ ] Beta NPS >= 40
- [ ] Zero P0/P1 in 7-day window
