# Scheduled Messages — Technical Requirements

## 1. Architecture Overview

```
        ┌────────────────────────────────────────────────────┐
        │  Mobile (Flutter)                                  │
        │   Composer + ScheduleSheet + ScheduledListScreen   │
        └────────────┬───────────────────────────────────────┘
                     │ REST
                     ▼
        ┌──────────────────────────────────────────────┐
        │ Go Backend                                   │
        │  scheduled_messages_service.go               │
        │  scheduled_messages_handler.go               │
        │  scheduled_messages_worker.go                │
        └──────────┬─────────────────────────┬─────────┘
                   │                          │
                   ▼                          ▼
        ┌──────────────────┐      ┌────────────────────┐
        │ Postgres         │      │ pg_cron tick 30s   │
        │ scheduled_msgs   │◀─────│ scheduled_msgs_tick│
        └──────────────────┘      └────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ MessageService.Send  │  reuses normal send pipeline
        └──────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Centrifugo / fanout   │
        └──────────────────────┘
```

## 2. Components

### Backend (Go)
- `backend/internal/services/productivity/scheduled_messages/service.go`
- `backend/internal/services/productivity/scheduled_messages/worker.go`
- `backend/internal/handlers/scheduled_messages/handler.go`
- `backend/internal/models/scheduled_message.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/scheduled_messages/`
  - `data/`: `scheduled_message_dto.dart`, `repository.dart`
  - `domain/`: `scheduled_message.dart`, `recurrence.dart`
  - `application/`: `scheduled_messages_provider.dart`
  - `presentation/screens/`: `scheduled_list_screen.dart`, `schedule_sheet.dart`
  - `presentation/widgets/`: `schedule_chip.dart`, `picker.dart`

### Infra
- DB: Supabase Postgres, migration 163
- Cron: pg_cron `scheduled_messages_tick` every 30s
- Realtime: Centrifugo `scheduled_messages:user:<uid>`

## 3. API Contracts

### REST
```
POST   /api/v1/scheduled-messages              create
GET    /api/v1/scheduled-messages              list mine
GET    /api/v1/scheduled-messages/:id          read
PATCH  /api/v1/scheduled-messages/:id          edit body or fire_at
DELETE /api/v1/scheduled-messages/:id          cancel
POST   /api/v1/scheduled-messages/:id/send-now bypass timer (also cancels schedule)
```

### Payloads
```jsonc
{
  "channel_id": "uuid",                  // OR dm_user_id
  "dm_user_id": null,
  "body": "## Sunday News\nHi all...",
  "attachments": [{ "id": "appwrite-id", "type": "image/png" }],
  "fire_at": "2026-06-01T13:00:00Z",
  "tz": "America/New_York",
  "recurrence": null                     // or { "freq":"weekly","byday":["SU"],"count":12 }
}
```

## 4. Permissions & Auth

- Scope: `messages.write` (same as normal send)
- Re-check on fire: channel write permission, not muted, not banned
- RLS: owner only on own scheduled rows

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Schedule create p99 | <120 ms |
| Fire-on-time | within 60s of fire_at |
| Worker throughput | 1000 msg/min |
| Storage | <$0.0001 per msg |

## 6. Dependencies

- Existing: messages service, channel-permissions, audit-log
- New libraries: `github.com/teambition/rrule-go` (shared with calendar)

## 7. Observability

- Metrics:
  - `flicko_scheduled_msg_pending` gauge
  - `flicko_scheduled_msg_fired_total{result}` (sent|failed_perm|failed_chan_gone|expired)
  - `flicko_scheduled_msg_skew_seconds` histogram
- Logs: failed fires log redacted body; counter ticks Sentry
- Traces: `worker.fire`, `service.Schedule`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Worker tick missed | message late | Lock-skip retry on next tick; idempotent UNIQUE on row state |
| Channel deleted before fire | failed fire | Mark `failed_chan_gone`; notify owner |
| Permission revoked | failed fire | Mark `failed_perm`; notify owner |
| Owner deleted | orphan | CASCADE delete on user delete |
| DST collision | wrong-time fire | Re-resolve fire_at from tz at the previous tick before next-occurrence schedule |
| Recurrence loop bug | runaway sends | RRULE COUNT cap 365; engine validation |
