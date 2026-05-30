# Channel Notes — Technical Requirements

## 1. Architecture Overview

```
   ┌─────────────────────────────────────────┐
   │ Mobile (Flutter) WebView                │
   │  Tiptap-lite + Yjs + y-websocket        │
   └────────────┬────────────────────────────┘
                │ REST handshake / WS sync
                ▼
   ┌─────────────────────────────────────────┐
   │ Go Backend (reuses docs infra)          │
   │  channel_notes_service.go               │
   │  handshake JWT (channel-write check)    │
   └────────────┬────────────────────────────┘
                │
                ▼
   ┌─────────────────────────────────────────┐
   │ Hocuspocus  doc namespace cn:<id>       │
   └────────────┬────────────────────────────┘
                ▼
   ┌─────────────────────────────────────────┐
   │ Postgres channel_notes                  │
   └─────────────────────────────────────────┘
```

Reuses Hocuspocus and the same JS bundle as collaborative-docs (lite mode).
Single doc per channel; auto-created lazily.

## 2. Components

### Backend (Go)
- `services/productivity/channel_notes/service.go`
- `services/productivity/channel_notes/handshake.go`
- `handlers/channel_notes/handler.go`
- `models/channel_note.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/channel_notes/`
  - `data/`, `domain/`, `application/`
  - `presentation/screens/note_screen.dart`
  - WebView host using same shared editor frame

### Infra
- DB: Postgres, migration 170
- Realtime: Hocuspocus namespace `cn:<channel_id>`

## 3. API Contracts

### REST
```
GET    /api/v1/channels/:cid/note                 read meta + render
POST   /api/v1/channels/:cid/note/handshake       returns ws_url, token
POST   /api/v1/channels/:cid/note/clear           mod-only soft clear
```

### Payloads
```jsonc
{ "id":"uuid","markdown_export":"...","updated_at":"...","updated_by":"uuid","rev":3 }
```

## 4. Permissions & Auth

- Read: channel members
- Write: channel write permission
- Clear: channel mods/admins
- RLS in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Handshake p99 | <250 ms |
| Update propagation p99 | <300 ms |
| Note size cap | 64 KB markdown |
| Concurrent editors | 10 |

## 6. Dependencies

- Existing Hocuspocus container
- Existing Tiptap bundle (lite mode)
- channel-permissions service

## 7. Observability

- `flicko_channel_notes_active` gauge
- `flicko_channel_notes_edit_total{channel}`
- `flicko_channel_notes_size_bytes` histogram

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Hocuspocus disconnect | sync paused | reconnect + replay |
| Bloat past 64 KB | sync slow | nudge "consider a Doc" |
| Permission revoked | edit denied | server-side rejection + UI banner |
| Cross-device race | last-write merge via CRDT | Yjs handles |
