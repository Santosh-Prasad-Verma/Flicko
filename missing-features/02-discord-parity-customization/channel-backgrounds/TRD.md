# Channel Backgrounds — Technical Requirements

## 1. Architecture Overview

```
                ┌──────────────────────────────────────────┐
                │ Mobile (Flutter)                          │
                │                                           │
                │  ChannelSettings ──► upload picker        │
                │   │                                       │
                │   ▼ multipart                             │
                │  POST /channels/:id/background            │
                │                                           │
                │  ChannelScreen                            │
                │   ├─ ChannelBackgroundLayer (BlurHash →   │
                │   │    mobile variant → dim scrim)        │
                │   └─ MessageList                          │
                └────────────────────────┬─────────────────┘
                                         │ HTTPS
                                         ▼
┌────────────────────────────────────────────────────────────────┐
│ Go backend                                                      │
│                                                                 │
│  channel_background_handler.go                                  │
│        │                                                        │
│        ▼                                                        │
│  channel_background_service.go                                  │
│   ├─ permissions_service (MANAGE_CHANNEL)                       │
│   ├─ image_processor (libvips bindings) ─► variants             │
│   ├─ safe_browsing_service.HashCheck                            │
│   ├─ blurhash.Encode (woltapp/blurhash)                         │
│   └─ appwrite_client.UploadFile (×4)                            │
│        │                                                        │
│        ▼                                                        │
│  Postgres channel_backgrounds + channels.background_id          │
│        │                                                        │
│        └──► Centrifugo publish "channel:{id}" event             │
└────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │ Appwrite bucket     │
                              │ channel-backgrounds │
                              └─────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/channel_background_service.go`
  - `Upload(ctx, channelID, userID, multipart) (*ChannelBackground, error)`
  - `Delete(ctx, channelID, userID) error`
  - `Get(ctx, channelID) (*ChannelBackground, error)`
- **Handler:** `backend/internal/handlers/channel_background_handler.go`
- **Model:** `backend/internal/models/channel_background.go`
- **Worker:** `backend/internal/services/channel_background/variant_worker.go` (async — derives `mobile` and `blurred` from `original` after upload).
- **Repo:** `backend/internal/repo/channel_background_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/channel_backgrounds/`
  - `data/` repository, dto, datasource (multipart upload).
  - `domain/` entities (`ChannelBackground`, `BackgroundOpacity`).
  - `application/` providers (`channelBackgroundProvider(channelId)`, `backgroundOpacityProvider`).
  - `presentation/` `BackgroundUploadSheet`, `BackgroundOpacityTile`, `ChannelBackgroundLayer` widget.

### Infra
- DB: `channel_backgrounds` table (see `SCHEMA.md`).
- Realtime: Centrifugo `channel:{channelID}` publishes `channel.background.updated` / `channel.background.deleted`.
- Cache: Redis `channel:bg:{channelID}` (5m TTL).
- Storage: Appwrite bucket `channel-backgrounds` — 4 files per row (`original`, `mobile`, `blurred`, BlurHash is a string in DB).
- Processing: libvips via `github.com/davidbyttow/govips/v2` for fast variant generation.
- Queue: NATS subject `flicko.channel_background.process` for async variant work.

## 3. API Contracts

### REST

```
POST   /api/v1/channels/:id/background     multipart upload (admin)
GET    /api/v1/channels/:id/background     read
DELETE /api/v1/channels/:id/background     remove (admin)
PATCH  /api/v1/users/me/settings           opacity (existing)
```

### WebSocket / Centrifugo
- Channel: `channel:{channelID}` (existing)
- Events:
  - `channel.background.updated` `{ channel_id, original_url, mobile_url, blurred_url, blurhash, dominant_color, set_at }`
  - `channel.background.deleted` `{ channel_id }`

### Payloads

```jsonc
// POST request — multipart fields
//   file: <binary, max 8MB, image/jpeg|image/png|image/webp>
//   focal_x: 0.5      // 0..1, where to crop from
//   focal_y: 0.5
//   tags:   ["aesthetic","retro"]   // optional, mod-only

// POST 202 (variants generating)
{
  "channel_id": "0c2a...",
  "original_url": "https://appwrite.flicko.dev/.../original.jpg",
  "blurhash":     "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
  "dominant_color": "#3A2D58",
  "status": "processing"
}

// GET 200 (after variants done)
{
  "channel_id": "0c2a...",
  "original_url": "...",
  "mobile_url":   "...",
  "blurred_url":  "...",
  "blurhash":     "...",
  "dominant_color": "#3A2D58",
  "uploader_id": "9f...",
  "status": "ready",
  "set_at":  "2026-05-29T11:00:00Z"
}

// 403 Permission
{ "error": "missing_permission", "required": "MANAGE_CHANNEL" }

// 413 Too Large
{ "error": "file_too_large", "max_bytes": 8388608 }

// 422 Moderation
{ "error": "image_blocked", "reason": "matched_banned_hash" }
```

## 4. Permissions & Auth

- Required scope: `channels.background.write` for upload/delete; member of channel for read.
- Role checks: `MANAGE_CHANNEL` permission bit OR server owner.
- RLS policies in `SCHEMA.md`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency POST (sync part) | <400 ms |
| p99 latency POST | <1.2 s |
| Variant generation (worker) | <5 s p95 |
| GET p50 | <50 ms (Redis hit) |
| Throughput POST | 5 rps cluster (rare action) |
| Availability | 99.9% |
| Storage cost | <$0.0002 per channel/month at 4 variants × ~250KB |
| Egress cost | <$0.005/server/month at 100k members loading mobile variant once/day |
| GDPR | image deleted within 24h of channel deletion via cascade + worker |

## 6. Dependencies

- `github.com/davidbyttow/govips/v2 v2.13.0` (image processing, libvips wrapper).
- `github.com/buckket/go-blurhash` (BlurHash encoding).
- Existing: `appwrite_client`, `centrifugo_client`, `safe_browsing_service`, `permissions_service`.
- libvips system package (already on Railway image for avatar processing).

## 7. Observability

- Metrics:
  - `flicko_channel_bg_uploads_total{result="ok|moderated|too_big|invalid"}`
  - `flicko_channel_bg_variant_duration_seconds` (histogram)
  - `flicko_channel_bg_storage_bytes` (gauge)
  - `flicko_channel_bg_egress_bytes_total{variant}`
- Logs: structured `{event, channel_id, server_id, user_id, file_size, variant}`. Errors → Sentry tagged `feature: channel_backgrounds`.
- Traces: OTel spans `bg.upload`, `bg.variants`, `bg.moderate`.
- Dashboards: Grafana `Channel Backgrounds` board (uploads, variant latency, storage, top servers).

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| libvips OOM on huge image | upload fails | pre-flight dimension check; reject >4096 px before decode |
| Appwrite storage full | uploads start failing | alarm at 70% capacity; provision next bucket |
| Variant worker stuck | members see only `original` (heavy) | retry 3× then mark `status=failed`; client falls back to BlurHash |
| Banned-hash false positive | legit image rejected | mod can appeal via `/api/v1/moderation/appeal`; manual override |
| Mobile data-saver client | doesn't want background | client honors `Save-Data` and shows BlurHash only |
| Channel deleted with active background | orphaned blobs | cascade trigger enqueues delete-by-file-id NATS message |

## 9. Image Processing Pipeline (server-side)

1. Validate MIME, magic bytes, size.
2. Decode with libvips, check dimensions.
3. Compute SHA256, check against `safe_browsing_hashes` table.
4. Upload `original` to Appwrite (sync).
5. Compute BlurHash (~10 ms).
6. Compute `dominant_color` via 16-color quantize, pick highest-saturation top-3.
7. Insert/update DB row with `status=processing`.
8. Publish NATS `flicko.channel_background.process` with file_id.
9. Worker: generate `mobile` (max 1280 dimension, q=78) + `blurred` (kawase, σ=8, downscaled 4×). Upload. Update row to `status=ready`.
10. Publish Centrifugo event.
