# Collaborative Docs — Technical Requirements

## 1. Architecture Overview

```
        ┌────────────────────────────────────────────────────────────┐
        │  Mobile (Flutter)                                          │
        │   DocEditorScreen  -- Tiptap WebView (Yjs aware) --        │
        │   DocListScreen                                            │
        └─────────────┬─────────────────────────┬────────────────────┘
                      │ REST (CRUD, ACL)         │ WebSocket (Yjs binary)
                      ▼                          ▼
        ┌──────────────────────┐  ┌──────────────────────────────┐
        │ Go Backend           │  │ Hocuspocus container          │
        │ doc_handler.go       │  │ wss://hocus.flicko/doc/<id>   │
        │ doc_service.go       │◀─┤ persistence -> Postgres       │
        │ doc_acl.go           │  │ presence -> Redis             │
        └─────────┬────────────┘  └──────────────┬───────────────┘
                  │ Postgres                       │
                  ▼                                ▼
        ┌──────────────────────────────────────────────────────────┐
        │ Postgres: docs  doc_revisions  doc_acls  doc_comments    │
        └──────────────────────────────────────────────────────────┘
                  │
                  ▼
        ┌──────────────────────┐
        │ Snapshot Worker      │  every 5 min idle / 200 updates
        └──────────────────────┘
```

## 2. Components

### Backend (Go)
- `backend/internal/services/productivity/docs/service.go`
- `backend/internal/services/productivity/docs/acl.go`
- `backend/internal/services/productivity/docs/snapshot_worker.go`
- `backend/internal/handlers/docs/doc_handler.go`
- `backend/internal/handlers/docs/comment_handler.go`
- `backend/internal/models/doc.go`

### Hocuspocus Server
- New container in `docker-compose.yml` service `hocuspocus`
- Image: `ghcr.io/ueberdosis/hocuspocus:latest`
- Persistence extension hits Go backend `/internal/docs/:id/persist` for write
  through; Postgres holds binary state in `docs.yjs_state` (bytea)
- Auth extension validates JWT issued by Flicko backend at handshake

### Mobile (Flutter)
- `mobile/lib/features/productivity/collab_docs/`
  - `data/`: `doc_dto.dart`, `doc_repository.dart`, `doc_remote_ds.dart`
  - `domain/`: `doc.dart`, `doc_revision.dart`, `doc_comment.dart`
  - `application/`: `doc_provider.dart`, `doc_list_provider.dart`
  - `presentation/screens/`: `doc_list_screen.dart`, `doc_editor_screen.dart`
  - `presentation/widgets/`: `presence_avatars.dart`, `comment_thread.dart`
- Editor uses `webview_flutter` loading Tiptap+Yjs bundle from CDN
  `https://cdn.flicko.io/editor/v1/index.html`

### Infra
- DB: Supabase Postgres, migration 162
- Realtime: Hocuspocus `doc:<doc_id>` (binary Yjs); Centrifugo for presence
  fallbacks `docs:server:<sid>` -> `doc.created`, `doc.archived`
- Cache: Redis `docs:presence:<doc_id>` with TTL 30s
- Storage: Appwrite bucket `doc-images`, max 8 MB
- Snapshot worker: cron every 5 min, also triggered after 200 updates

## 3. API Contracts

### REST
```
POST   /api/v1/docs                                create
GET    /api/v1/docs?server=&channel=               list
GET    /api/v1/docs/:id                            metadata + ACL
PATCH  /api/v1/docs/:id                            rename, archive
DELETE /api/v1/docs/:id                            soft-archive
POST   /api/v1/docs/:id/snapshots                  manual snapshot
GET    /api/v1/docs/:id/snapshots                  list versions
GET    /api/v1/docs/:id/snapshots/:rev             read content (markdown export)
POST   /api/v1/docs/:id/snapshots/:rev/restore     create new snapshot from old
POST   /api/v1/docs/:id/comments                   create comment thread
GET    /api/v1/docs/:id/comments
POST   /api/v1/docs/:id/acl                        grant role to user
DELETE /api/v1/docs/:id/acl/:uid
GET    /api/v1/docs/:id/handshake                  exchanges JWT for Hocuspocus
```

### WebSocket (Hocuspocus)
- URL: `wss://hocus.flicko/doc/<doc_id>?token=<jwt>`
- Protocol: y-protocols sync + awareness
- Server-side handlers: `onAuthenticate`, `onLoadDocument`, `onStoreDocument`

### Payloads
```jsonc
// Create
{
  "server_id": "uuid",
  "channel_id": "uuid",
  "title": "Onboarding Playbook",
  "template": "blank|meeting_notes|playbook"
}
// Response
{
  "id": "uuid",
  "ws_url": "wss://hocus.flicko/doc/<id>",
  "token": "<jwt>",
  "rev": 0
}
```

## 4. Permissions & Auth

- Scopes: `docs.read`, `docs.write`, `docs.manage`
- Tiers: `owner` (any operation), `editor` (read/write), `commenter` (read + comment), `viewer` (read)
- Defaults: channel members get tier from `docs.default_tier` on create (admin sets)
- JWT for Hocuspocus carries `{doc_id, user_id, tier}`; expires 30 min; refresh via `/handshake`
- RLS in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| WS handshake p99 | <250 ms |
| Update propagation p99 | <300 ms |
| Concurrent editors per doc | 25 |
| Doc size | <2 MB rendered markdown |
| Availability | 99.5% (Hocuspocus single host in v1) |
| Storage cost | <$0.002/doc/month |

## 6. Dependencies

- New service: Hocuspocus container
- Go libs: `github.com/golang-jwt/jwt/v5`, existing Postgres driver
- Mobile: `webview_flutter: ^4.7.0`, `webview_flutter_android`, `webview_flutter_wkwebview`
- CDN bundle: Tiptap 2.x + Yjs 13.x + y-websocket 1.5

## 7. Observability

- Metrics:
  - `flicko_docs_active_connections` gauge
  - `flicko_docs_update_bytes_total` counter
  - `flicko_docs_snapshot_total{trigger}` counter (idle|threshold|manual)
  - `flicko_docs_persist_seconds` histogram
- Logs: Hocuspocus stdout collected by Loki; Go backend logs auth failures
- Traces: OTel on `service.CreateDoc`, `worker.snapshot`
- Dashboard: Grafana board `docs`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Hocuspocus crash | All editors disconnect | Auto-restart by Docker; client reconnects with backoff; last snapshot preserved |
| Postgres write lag | Snapshots stale | Snapshot worker uses `FOR UPDATE SKIP LOCKED`; batch flushes |
| Conflict on restore | Concurrent restore wars | Restore creates new snapshot, never overwrites |
| Image upload too big | OOM | Pre-signed Appwrite URL; client uploads directly; backend records ref only |
| WebView load fail | Editor blank | Fallback message + retry; offline copy of last snapshot in markdown |
| JWT expired mid-edit | Disconnect | Client refreshes 5 min before expiry; reconnect transparently |
| ACL change kicks editor | Confusion | Client polls ACL every 60s; server pushes `acl.changed` via Centrifugo |
