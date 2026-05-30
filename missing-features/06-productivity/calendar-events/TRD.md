# Calendar & Events — Technical Requirements

## 1. Architecture Overview

```
        ┌───────────────────────────────────────────────────────────┐
        │                       Mobile (Flutter)                    │
        │  CalendarGridScreen ── EventDetailScreen ── RSVPSheet     │
        └────────────┬───────────────────────────┬──────────────────┘
                     │ REST                       │ Centrifugo WS
                     ▼                            ▼
        ┌───────────────────────────────────────────────────────────┐
        │ Go Backend  internal/services/productivity/calendar       │
        │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │
        │  │ EventService │  │ RsvpService  │  │ RecurrenceEng. │  │
        │  └──────┬───────┘  └──────┬───────┘  └────────┬───────┘  │
        │         │                  │                   │          │
        │         ▼                  ▼                   ▼          │
        │  ┌────────────────── Postgres / Supabase ───────────────┐ │
        │  │ events  event_rsvps  event_occurrences  reminders    │ │
        │  └──────────────────────────────────────────────────────┘ │
        │         │                  │                              │
        │         ▼                  ▼                              │
        │  ┌─────────────┐    ┌──────────────────┐                  │
        │  │ pg_cron tick │──▶│ ReminderWorker   │──▶ NATS push    │
        │  └─────────────┘    └──────────────────┘                  │
        └───────────────────────────────────────────────────────────┘
                     │
                     ▼
        ┌─────────────────────────┐
        │ ICS Endpoint (signed)   │  GET /calendar/<srv>.ics?sig=
        └─────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/productivity/calendar/service.go`
- **Recurrence:** `backend/internal/services/productivity/calendar/recurrence.go`
- **ICS:** `backend/internal/services/productivity/calendar/ics.go`
- **Worker:** `backend/internal/services/productivity/calendar/reminder_worker.go`
- **Handlers:** `backend/internal/handlers/calendar/event_handler.go`
- **Models:** `backend/internal/models/calendar.go`
- **Repo:** `backend/internal/repo/calendar_repo.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/calendar_events/`
  - `data/`: `event_dto.dart`, `event_repository.dart`, `calendar_remote_ds.dart`
  - `domain/`: `event.dart`, `rsvp.dart`, `recurrence_rule.dart`
  - `application/`: `calendar_provider.dart`, `event_detail_provider.dart`
  - `presentation/screens/`: `calendar_grid_screen.dart`, `event_detail_screen.dart`, `event_compose_screen.dart`
  - `presentation/widgets/`: `month_grid.dart`, `agenda_list.dart`, `rsvp_pill.dart`

### Infra
- DB: Supabase Postgres, migration 160
- Realtime: Centrifugo channel `calendar:server:<server_id>`
- Cache: Redis `calendar:server:<server_id>:month:<yyyymm>` TTL 60s
- Cron: pg_cron `calendar_reminder_tick` every minute
- Queue: NATS subject `flicko.calendar.reminder`
- Storage: Appwrite bucket `event-covers`, max 2 MB

## 3. API Contracts

### REST
```
POST   /api/v1/calendar/events                   create event
GET    /api/v1/calendar/events?server=&from=&to= list (range)
GET    /api/v1/calendar/events/:id               read with RSVPs
PATCH  /api/v1/calendar/events/:id               update
DELETE /api/v1/calendar/events/:id               cancel (soft)
POST   /api/v1/calendar/events/:id/rsvp          { state: "yes|no|maybe" }
DELETE /api/v1/calendar/events/:id/rsvp          remove rsvp
GET    /api/v1/calendar/feed/:server.ics?sig=    ICS feed (signed URL)
```

### WebSocket / Centrifugo
- Channel: `calendar:server:<server_id>`
- Events: `event.created`, `event.updated`, `event.cancelled`, `rsvp.changed`

### Payloads
```jsonc
// Create request
{
  "server_id": "uuid",
  "channel_id": "uuid|null",
  "title": "Friday Game Night",
  "description": "Bring your own chips.",
  "starts_at": "2026-06-05T20:00:00-04:00",
  "ends_at":   "2026-06-05T22:00:00-04:00",
  "tz": "America/New_York",
  "location": "Voice: Lounge",
  "rrule": "FREQ=WEEKLY;BYDAY=FR;COUNT=12",
  "capacity": 30,
  "reminders": [1440, 60, 10],
  "cover_image_id": "appwrite-id|null"
}
// Response
{
  "id": "uuid",
  "uid": "evt-7f3...@flicko",
  "next_occurrence": "2026-06-05T20:00:00Z",
  "rsvp_counts": { "yes": 0, "no": 0, "maybe": 0 }
}
```

## 4. Permissions & Auth

- Required scopes: `calendar.read`, `calendar.write`, `calendar.manage` (cancel/delete)
- Server admin / mods get write+manage
- Members get read+rsvp
- ICS feed URL is signed `HMAC-SHA256(user_id|server_id|secret)`; rotate secret yearly
- RLS in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 list latency | <80 ms |
| p99 list latency | <300 ms |
| Reminder fire skew | <30 s |
| Throughput | 200 rps list |
| Availability | 99.9% |
| Storage cost | <$0.0001 per event/month |
| Compute cost | <$0.0008 per event/month |
| GDPR | event row deleted when server deleted; RSVP cascades on user delete |

## 6. Dependencies

- Existing services: servers, channels, members, audit-log, push-notifications
- New libraries:
  - Go: `github.com/teambition/rrule-go v1.8.x`
  - Go: `github.com/arran4/golang-ical v0.3.x`
  - Flutter: `table_calendar: ^3.1.0`, `rrule: ^0.2.16`, `timezone: ^0.10.0`
- External APIs: none (ICS feed served by us)

## 7. Observability

- Metrics:
  - `flicko_calendar_events_created_total{server}`
  - `flicko_calendar_rsvps_total{state}`
  - `flicko_calendar_reminder_fired_total{offset}`
  - `flicko_calendar_reminder_skew_seconds` histogram
  - `flicko_calendar_ics_feed_requests_total{server}`
- Logs: structured JSON; reminder failures route to Sentry
- Traces: OTel spans on `service.CreateEvent`, `worker.fireReminder`, `ics.render`
- Dashboard: Grafana board `calendar`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| pg_cron skipped tick | reminders late | Worker reads `events` directly with lock-skip on next tick; idempotent dispatch |
| RRULE engine bug on DST | wrong occurrence time | Engine unit tests covering Spring/Fall transitions in 5 zones; canary via golden file |
| Push provider down | reminder lost | Fallback to in-app banner + email digest backfill |
| Centrifugo disconnect | UI stale | Pull-to-refresh + ETag on list endpoint |
| ICS feed leaked URL | unauthorized read | Sigs scoped per user; rotate by bumping `users.ics_secret_version` on suspicion |
| Capacity race (over-RSVP) | event over-booked | Insert with `WHERE yes_count < capacity` + serializable txn or row-level lock |
| Bulk recurring expansion | DB write spike | Materialize only next 90d; recompute lazily on access past horizon |
| User timezone mismatch | event shown wrong time | Always send UTC + IANA tz; client renders; never trust client clock |
