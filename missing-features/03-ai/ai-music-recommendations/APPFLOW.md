# AI Music Recommendations — APPFLOW

```mermaid
sequenceDiagram
    participant H as Host
    participant API as Backend
    participant V as Vector Service
    participant LLM as Groq
    participant SP as Spotify
    participant Q as Queue

    Note over Q: queue dips to 2
    Q-->>API: queue_low event
    API->>V: build room_vector(participants, last 25 tracks)
    API->>SP: get audio_features for last 25
    API->>LLM: pick(N=5, room_vec, recent_tracks)
    LLM-->>API: [{uri, rationale}]
    API->>SP: validate uris exist + region
    API->>Q: enqueue valid tracks
    Note over H: optional vibe prompt
    H->>API: POST /music-party/:id/vibe {prompt: "more chill"}
    API->>LLM: pick with vibe modifier
    LLM-->>API: [...]
    API->>Q: prepend
```

## State Machine
```
auto_queue: [off] ⇄ [on]
host can pin/unpin a vibe; AI picks bias toward pinned vibe
```

## Edge Cases
- All participants have empty taste vectors: fall back to genre seed from server tags.
- LLM returns inaccessible track for region: skip and retry.
- DMCA warning from Spotify: skip + log.
- Same track repeated: dedupe across last 50.

## Background
- Listening event ingest writes taste vectors hourly.
- Personal digest cron weekly Sunday 09:00 user-local.

## Notifications
- "Your weekly Flicko mix is ready" push.
