# Whiteboard — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User
    participant M as Mobile (WebView)
    participant API as Go Backend
    participant H as Hocuspocus
    participant DB as Postgres
    participant W as SnapshotWorker
    participant R as PNGRenderer

    U->>M: Tap "Whiteboard" in voice channel side rail
    M->>API: GET /whiteboards/:id/handshake
    API->>DB: validate ACL; mint JWT (30min)
    API-->>M: {ws_url, token}
    M->>H: WS connect doc=wb:<id>
    H->>DB: load state
    H-->>M: Yjs sync
    M-->>U: tldraw canvas mounts; cursors visible

    Note over U,DB: Co-drawing
    U->>M: draw shape
    M->>H: y-protocol update
    H->>H: broadcast
    Note over H: every 200 updates / 5m idle
    H->>DB: persist state, rev++

    Note over U,DB: Export PNG
    U->>M: Export
    M->>API: POST /whiteboards/:id/export.png
    API->>R: render(state)
    R-->>API: PNG bytes
    API->>DB: store ref in Appwrite
    API-->>M: {url}
    M-->>U: download / share
```

## 2. State Machine

```
[draft] -- save --> [active]
[active] -- archive --> [archived]
[archived] -- 90d --> [purged]

connection:
  [connecting] -- ok --> [synced]
  [synced] -- drop --> [reconnecting]
  [reconnecting] -- 3 fail --> [offline_readonly]
```

## 3. User Journeys

### J1 — Voice call brainstorm
1. Three teammates on voice call.
2. Host taps Whiteboard side button -> creates "Sprint planning".
3. Cursors appear; sticky notes go up.
4. Call ends; whiteboard survives in channel for follow-up.

### J2 — Async addition
1. Member opens previous whiteboard solo a day later.
2. Adds notes, arrow connecting two clusters.
3. Snapshot worker creates a named rev "after follow-up".

### J3 — Export
1. Mod taps overflow -> Export PNG.
2. Server renders; download starts.

### J4 — First-time empty state
1. Channel has no whiteboard; "+ New whiteboard".

## 4. Edge Cases

- Mobile WebView OOM on huge canvas: warn at 80% of 5 MB cap.
- Permission revoked mid-edit: ACL change pushed via Centrifugo; switch to read-only.
- Voice channel ends: drawer still openable from channel header.
- Stylus tilt unsupported on web -> fall back to pressure curve.

## 5. Background / Async

- Snapshot worker every 5m idle / 200 updates
- PNG render worker (Playwright headless) on demand
- Archive purge daily

## 6. Notifications

| Trigger | Channel | Copy | Deep link | Batching |
|---------|---------|------|-----------|----------|
| Mentioned in sticky note | in-app | "{author} mentioned you in {wb title}" | `flicko://wb/<id>` | once per author per 5m |
| Whiteboard archived | in-app | "{wb title} archived" | channel | once |
| Export ready | toast | "PNG ready" | url | none |

Voice: short.
