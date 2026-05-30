# AI Channel Organizer — APPFLOW

```mermaid
sequenceDiagram
    participant A as Admin
    participant API as Backend
    participant CTX as Context Builder
    participant LLM as Groq
    participant DB as Supabase

    A->>API: POST /servers/:id/organizer/runs
    API->>DB: insert organizer_runs (queued)
    API->>CTX: build {channels, 14d activity}
    CTX-->>API: context json
    API->>LLM: chat completion (prompt + context)
    LLM-->>API: stream JSON suggestions
    API->>DB: insert suggestions rows
    API-->>A: SSE stream
    A->>API: POST /apply {ids}
    API->>API: per id, call channel_service / category_service
    API->>DB: insert audit_log per change
    API-->>A: 200 with applied_ids
```

## State Machine
```
run: queued → running → completed
                     → failed
                     → canceled
suggestion: open → accepted / dismissed
```

## Edge Cases
- Server has 0 channels: nothing to do.
- Generation interrupted: partial suggestions saved, marked partial.
- Apply race vs concurrent admin edits: re-validate target ids before applying; skip stale.
- Reverted changes: keep audit; allow "revert run" within 24h.

## Background
- Runs are sync; no cron.

## Notifications
- "Organizer found 14 suggestions — review now" toast in admin notification center.
