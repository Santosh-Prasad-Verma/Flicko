# Whiteboard — Technical Requirements

## 1. Architecture Overview

```
   ┌──────────────────────────────────────────────┐
   │  Mobile (Flutter) / Web                       │
   │   WhiteboardScreen                            │
   │   webview_flutter -> tldraw bundle (CDN)      │
   │   tldraw <-> Yjs <-> WebSocket                │
   └──────────┬───────────────────────────────────┘
              │ REST handshake / WS sync
              ▼
   ┌──────────────────────────────────────────────┐
   │  Go Backend                                   │
   │   whiteboard_service.go (CRUD/ACL)            │
   │   handshake JWT mint/verify                   │
   └──────────┬───────────────────────────────────┘
              │ persist_webhook
              ▼
   ┌──────────────────────────────────────────────┐
   │  Hocuspocus (whiteboard mode)                 │
   │   namespace: wb:<id>                          │
   │   binary Yjs state                            │
   └──────────┬───────────────────────────────────┘
              ▼
   ┌──────────────────────────────────────────────┐
   │  Postgres whiteboards + revisions + acls      │
   └──────────────────────────────────────────────┘
```

Reuses Hocuspocus from collaborative-docs (different doc namespace `wb:`).
Tldraw embedded in WebView; canvas = Yjs binary doc.

## 2. Components

### Backend (Go)
- `services/productivity/whiteboard/service.go`
- `services/productivity/whiteboard/handshake.go`
- `services/productivity/whiteboard/snapshot_worker.go`
- `services/productivity/whiteboard/png_export.go`
- `handlers/whiteboard/{handler,acl_handler}.go`
- `models/whiteboard.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/whiteboard/`
  - WebView shell loading `https://cdn.flicko.io/tldraw/v1/index.html`
  - Native gestures forwarded via JS bridge
  - Voice channel embed: opens drawer beside voice grid

### Web bundle
- `tools/tldraw-bundle/` Vite-built tldraw + Yjs adapter
- CDN-served with SRI

### Infra
- DB: Postgres, migration 168
- Realtime: Hocuspocus with `wb:` doc namespace
- Storage: Appwrite bucket `whiteboard-exports` (PNG snapshots)
- Cron: snapshot worker every 5 min idle / 200 updates

## 3. API Contracts

### REST
```
POST   /api/v1/whiteboards                   create
GET    /api/v1/whiteboards?channel=
GET    /api/v1/whiteboards/:id
PATCH  /api/v1/whiteboards/:id               rename, archive
DELETE /api/v1/whiteboards/:id
POST   /api/v1/whiteboards/:id/handshake     -> {ws_url, token}
POST   /api/v1/whiteboards/:id/snapshots
GET    /api/v1/whiteboards/:id/snapshots
POST   /api/v1/whiteboards/:id/export.png    server-side render
POST   /api/v1/whiteboards/:id/acl           grant
DELETE /api/v1/whiteboards/:id/acl/:uid
```

### WebSocket
- `wss://hocus.flicko/wb/<id>?token=<jwt>`

### Payloads
```jsonc
// Create
{ "server_id":"uuid", "channel_id":"uuid", "voice_channel_id":"uuid|null", "title":"Brainstorm" }
// Response
{ "id":"uuid", "ws_url":"...", "token":"...", "rev": 0 }
```

## 4. Permissions & Auth

- Tier `editor`/`viewer`
- Voice-attached whiteboards inherit voice channel membership
- Handshake JWT 30 min, refresh transparently

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| WS handshake p99 | <250 ms |
| Update propagation p99 | <300 ms |
| Concurrent editors | 25 |
| Canvas size cap | 5 MB Yjs state |
| PNG export p99 | <3s |

## 6. Dependencies

- Tldraw 2.x (MIT) + Yjs 13.x
- `webview_flutter`, `webview_flutter_android`, `webview_flutter_wkwebview`
- Existing Hocuspocus container (shared with docs)
- Headless renderer for PNG: Playwright-Chromium worker `tools/wb-render/`

## 7. Observability

- `flicko_wb_active_connections` gauge
- `flicko_wb_update_bytes_total`
- `flicko_wb_snapshot_total{trigger}`
- `flicko_wb_export_seconds` histogram

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| WebView load failure | blank canvas | retry + offline copy of last PNG |
| State blob too large | sync slow | hard cap 5 MB; UI nudges to "snapshot and start fresh" |
| Hocuspocus crash | disconnect | auto reconnect; last snapshot replayed |
| Voice channel ends | whiteboard stays | becomes channel-wide; banner explains |
| Export render OOM | export fails | tile-by-tile render fallback |
| Token replay | unauthorized | one-time-use JTI cache |
