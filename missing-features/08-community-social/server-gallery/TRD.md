# Server Gallery — Technical Requirements

## 1. Architecture Overview

```
flicko.messages.created --> NATS --> gallery_worker
                                          |
                                          v
                                   user_galleries
                                          |
                                          v
                                     REST API
                                          |
                                          v
                                  Mobile gallery UI
```

Ingestion is event-driven. Reads are paginated, cache-then-DB. Lightbox uses signed URLs from media service.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/server-gallery/service.go`
- **Worker:** `backend/internal/services/social/server-gallery/ingester.go`
- **Handlers:** `backend/internal/handlers/social/gallery_handler.go`
- **Models:** `backend/internal/models/social/gallery_item.go`
- **Repo:** `backend/internal/repo/social/gallery_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/server-gallery/`
  - `data/`, `domain/`, `application/`, `presentation/`
  - Mosaic via `flutter_staggered_grid_view`; lightbox via `extended_image`

### Infra
- DB: tables in migration 199
- Cache: Redis pages
- Search: Meilisearch over alt_text + author handle (later: OCR)

## 3. API Contracts

### REST
```
GET    /api/v1/servers/:id/gallery?cursor=&limit=60&channel_id=&author_id=&type=&from=&to=&featured=
GET    /api/v1/servers/:id/gallery/:item_id
POST   /api/v1/servers/:id/gallery/:item_id/feature
POST   /api/v1/servers/:id/gallery/:item_id/unfeature
POST   /api/v1/servers/:id/gallery/:item_id/hide
POST   /api/v1/servers/:id/gallery/:item_id/remove
POST   /api/v1/servers/:id/gallery/:item_id/report
PATCH  /api/v1/servers/:id/gallery/settings
```

### WebSocket / Centrifugo
- Channel: `gallery:<server_id>`
- Events: `gallery.item.added`, `gallery.item.featured`, `gallery.item.removed`

### Payloads
```jsonc
{
  "id": "uuid",
  "media_kind": "image",
  "media_url": "https://...",
  "thumb_url": "https://...",
  "width": 1200,
  "height": 800,
  "author_id": "uuid",
  "channel_id": "uuid",
  "posted_at": "iso8601",
  "nsfw": false,
  "featured": false
}
```

## 4. Permissions & Auth

- Read: server members + channel visibility
- Feature/hide/remove: `MANAGE_MESSAGES`
- Settings: `MANAGE_SERVER`
- Author can hide own

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Page p50 | <120 ms |
| Lightbox first frame | <300 ms |
| Throughput | 100 ingest/s peak |

## 6. Dependencies

- Existing media service for signed URLs
- NATS messages firehose

## 7. Observability

- Metrics: `flicko_gallery_items_total`, `flicko_gallery_ingest_seconds`, `flicko_gallery_features_total`
- Logs: structured per ingest
- Traces: OTel
- Dashboards: `social-gallery`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Ingest backlog | stale gallery | autoscale workers; backfill on resume |
| Bad media URL | broken tile | placeholder + retry render |
| NSFW unmarked | unsafe display | blur-by-default + report |
