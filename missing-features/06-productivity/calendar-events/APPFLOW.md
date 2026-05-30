# Calendar & Events — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile (Flutter)
    participant API as Go Backend
    participant DB as Supabase
    participant CRON as pg_cron
    participant W as ReminderWorker
    participant RT as Centrifugo
    participant PUSH as Push Provider

    Note over U,PUSH: Create event
    U->>M: Tap "+ New Event"
    M->>API: POST /calendar/events
    API->>DB: INSERT events (...)
    API->>DB: expand RRULE -> event_occurrences (next 90d)
    API->>DB: enqueue event_reminders_outbox rows
    API->>RT: publish calendar:server:<sid> "event.created"
    DB-->>API: ok
    API-->>M: 201 {id, next_occurrence}
    M-->>U: shows on grid + toast "Event created"

    Note over U,PUSH: RSVP
    U->>M: Taps "Going"
    M->>API: POST /calendar/events/:id/rsvp {state:yes}
    API->>DB: UPSERT event_rsvps
    API->>DB: trigger recount_event_rsvps()
    API->>RT: publish "rsvp.changed"
    API-->>M: 200 {counts}
    M-->>U: pill turns green; counts animate

    Note over U,PUSH: Reminder fires
    CRON->>W: tick every 60s
    W->>DB: SELECT outbox WHERE fire_at<=now()+60s FOR UPDATE SKIP LOCKED
    W->>PUSH: dispatch push to user
    W->>DB: UPDATE outbox SET fired_at=now()
    PUSH-->>U: push notification "Friday Game Night in 10 min"
    U->>M: tap deep link flicko://calendar/event/<id>
```

## 2. State Machine

```
event lifecycle:
  [draft] -- save --> [scheduled]
  [scheduled] -- edit --> [scheduled]
  [scheduled] -- cancel --> [cancelled]
  [scheduled] -- end_time_passed --> [completed]
  [cancelled] -- (terminal) --> [cancelled]
  [completed] -- archive 90d --> [purged]

rsvp lifecycle (per user, per occurrence):
  [none] -- click yes/no/maybe --> [yes|no|maybe]
  [yes] -- capacity full + late join --> [waitlist]
  [waitlist] -- spot opens --> [yes]
  [yes|no|maybe] -- remove --> [none]
```

## 3. User Journeys

### J1 — Moderator creates a recurring weekly game night
1. Mod opens server, taps "Calendar" tab in side rail.
2. Taps FAB "+ New Event".
3. Fills title "Friday Game Night", picks Friday 8pm-10pm in NYC tz.
4. Toggles "Repeats" -> Weekly -> Friday, ends after 12 occurrences.
5. Sets channel to #lounge-voice; reminders default 24h/1h/10m.
6. Taps Save -> sees occurrence chips appear on month grid.
7. Bot posts "New event scheduled" in #lounge-voice with RSVP buttons.

### J2 — Member RSVPs and gets reminded
1. Member sees "Friday Game Night" pill on calendar.
2. Taps event -> detail sheet -> taps "Going".
3. Receives confirmation toast "You're going. Reminder set for 10m before."
4. 7:50pm Friday: push fires "Game Night in 10 min", deep links to event.
5. Member taps -> joins voice channel from event detail.

### J3 — Member subscribes from phone calendar
1. On event detail, tap overflow -> "Subscribe in calendar".
2. App resolves signed ICS feed URL; OS opens Add-to-Calendar.
3. Phone calendar polls feed; new occurrences appear automatically.
4. RSVP changes do not flow back (one-way feed in v1).

### J4 — First-time empty state
1. New member opens Calendar tab.
2. Sees illustration of a wall calendar with "No upcoming events".
3. Below: "When mods schedule something, it'll appear here."
4. CTA: "Browse other servers' public events" -> discover screen.

### J5 — Moderator cancels an occurrence
1. Mod opens Friday's occurrence -> overflow -> "Cancel this occurrence".
2. Confirm dialog explains rest of the series stays.
3. Backend adds Friday to `exdate`; outbox rows for that occurrence purged.
4. Members who RSVP'd yes get a push "Cancelled: Friday Game Night".

## 4. Edge Cases

- **Offline create:** Form local-buffered; on reconnect POST queued. Show
  pending state with clock icon.
- **Permission denied (member tries to create):** FAB hidden; if deep link
  reaches compose screen, a banner explains and blocks save.
- **DST transition:** Engine uses IANA tz, so 8pm local stays 8pm local even
  when offset changes; tests cover Spring forward and Fall back.
- **Concurrent edits:** Optimistic locking via `events.updated_at`; second writer
  gets 409, UI shows "Event changed; reload?".
- **Capacity race:** Insert RSVP with `WHERE yes_count < capacity` guard inside
  serializable transaction; loser routed to waitlist.
- **RRULE too greedy:** Hard cap at 365 occurrences materialized; UI warns
  "Recurrence too long" if user picks something boundless without COUNT/UNTIL.
- **Reminder past start time:** Worker skips and logs; never fires backwards.
- **Network slow:** Compose screen optimistic; rollback with snackbar on failure.

## 5. Background / Async

- **Reminder dispatch:**
  - Triggered by: pg_cron `calendar_reminder_tick` every minute
  - Worker: claims rows `FOR UPDATE SKIP LOCKED LIMIT 500`
  - Idempotency key: `(event_id,user_id,occ_starts_at,offset_min)` UNIQUE
  - Failure: retry 3 with backoff 30s/2m/10m; then DLQ row in
    `event_reminders_outbox.last_error`
- **Occurrence horizon extension:**
  - Triggered by: nightly cron `calendar_horizon_extend`
  - Extends materialized occurrences for any series whose last materialized row
    is within 30 days of now, up to 90-day rolling horizon.
- **Series cleanup on cancel:**
  - When event cancelled, delete future outbox rows + occurrences.

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Event created in subscribed server | in-app | "{Mod} scheduled {title} for {when}" | `flicko://calendar/event/<id>` | 1 per server per 5m |
| RSVP yes confirmed | toast | "You're going. We'll remind you {offset} before." | inline | none |
| T-24h reminder | push | "Tomorrow: {title} at {time}" | `flicko://calendar/event/<id>` | once per event |
| T-1h reminder | push | "{title} starts in 1 hour" | same | once |
| T-10m reminder | push high-priority | "{title} starts in 10 min" | same | once |
| Cancellation | push + in-app | "Cancelled: {title} on {date}" | `flicko://calendar/event/<id>` | once |
| Daily digest | email | "Today on {server}: {n} events" | weblink | max 1/day |

Voice: friendly, concise. No jargon. Uppercase only proper nouns.
