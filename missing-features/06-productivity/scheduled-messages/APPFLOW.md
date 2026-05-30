# Scheduled Messages — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile
    participant API as Go Backend
    participant DB as Postgres
    participant CRON as pg_cron 30s
    participant W as Worker
    participant MSG as MessageService
    participant RT as Centrifugo

    U->>M: types message, taps "Send later"
    M->>API: POST /scheduled-messages {body, fire_at, tz}
    API->>DB: INSERT scheduled_messages state=pending
    API-->>M: 201 {id, fire_at_local}
    M-->>U: chip "Scheduled for Sunday 9am"

    Note over CRON,W: Every 30 seconds
    CRON->>DB: SELECT process_scheduled_messages()
    DB->>W: dispatch via NATS or in-process loop
    W->>DB: SELECT FOR UPDATE SKIP LOCKED batch (fire_at <= now+30s)
    W->>DB: UPDATE state=firing
    W->>MSG: SendOnBehalf(user_id, channel_id, body, attachments)
    MSG->>RT: publish channel feed
    MSG-->>W: ok / err(reason)
    alt success
      W->>DB: UPDATE state=sent, fired_message_id, fired_at
    else failure
      W->>DB: UPDATE state=failed, failure_reason; attempts++
    end
    Note over W: if rrule: compute next fire_at, INSERT new row state=pending
```

## 2. State Machine

```
[pending] -- edit --> [pending]
[pending] -- cancel --> [cancelled]
[pending] -- worker claims --> [firing]
[firing] -- send ok --> [sent]
[firing] -- perm denied / channel gone --> [failed]
[firing] -- transient err, attempts<3 --> [pending]
[firing] -- attempts>=3 --> [expired]
```

## 3. User Journeys

### J1 — Sunday newsletter
1. Mod opens compose box Saturday afternoon, drafts a long announcement.
2. Taps clock icon next to send button.
3. Sheet appears with quick chips: Tomorrow 9am, Monday 9am, Custom.
4. Picks Sunday 9am in their tz; confirms.
5. Compose closes; toast "Scheduled for Sunday 9am".
6. Sunday at 9:00:18 the message appears in channel under their name.

### J2 — Edit before fire
1. Mod opens "My scheduled" list from compose menu.
2. Sees pending message; taps to edit body.
3. Saves; fire_at unchanged unless they tap pencil on time.

### J3 — Recurring weekday
1. Power user picks "Repeat" -> "Weekdays at 9am".
2. Backend stores `rrule=FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;COUNT=20`.
3. After each fire, worker schedules next occurrence with same body.

### J4 — Failure path: channel deleted
1. Channel is deleted by owner.
2. Worker tries to send; `failed_chan_gone`.
3. User gets in-app: "Couldn't send your scheduled message — the channel was removed."

### J5 — First-time empty state
1. User opens "My scheduled".
2. Empty illustration; "No scheduled messages".
3. CTA "Compose with 'Send later'".

## 4. Edge Cases

- **Offline at compose:** local-buffer schedule; sync on reconnect.
- **Permission revoked:** worker does authoritative check; fails with reason.
- **DST cross:** server stores tz; recomputes at each tick using IANA db.
- **Quota hit (50 pending):** API returns 429 with `quota_exceeded`.
- **Body edited by another device:** last-write-wins; updated_at conflict 412.
- **User logged out before fire:** still fires; user is owner of message.
- **Attachment missing at fire:** strip attachment, send body, log warning.
- **Recurrence beyond cap:** worker stops auto-rolling after 365 fires.

## 5. Background / Async

- Worker tick: 30s
- Lock claim: `FOR UPDATE SKIP LOCKED LIMIT 200`
- Idempotency: state transitions; `fired_message_id` UNIQUE
- Failure: 3 retries with exponential backoff before `expired`
- Attachment copy-forward: at fire time, server reuses attachment IDs

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Schedule confirmed | toast | "Scheduled for {time}" | inline | none |
| Fire failed (perm) | in-app | "Couldn't send your scheduled message in #{channel}: no permission" | edit screen | once |
| Fire failed (channel gone) | in-app | "Channel was removed; message not sent." | list | once |
| Quota near limit | in-app | "You have 45 of 50 scheduled messages." | list | once |

Voice: factual, brief, owner-only.
