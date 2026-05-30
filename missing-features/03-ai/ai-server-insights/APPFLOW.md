# AI Server Insights — APPFLOW

```mermaid
sequenceDiagram
    participant CR as pg_cron
    participant AG as Aggregator
    participant DB as Supabase
    participant LLM as Groq
    participant API as Backend
    participant CH as Mod channel
    participant E as Email (Resend)

    CR->>AG: weekly tick per server
    AG->>DB: run aggregate queries (last 7d)
    DB-->>AG: facts JSON
    AG->>AG: detect patterns (peak hrs, dead channels, churn risk)
    AG->>LLM: summarize {facts, patterns, prior_report}
    LLM-->>AG: prose summary
    AG->>DB: insert insights_reports
    AG->>API: post embed in mod channel
    AG->>E: send opt-in email digest
```

## State Machine
```
report: queued → aggregating → summarizing → published
       \→ skipped (too small)
       \→ failed
```

## Edge Cases
- New server <14d: skip historical compare; show "first report".
- Mostly-inactive server: section "How to revive your server" with checklist.
- Cluster of bots/spam: classifier ignores bot accounts.
- Time-zone aware scheduling.

## Background
- pg_cron `0 9 * * 1` (Monday 09:00 server-local).
- Manual trigger limit 1/day Plus.

## Notifications
- Mod channel: always.
- Admins DM: opt-in.
- Email digest: opt-in.
