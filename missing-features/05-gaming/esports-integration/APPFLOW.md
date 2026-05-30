# Esports Integration — APPFLOW

```mermaid
sequenceDiagram
    participant CR as Cron 60s
    participant P as Poller
    participant PS as PandaScore
    participant DB as Supabase
    participant N as NATS
    participant API as Backend
    participant CH as Channel

    CR->>P: tick
    P->>PS: GET /matches/upcoming?per_page=50
    PS-->>P: list
    P->>DB: upsert esports_events
    P->>P: diff vs prev
    P->>N: publish flicko.esports.update {ids}
    N-->>API: dispatcher
    API->>DB: SELECT subs matching event.game/team/league
    loop per matching subscription
      API->>API: render embed
      API->>CH: post or edit message in channel
      API->>DB: upsert esports_event_messages
    end
```

## State Machine
```
event: [upcoming] → [live] → [finished]
                 \─→ [canceled]
subscription: [active] ⇄ [muted] (admin)
```

## Edge Cases
- Match postponed: status reverts to upcoming with new time; embed edited.
- Tournament rebracketing: new event row, old finished.
- Multiple subs for same match: post once per channel; edit single message.
- PandaScore inconsistency: check & trust local clock if mismatch.

## Background
- pg_cron 60s tick for live polling, 5m tick for upcoming.
- Schedule digest cron weekly Mon 09:00 server-local.

## Notifications
- "T1 just won game 2 vs GenG" message edit notification (channel-level).
- No global push by default.
