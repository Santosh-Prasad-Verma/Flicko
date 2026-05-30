# Task Management — Technical Requirements

## 1. Architecture Overview

```
        ┌────────────────────────────────────────────────────────────┐
        │  Mobile (Flutter)                                          │
        │   TaskListScreen ── TaskDetailScreen ── ConvertSheet       │
        │   "/task" composer slash menu                              │
        └─────────┬─────────────────────────┬────────────────────────┘
                  │ REST                      │ Centrifugo WS
                  ▼                           ▼
        ┌────────────────────────────────────────────────────────────┐
        │ Go Backend  internal/services/productivity/tasks           │
        │  ┌───────────┐ ┌────────────┐ ┌──────────────┐             │
        │  │ TaskSvc   │ │ AssignSvc  │ │ SlashParser  │             │
        │  └────┬──────┘ └──────┬─────┘ └──────┬───────┘             │
        │       ▼               ▼              ▼                      │
        │ ┌──────────────── Postgres ───────────────────────────┐    │
        │ │ tasks  task_assignees  task_labels  task_comments   │    │
        │ │ task_history  task_reminders_outbox                 │    │
        │ └─────────────────────────────────────────────────────┘    │
        │       │                              │                      │
        │       ▼                              ▼                      │
        │  ┌──────────┐                  ┌────────────────┐          │
        │  │ Audit    │                  │ ReminderWorker │──▶ Push  │
        │  └──────────┘                  └────────────────┘          │
        └────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- `backend/internal/services/productivity/tasks/service.go`
- `backend/internal/services/productivity/tasks/assign_service.go`
- `backend/internal/services/productivity/tasks/slash_parser.go`
- `backend/internal/services/productivity/tasks/reminder_worker.go`
- `backend/internal/handlers/tasks/task_handler.go`
- `backend/internal/handlers/tasks/comment_handler.go`
- `backend/internal/handlers/tasks/label_handler.go`
- `backend/internal/models/task.go`
- `backend/internal/repo/task_repo.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/task_management/`
  - `data/`: `task_dto.dart`, `task_repository.dart`, `tasks_remote_ds.dart`
  - `domain/`: `task.dart`, `task_status.dart`, `task_priority.dart`, `task_label.dart`
  - `application/`: `tasks_provider.dart`, `task_detail_provider.dart`, `inbox_provider.dart`
  - `presentation/screens/`: `task_list_screen.dart`, `task_detail_screen.dart`, `task_compose_screen.dart`, `task_inbox_screen.dart`
  - `presentation/widgets/`: `task_card.dart`, `assignee_avatars.dart`, `priority_pill.dart`, `due_chip.dart`, `convert_message_sheet.dart`

### Infra
- DB: Supabase Postgres, migration 161
- Realtime: Centrifugo channel `tasks:server:<server_id>` and `tasks:user:<user_id>` (inbox)
- Cache: Redis `tasks:server:<sid>:list:<hash>` 30s, `tasks:user:<uid>:inbox` 60s
- Search: Meilisearch index `tasks`
- Cron: pg_cron `task_reminder_tick` every minute
- Queue: NATS `flicko.tasks.*`

## 3. API Contracts

### REST
```
POST   /api/v1/tasks                          create
GET    /api/v1/tasks?server=&status=&assignee=&label=&q=
GET    /api/v1/tasks/:id                      read
PATCH  /api/v1/tasks/:id                      update
DELETE /api/v1/tasks/:id                      soft-archive
POST   /api/v1/tasks/:id/assignees            { user_ids:[] }
DELETE /api/v1/tasks/:id/assignees/:uid
POST   /api/v1/tasks/:id/comments             { body }
GET    /api/v1/tasks/:id/comments
GET    /api/v1/tasks/:id/history
GET    /api/v1/tasks/inbox?status=open
POST   /api/v1/tasks/from-message             { message_id, title?, assignees?, due_at? }
POST   /api/v1/tasks/labels                   { name, color }
GET    /api/v1/tasks/labels?server=
```

### WebSocket / Centrifugo
- `tasks:server:<server_id>` -> `task.created`, `task.updated`, `task.archived`, `comment.added`
- `tasks:user:<user_id>` -> `inbox.changed`

### Payloads
```jsonc
// Create
{
  "server_id": "uuid",
  "channel_id": "uuid|null",
  "title": "Triage bug reports",
  "description": "Markdown allowed",
  "assignees": ["uuid","uuid"],
  "due_at": "2026-06-08T17:00:00-04:00",
  "due_tz": "America/New_York",
  "priority": "medium",
  "label_ids": ["uuid"],
  "source_message_id": "uuid|null"
}
// Response
{
  "id": "uuid",
  "short_id": 142,                                // server-scoped
  "status": "todo",
  "url": "flicko://server/<sid>/task/142"
}
```

## 4. Permissions & Auth

- Scopes: `tasks.read`, `tasks.write`, `tasks.manage` (delete/archive)
- Members: read, create, comment, self-assign, edit own, change status of tasks they're assigned to
- Mods/admins: full edit including archive
- RLS in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 list latency | <70 ms |
| p99 list latency | <250 ms |
| Inbox query p99 | <300 ms |
| Throughput | 300 rps list |
| Availability | 99.9% |
| Storage cost | <$0.0002 per task/month |
| Compute cost | <$0.0006 per task/month |

## 6. Dependencies

- Existing: messages, audit-log, push-notifications, server-members
- New libraries: none server-side beyond stdlib + existing PG driver
- Mobile: `flutter_slidable: ^3.1.0` for swipe actions, `intl: ^0.19.0` for due date formatting

## 7. Observability

- Metrics:
  - `flicko_tasks_created_total{source}` (manual|message|slash)
  - `flicko_tasks_status_change_total{from,to}`
  - `flicko_tasks_open_total{server}` gauge
  - `flicko_tasks_overdue_total{server}` gauge
  - `flicko_tasks_inbox_query_seconds` histogram
- Logs: structured; failed slash parses warn-logged with redacted body
- Traces: OTel spans on `service.CreateTask`, `slash.Parse`, `worker.fireReminder`
- Dashboard: Grafana board `tasks`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Short-id race (two creators same instant) | duplicate id | Allocator function uses `UPDATE ... RETURNING` inside txn; collision impossible |
| Missing message on convert (deleted) | broken backlink | Snapshot title/body at conversion; null `source_message_id` allowed |
| Assignee removed from server | task orphaned | Keep assignee row; UI shows "Former member" |
| Slash command typo | bad UX | Inline help bubble; `/task ?` prints syntax |
| Reminder worker crash | overdue alerts skipped | At-least-once: `fired_at IS NULL` retried on next tick |
| Search index lag | stale results | Read-from-DB fallback when Meilisearch returns empty + `q` provided |
| Bulk archive | DB write spike | Batch update in chunks of 200 with sleep 50ms |
