# Task Management — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 2d | PM |
| 1 | Migration 161 + models + repo | 2d | Backend |
| 2 | TaskService + AssignService + handlers | 4d | Backend |
| 3 | SlashParser + ConvertFromMessage | 2d | Backend |
| 4 | ReminderWorker + cron + history | 2d | Backend |
| 5 | Mobile screens + inbox | 5d | Mobile |
| 6 | Realtime + slash UX | 2d | Both |
| 7 | QA, a11y, load | 3d | QA |
| 8 | Beta -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/161_task_management.up.sql`
- [ ] Down migration
- [ ] `internal/models/task.go` (Task, Assignee, Label, Comment, History)
- [ ] `internal/repo/task_repo.go` with prepared statements
- [ ] `services/productivity/tasks/service.go`
- [ ] `services/productivity/tasks/assign_service.go`
- [ ] `services/productivity/tasks/label_service.go`
- [ ] `services/productivity/tasks/slash_parser.go` (table-driven grammar)
- [ ] `services/productivity/tasks/reminder_worker.go` (`SELECT ... FOR UPDATE SKIP LOCKED`)
- [ ] Handlers: `task_handler.go`, `comment_handler.go`, `label_handler.go`, `slash_handler.go`
- [ ] Wire routes in `cmd/server/main.go`
- [ ] Centrifugo channels `tasks:server:<sid>` and `tasks:user:<uid>`
- [ ] Permission middleware
- [ ] Audit log entries
- [ ] Meilisearch sync on create/update/archive (NATS subscriber)
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Unit tests: parser grammar, allocator concurrency, status transitions
- [ ] Integration: testcontainers Postgres + Meilisearch

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/task_management/`
- [ ] DTOs match API exactly; generated via `freezed`
- [ ] Repositories + remote datasource
- [ ] Domain entities + state enums
- [ ] Riverpod providers: filtered list, inbox, detail, compose form
- [ ] Screens: list, detail, compose, inbox
- [ ] Widgets: task card with swipe (Slidable), priority pill, due chip, assignee stack
- [ ] Convert-from-message bottom sheet (long-press menu hook)
- [ ] Slash command UI (autocomplete chips for `/task new|assign|done|list`)
- [ ] Routing: `/server/:sid/tasks`, `/server/:sid/task/:short`
- [ ] Deep link handler `flicko://server/<sid>/task/<short>`
- [ ] L10n keys
- [ ] Tests: widget tests on list + detail; provider tests; one golden

## 4. AI / Infra Tasks

- Optional v1.1: AI suggests assignee from message content (Groq Llama 3 8B). Not v1.

## 5. Files Touched (predicted)

```
backend/
  internal/services/productivity/tasks/
    service.go
    assign_service.go
    label_service.go
    slash_parser.go
    slash_parser_test.go
    reminder_worker.go
  internal/handlers/tasks/
    task_handler.go
    comment_handler.go
    label_handler.go
    slash_handler.go
  internal/models/task.go
  internal/repo/task_repo.go
  cmd/server/main.go                             (edit)
  api/openapi.yaml                               (edit)
mobile/
  lib/features/productivity/task_management/...  (new tree)
  lib/core/router/app_router.dart                (edit)
  lib/l10n/app_en.arb                            (edit)
supabase/
  migrations/161_task_management.up.sql
  migrations/161_task_management.down.sql
```

## 6. Test Plan

- Unit: 80% on tasks package; slash parser 95%
- Integration: convert-message flow end-to-end
- E2E: Maestro flow create -> assign -> due -> reminder fires
- Load: k6 inbox 300 rps for 5 min, p99 < 300ms
- Accessibility: TalkBack on list/detail; high-contrast tested
- Security: RLS leakage tests; assignee-not-in-server case; slash injection

## 7. Rollout & Feature Flags

- Flag `feature.task_management.enabled` (Doppler)
- Internal -> 20-server beta -> 1% -> 10% -> 50% -> GA over 28 days
- Server-level allowlist during beta

## 8. Rollback Plan

1. Flip flag (instant; nav hidden, API 404)
2. Pause cron
3. Stop worker
4. Leave tables; data is cheap
5. Down migration only on data corruption

## 9. Dependencies / Blockers

- Depends on: messages, audit-log, push-notifications, search-index
- Blocks: kanban-boards (consumes same `tasks` table)
- External: none

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Slash parser ambiguity | M | M | golden test suite; "/task ?" help text |
| Inbox slow at scale | L | M | composite index (assignee, status, due_at); pagination |
| Convert UX confusing | M | L | onboarding tooltip first 3 uses |
| Label color clutter | L | L | server cap 24 labels |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB rows | Supabase | $0 (well under quota) |
| Meilisearch | self-host | $0 |
| Push | FCM/APNs | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Slash parser test suite green
- [ ] Inbox p99 < 300ms in load test
- [ ] Beta NPS >= 30
- [ ] Zero P0/P1 in 7-day window
