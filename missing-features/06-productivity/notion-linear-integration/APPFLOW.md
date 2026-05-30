# Notion / Linear Integration — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant Adm as Admin
    participant M as Mobile/Web
    participant API as Flicko Backend
    participant L as Linear
    participant N as Notion
    participant DB as Postgres
    participant W as ReverseSync

    Note over Adm,N: Install Linear
    Adm->>M: Settings -> Integrations -> Linear -> Install
    M->>API: POST /integrations/linear/install/start
    API-->>M: 302 to https://linear.app/oauth/authorize?...
    M->>L: User authorizes
    L-->>API: GET /linear/install/callback?code=
    API->>L: exchange code -> {access_token, refresh_token, workspace}
    API->>DB: INSERT integrations (encrypted_token, ...)
    API->>L: POST /webhooks/subscribe url=/webhooks/linear
    API-->>M: 200 + integration_id
    M-->>Adm: Mapping screen

    Note over Adm,DB: Map team -> channel
    Adm->>M: pick Linear team #api -> Flicko #engineering
    M->>API: POST /integrations/:id/mappings
    API->>L: GET issues filter team=api updated>30d
    API->>DB: backfill INSERT tasks + integration_links
    API-->>M: 200 with progress

    Note over L,DB: Live event
    L->>API: POST /webhooks/linear (issue.update)
    API->>API: verify HMAC + idempotency
    API->>API: Normalize -> Map
    API->>DB: UPSERT tasks via integration_link
    API->>DB: insert integration_audit
    API->>RT: publish task.updated

    Note over W,L: Reverse sync
    W->>DB: SELECT pending_outbox
    W->>L: PATCH issue status=...
    W->>DB: mark synced
```

## 2. State Machine

```
connector:
  [active] -- token expired & refresh fail --> [needs_reinstall]
  [active] -- admin disable --> [paused]
  [paused] -- enable --> [active]
  [active] -- uninstall --> [removed]

per-mapping link:
  [linked] -- external delete --> [orphan]
  [linked] -- flicko archive --> [linked but hidden]
  [orphan] -- restore link --> [linked]
```

## 3. User Journeys

### J1 — Connect Linear and map a team
1. Admin opens Settings -> Integrations -> Linear -> Install.
2. OAuth dialog opens; admin authorizes.
3. Returns to Flicko mapping screen; picks team "api" -> channel "#engineering".
4. Backfill runs; tasks appear in #engineering and on board if linked.
5. Admin sees progress 0% -> 100%.

### J2 — Status change in Linear reflects in Flicko
1. PM moves Linear issue to "In Progress".
2. Webhook fires; Flicko updates corresponding task to status `in_progress`.
3. Bot posts a thread reply in #engineering: "Linear: APP-23 -> In Progress".

### J3 — Status change in Flicko reflects in Linear
1. Engineer marks Flicko task done.
2. ReverseSyncWorker batches updates every 30s.
3. Linear issue closed; Flicko task gets a sync timestamp.

### J4 — Notion DB sync (poll-based)
1. Admin connects Notion; picks "Roadmap" DB filter "Status != Archived" -> #planning.
2. Notion poller runs every 5 min; webhook fires on page edit.
3. New rows appear as tasks; status changes propagate.

### J5 — Token expires
1. Refresh token returns 401.
2. Connector enters `needs_reinstall`; banner in Settings; sync paused.
3. Admin reinstalls; sync resumes from last cursor.

## 4. Edge Cases

- **Cycle:** Flicko -> Linear -> webhook returns to Flicko. Idempotency key blocks re-apply.
- **Bulk import:** rate-limit ingestion to 50/s; backfill marked as priority=low.
- **Filter changed mid-sync:** snapshot filter at mapping create; admin must re-confirm to switch.
- **Linear assignee not in Flicko server:** create unassigned task with note.
- **Webhook out-of-order:** events carry `updated_at`; ignore if older than current task `updated_at`.
- **Encrypted token DB read failure:** retry; on persistent failure mark needs_reinstall.

## 5. Background / Async

- Notion poller: 5 min for each connected DB
- ReverseSyncWorker: 30s tick batching outbox
- Token refresh: hourly check; refresh anything within 1h of expiry
- Health monitor: hourly; webhook delivery rate < 95% triggers alert

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Connector installed | bot post in #integrations | "Linear connected. {n} items synced." | Settings -> Integrations | once |
| Sync error spike | DM admin | "Linear sync errors: {n}. Investigating." | Settings | hourly |
| Token needs re-install | DM admin | "Linear connection expired. Re-install in Settings." | Settings | once per state change |
| Conflict (external wins) | thread reply on task | "Conflicting change resolved by Linear." | task | once per conflict |

Voice: factual, admin-targeted.
