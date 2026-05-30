# Short Videos — APPFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile
    participant API as Backend
    participant N as NATS
    participant W as ffmpeg/Whisper Worker
    participant S as Storage (Appwrite/R2)
    participant Q as Qdrant

    U->>M: record 60s vertical
    M->>API: POST /shorts (multipart)
    API->>S: store original
    API->>N: publish flicko.shorts.transcode {id}
    API-->>M: 202 {id, status:'queued'}
    W->>S: fetch original
    W->>W: ffmpeg → HLS variants (240p/480p/720p)
    W->>S: write HLS
    W->>N: publish flicko.shorts.caption {id}
    W->>W: Whisper STT
    W->>S: write captions.vtt
    W->>API: PATCH /shorts/:id status=ready, embedding
    API->>Q: upsert embedding
    API->>API: rank refresh (next batch tick)
    API->>Centrifugo: feed:<follower> {new short}
    M->>API: GET /shorts/feed
    API-->>M: cursor list
    loop scroll
      M->>API: POST /shorts/:id/engage {kind: view, watch_ms}
    end
```

## State Machine
```
[uploaded] → [transcoding] → [captioning] → [ranking] → [ready]
[any]      → [blocked]   (NSFW or DMCA fingerprint match)
[any]      → [removed]   (mod or author)
```

## Edge Cases
- Upload too long: client trims to 60s; reject server-side if >65s.
- Network drop mid-upload: tus-style resumable.
- Battery dies during recording: drafts in Hive every 2s.
- DMCA hit: status → blocked; author notified with reason.
- Repost detection: audio fingerprint match → flag in mod queue.
- Watching without account: limited public feed only.

## Background
- Ranker: every 5 min recomputes top-N per cohort.
- Cold-archive sweeper: daily moves 30d+ to R2.
- Engagement aggregator: rollup `view_count`, `like_count` from engagements every 60s.

## Notifications
- "@alice posted a new short: 'sunday vibes'" (followers, batched 1/15min/poster).
- Deep link `flicko://shorts/<id>`.
- Admins of server: "New short pending review" if mod-queue mode.
