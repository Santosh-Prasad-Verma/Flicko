# Stream Analytics — APPFLOW

```mermaid
sequenceDiagram
    participant V as Viewer
    participant CL as Client
    participant LK as Azure ACS
    participant API as Backend
    participant N as NATS
    participant R as Redis
    participant DB as Supabase

    V->>CL: open stream
    CL->>LK: join room
    LK-->>API: webhook participant_joined
    API->>N: publish flicko.stream.events.join
    N->>API: aggregator consumes
    API->>R: ZADD stream:viewers:<id>
    API->>Centrifugo: push concurrent count
    loop every 30s
      CL->>API: heartbeat
      API->>R: refresh score
    end
    Note over R: members idle >60s evicted
    V->>CL: close stream
    CL->>LK: leave
    LK-->>API: webhook participant_left
    API->>N: publish leave
    Note over API,DB: stream_ended event
    API->>API: trigger refresh_stream_aggregates()
    API->>DB: upsert stream_metric_aggregates
    API->>CL: push notification "your summary is ready"
```

## State Machine
```
[live] -> [aggregating] (on stream_ended)
[aggregating] -> [ready] (after MV refresh)
[ready] -> [archived] (30d)
```

## Edge Cases
- Viewer flapping (join/leave repeatedly): debounce — count as 1 unique.
- Stream crashes: detect via missing heartbeat 30s; mark ended.
- Late events post-end: queue 5 min then drop.
- Privacy: user opts out → counted as anon (no user_id).

## Background
- pg_cron `*/5 * * * *` MV refresh.
- pg_cron `0 3 * * *` partition rotate raw events.
- NATS consumer durable name `stream-analytics`.

## Notifications
- "Your stream summary is ready" push 60s after end.
- Deep link: `flicko://stream/<id>/analytics`
