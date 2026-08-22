# Watch Parties (Any Video) — App Flow

## Sequence

```mermaid
sequenceDiagram
    participant H as Host
    participant API as Backend
    participant DB as Supabase
    participant LK as Voice DataChannel
    participant V as Viewers

    H->>API: POST /watch-parties {url, channel_id}
    API->>API: detect provider (yt/twitch/vimeo/mp4)
    API->>API: probe metadata (oembed / HEAD)
    API->>DB: insert watch_parties
    API-->>H: party_id, manifest
    H->>LK: publish 'wp-control' join
    V->>API: GET /watch-parties/:id
    V->>LK: subscribe 'wp-control'
    H->>LK: {op: play, t: 0, ts: server_now}
    LK-->>V: same payload
    V->>V: align local clock; play(adjusted_t)
    Note over H,V: every 5s host emits heartbeat with t
    V->>V: drift > 1.5s? hard-seek; <1.5s? gentle rate adjust
    H->>LK: {op: pause, t: 42}
    H->>API: DELETE /watch-parties/:id (or auto on host leave)
```

## State Machine
```
[creating] -> [waiting] -> [playing] <-> [paused]
[playing] -> [seeking] -> [playing]
[any] -> [host_left] -> {auto_promote? promoted; else ended}
[any] -> [provider_error] -> [ended]
```

## Edge Cases
- YT/Twitch geo-block: detect on viewer side, fall back to "host's screen-share" suggestion.
- DRM content (Netflix etc): explicitly unsupported; show "DRM content can't be co-watched."
- Latency drift: server is timer source; clients sync at heartbeat.
- Host leaves mid-party: longest-tenured viewer auto-promoted.
- Mobile background tab: pause locally; resync on resume.
- Provider rate-limit: cache oembed 1h; retry with backoff.
- Adult/NSFW content: provider flag respected; gates if channel not NSFW.

## Background
- pg_cron sweep `wp_sessions WHERE last_seen < now() - interval '10 min'` → mark ended.

## Notifications
- "Alice started a watch party in #lounge — Mr. Robot S1E1"
- Push + in-app, batch 1/channel/15min.
- Deep link: `flicko://channel/<id>/watch-party/<wp_id>`
