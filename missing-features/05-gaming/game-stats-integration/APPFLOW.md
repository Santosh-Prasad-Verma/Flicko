# Game Stats Integration — APPFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile
    participant API as Backend
    participant P as Provider (Riot/Steam/...)
    participant DB as Supabase
    participant W as Stats Worker

    U->>M: link Riot account
    M->>API: POST /oauth/riot/start
    API-->>M: authorize_url
    M->>P: redirect (browser/webview)
    P->>API: callback {code}
    API->>P: exchange code → tokens
    API->>DB: upsert linked_game_accounts (encrypted tokens)
    API->>W: enqueue initial fetch
    W->>P: GET stats
    W->>DB: insert game_stats_snapshots
    W->>API: PATCH stats summary
    API->>Centrifugo: user:<id> {stats_updated}
    Note over W: cron every 6h refreshes
```

## State Machine
```
account: [unlinked] → [linking] → [linked] → [refreshing] → [linked]
                              \→ [error] (re-prompt)
```

## Edge Cases
- Provider rate limit: serve cached, mark stale.
- Token revoked by user externally: detect on 401, re-prompt.
- Visibility = friends: only resolved when viewer is friend at request time.
- Profile lookup of disabled provider: hide section gracefully.

## Background
- pg_cron 6h refresh.
- Token rotation cron daily.
- Rank change → auto-grant/revoke roles per `rank_role_rules`.

## Notifications
- Optional: "You ranked up to Diamond III!" (user-toggle).
- Server-bot announcement: configurable.
