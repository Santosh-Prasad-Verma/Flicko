# Game Clip Sharing — APPFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant Cl as Client (desktop ring / mobile rec)
    participant API as Backend
    participant N as NATS
    participant W as ffmpeg worker
    participant S as Storage

    U->>Cl: hotkey "clip last 60s"
    Cl->>Cl: write ring buffer to file
    Cl->>API: POST /clips (multipart)
    API->>S: store original
    API->>N: publish flicko.clips.transcode
    API-->>Cl: 202 {id, status:'queued'}
    W->>S: fetch original
    W->>W: ffmpeg keyframe-align trim → HLS
    W->>W: pick peak-audio frame as thumbnail
    W->>S: write HLS + thumb
    W->>API: PATCH /clips/:id status=ready
    API->>Centrifugo: channel:<chan> {clip_ready}
    Cl->>U: open Trim & Post sheet
    U->>API: PATCH /clips/:id {trim_in, trim_out, caption}
    API->>N: re-trim publish if delta>2s
    API->>API: post message in channel referencing clip
```

## State Machine
```
[capturing] → [uploaded] → [transcoding] → [ready] → [posted]
[any] → [blocked] (DMCA / NSFW)
[any] → [removed] (mod / author)
```

## Edge Cases
- No game detected: still allow, mark "Unknown".
- Mobile foreground app blocks recording: show fallback "Record screen via system → save to Flicko".
- Upload disconnect: Hive draft + tus-resumable.
- DMCA hit on audio fingerprint: block + author email.

## Background
- Cold-archive sweeper daily.
- Peak-audio thumb extracted async if first pass fails (silence).

## Notifications
- "alice clipped a play in #clips" → channel notification (not push by default).
