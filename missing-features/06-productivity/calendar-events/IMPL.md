# Calendar & Events — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, design review | 2d | PM/Design |
| 1 | DB migration 160 + recurrence engine | 2d | Backend |
| 2 | EventService, RsvpService, handlers | 4d | Backend |
| 3 | ReminderWorker + pg_cron + ICS feed | 3d | Backend |
| 4 | Mobile screens + providers | 5d | Mobile |
| 5 | Realtime wire-up, deep links, push | 2d | Both |
| 6 | QA, accessibility, load test | 3d | QA |
| 7 | Internal dogfood + closed beta | 7d | All |
| 8 | 1% -> 10% -> 50% -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/160_calendar_events.up.sql`
- [ ] Down migration `160_calendar_events.down.sql`
- [ ] Models `backend/internal/models/calendar.go` (Event, Occurrence, RSVP, ReminderRow)
- [ ] Recurrence engine wrapping `teambition/rrule-go` with DST tests
- [ ] Service `backend/internal/services/productivity/calendar/service.go`
- [ ] RSVP service with capacity-aware insert (serializable txn)
- [ ] ICS renderer using `arran4/golang-ical`, signed URL middleware
- [ ] Worker `reminder_worker.go` with `FOR UPDATE SKIP LOCKED LIMIT 500`
- [ ] pg_cron job `calendar_reminder_tick` and `calendar_horizon_extend`
- [ ] Handlers `event_handler.go`, `rsvp_handler.go`, `ics_handler.go`
- [ ] Wire routes in `backend/cmd/server/main.go` under `/api/v1/calendar`
- [ ] Centrifugo channel hookup `calendar:server:<id>`
- [ ] Permission middleware honoring `calendar.read|write|manage`
- [ ] Audit log entries on create/edit/cancel
- [ ] Prometheus counters per metric in TRD section 7
- [ ] OpenAPI doc update in `backend/api/openapi.yaml`
- [ ] Unit tests: recurrence (table-driven across 5 zones), capacity race, ICS parse round-trip
- [ ] Integration: testcontainers Postgres + cron + worker

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/productivity/calendar_events/`
- [ ] DTOs from `event_dto.dart` matching API payloads exactly
- [ ] Repository talking to REST + Centrifugo
- [ ] Domain entities `event.dart`, `recurrence_rule.dart`, `rsvp.dart`
- [ ] Riverpod providers: month-keyed `calendarMonthProvider`, `eventDetailProvider`, `rsvpControllerProvider`
- [ ] Screens: `calendar_grid_screen.dart`, `event_detail_screen.dart`, `event_compose_screen.dart`
- [ ] Widgets: `month_grid.dart` (table_calendar wrapper), `agenda_list.dart`, `rsvp_pill.dart`, `recurrence_picker.dart`
- [ ] Routing additions to `app_router.dart` (`/server/:sid/calendar`, `/server/:sid/calendar/event/:id`)
- [ ] Deep link handler `flicko://calendar/event/<id>`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (titles, copy from UIUX.md section 7)
- [ ] Tests: widget tests on grid/agenda; provider tests on rsvp flow; one golden for empty state
- [ ] Empty/error/loading states matching UIUX.md
- [ ] Push notification handler routes deep link to event detail

## 4. AI / Infra Tasks

Not applicable for v1. Future: AI-suggest event title from a free-text description.

## 5. Files Touched (predicted)

```
backend/
  internal/services/productivity/calendar/
    service.go                                       (new)
    rsvp_service.go                                  (new)
    recurrence.go                                    (new)
    recurrence_test.go                               (new)
    ics.go                                           (new)
    reminder_worker.go                               (new)
  internal/handlers/calendar/
    event_handler.go                                 (new)
    rsvp_handler.go                                  (new)
    ics_handler.go                                   (new)
  internal/models/calendar.go                        (new)
  internal/repo/calendar_repo.go                     (new)
  cmd/server/main.go                                 (edit: routes + worker)
  api/openapi.yaml                                   (edit)
mobile/
  lib/features/productivity/calendar_events/...      (new tree)
  lib/core/router/app_router.dart                    (edit)
  lib/l10n/app_en.arb                                (edit)
supabase/
  migrations/160_calendar_events.up.sql              (new)
  migrations/160_calendar_events.down.sql            (new)
```

## 6. Test Plan

- Unit: 80% coverage on calendar package; recurrence engine 95%
- Integration: full flow create -> RSVP -> reminder fires (testcontainers)
- E2E: Maestro flow: create weekly event, RSVP, advance clock, see push
- Load: k6 hitting `/calendar/events?from=&to=` at 200 rps for 5m, p99 < 300ms
- Accessibility: TalkBack/VoiceOver pass on grid + detail; high-contrast theme; reduced motion swaps grid scroll for fade
- Security: ICS signed URL fuzz (replace sig, expired sig, wrong user); RLS row leakage tests

## 7. Rollout & Feature Flags

- Flag: `feature.calendar_events.enabled` (Doppler)
- Server-level allowlist while in beta: `feature.calendar_events.servers`
- Default OFF in prod
- Internal dogfood -> closed beta (20 servers) -> 1% -> 10% -> 50% -> 100% over 21 days
- Kill switch verified in staging: flips flag, worker exits cleanly inside 60s

## 8. Rollback Plan

1. Flip `feature.calendar_events.enabled` to false (instant; UI hides nav entry, API returns 404)
2. Stop ReminderWorker via supervisor signal
3. Pause pg_cron jobs `calendar_reminder_tick`, `calendar_horizon_extend`
4. Leave tables in place even if reverting code (data is cheap; rollback should not lose RSVPs)
5. Down migration only if data is corrupted

## 9. Dependencies / Blockers

- Depends on: push-notifications, audit-log, server-members (existing)
- Blocks: nothing P0; loosely related to scheduled-messages (shared cron infra)
- External: none

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| RRULE engine DST bug | M | H | golden tests across 5 IANA zones |
| Reminder lateness > 1 min | M | M | move to dedicated worker if pg_cron skew exceeds threshold |
| ICS feed leaked | L | M | rotate secret; signed URL; per-user revoke |
| Capacity over-RSVP under load | L | M | serializable txn + capacity guard |
| Mobile picker UX overwhelm for RRULE | H | M | hide custom RRULE behind "Custom" advanced toggle |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (worker + handlers) | Railway free | $0 |
| DB rows | Supabase free | $0 (well under 500MB) |
| Push fanout | FCM/APNs free | $0 |
| Storage (event covers) | Appwrite free | $0 |
| ICS bandwidth | small | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] Recurrence engine has table-driven tests in 5 IANA zones
- [ ] ICS feed validates against RFC 5545 in CI (`golang-ical` round-trip)
- [ ] Metrics dashboard live in Grafana
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 7-day window post-GA
