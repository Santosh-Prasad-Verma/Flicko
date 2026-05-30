# Reminders — Technical Requirements

## 1. Architecture Overview

```
        ┌────────────────────────────────────┐
        │ Mobile (Flutter)                   │
        │  Composer -> /remind autocomplete  │
        │  ReminderListScreen (cancel/snooze)│
        └─────────────┬──────────────────────┘
                      │ REST
                      ▼
        ┌────────────────────────────────────┐
        │ Go Backend                         │
        │  reminders_service.go              │
        │  reminders_handler.go              │
        │  nl_time_parser.go                 │
        │  reminder_worker.go                │
        └─────────────┬──────────────────────┘
                      │ pg_cron 30s
                      ▼
        ┌────────────────────────────────────┐
        │ Postgres reminders                 │
        └─────────────┬──────────────────────┘
                      ▼
        ┌────────────────────────────────────┐
        │ Push / In-app / Channel post       │
        └────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- `backend/internal/services/productivity/reminders/service.go`
- `backend/internal/services/productivity/reminders/nl_time_parser.go`
- `backend/internal/services/productivity/reminders/worker.go`
- `backend/internal/handlers/reminders/handler.go`
- `backend/internal/handlers/reminders/slash_handler.go`
- `backend/internal/models/reminder.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/reminders/`
  - `data/`, `domain/`, `application/`, `presentation/`

### Infra
- DB: Postgres, migration 165
- Cron: pg_cron tick every 30s
- Push: existing FCM/APNs pipeline
- NL parser: in-process Go (no external API in v1)

## 3. API Contracts

### REST
```
POST   /api/v1/reminders                      create from structured payload
POST   /api/v1/reminders/slash                create from raw slash body
GET    /api/v1/reminders                      list mine
PATCH  /api/v1/reminders/:id                  edit (text, fire_at)
POST   /api/v1/reminders/:id/snooze           { offset_min }
DELETE /api/v1/reminders/:id                  cancel
```

### Payloads
```jsonc
// Slash
{ "body": "me in 30m follow up with priya" }
// Structured
{
  "scope": "self|channel|dm",
  "channel_id": "uuid|null",
  "dm_user_id": "uuid|null",
  "text": "follow up with priya",
  "fire_at": "2026-06-01T13:30:00Z",
  "tz": "America/New_York",
  "rrule": null
}
```

## 4. Permissions & Auth

- Scope: `reminders.write`
- Channel reminder requires sender to have `messages.write` in target channel
- RLS: owner-only on rows
- DM reminders: target user does not need to consent (it's an at-me-from-me reminder); but channel reminder posts visible

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Parse + create p99 | <120 ms |
| Fire-on-time | within 60s |
| Throughput | 1500 reminders/min worker |
| Storage | <$0.00005 per reminder |

## 6. Dependencies

- Existing: messages send pipeline, push, audit-log
- Reuses time grammar test corpus

## 7. Observability

- `flicko_reminders_set_total{scope}`
- `flicko_reminders_parse_failed_total{reason}`
- `flicko_reminders_fired_total{result}`
- `flicko_reminders_skew_seconds` histogram

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Ambiguous parse | "?" help inline; user retries with explicit time |
| Channel write revoked | DM fallback to setter; audit log |
| User logged out | reminder still fires; push to last device |
| Recurrence runaway | Cap at 365 fires |
| Worker delay | 30s tick + look-ahead |
