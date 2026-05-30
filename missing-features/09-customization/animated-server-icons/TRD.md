# Animated Server Icons — Technical Requirements

## 1. Architecture Overview

```
            +------------------------------+
            | Server Appearance settings   |
            | (mobile)                     |
            +--------------+---------------+
                           | upload
                           v
+--------------------------+----------------------+
| server_icons_handler.go                         |
|  POST /servers/:sid/icon/animated               |
+----+--------------------+-----------------------+
     |                    |
     v                    v
+----+----+         +-----+--------+
| GIF     |         | Lottie       |
| process |         | validator    |
+----+----+         +-----+--------+
     |                    |
     +----------+---------+
                v
        +-------+--------+
        | Appwrite       |
        | bucket icons/  |
        +-------+--------+
                |
                v
     +----------+----------+
     | static fallback     |
     | worker (frame 0)    |
     +----------+----------+
                |
                v
        Centrifugo publish
        server:<sid>:icon.updated
```

## 2. Components

### Backend (Go)
- **Service:** `internal/services/icons/service.go`
- **GIF processor:** `internal/services/icons/gif_processor.go`
- **Lottie validator:** `internal/services/icons/lottie_validator.go`
- **Photosensitive analyzer:** `internal/services/icons/photosensitive.go`
- **Worker:** `internal/jobs/icon_static_fallback.go`
- **Handlers:** `internal/handlers/server_icons_handler.go`
- **Model:** `internal/models/server_icon.go`

### Mobile (Flutter)
- **Provider:** `mobile/lib/features/server_settings/application/animated_icon_provider.dart`
- **Widget:** `mobile/lib/features/shared/presentation/widgets/animated_server_icon.dart`
- **Cache:** `flutter_cache_manager` keyed by url + etag. For Lottie JSON, decode once and reuse `LottieComposition`.

### Infra
- DB: `server_animated_icons`.
- Storage: Appwrite bucket `server_icons` (max 512KB).
- Cache: Redis `icon:server:<sid>` TTL 30m.
- Realtime: Centrifugo channel `server:<sid>`.

## 3. API Contracts

### REST
```
POST   /api/v1/servers/:sid/icon/animated      multipart upload
DELETE /api/v1/servers/:sid/icon/animated      revert to static
GET    /api/v1/servers/:sid/icon/animated      metadata
```

### Payloads
```jsonc
// POST response
{
  "server_id": "uuid",
  "format": "lottie",
  "url": "https://cdn.flicko.app/icons/<sid>.json",
  "static_url": "https://cdn.flicko.app/icons/<sid>.webp",
  "fps": 30,
  "duration_ms": 1800,
  "size_bytes": 84392,
  "photosensitive_warning": false
}
```

### Realtime
- Channel `server:<sid>` event `icon.updated` `{format, url, static_url}`.

## 4. Permissions & Auth

- Required: server owner or `manage_server` permission.
- Read: any member.
- Photosensitive override: `flicko_admin` only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Upload p99 latency | <2.5s |
| Sidebar animate frame budget | <16ms |
| Static fallback derivation | <1.5s p95 |
| Storage per server | ≤512KB animated + ≤32KB static |
| Cost per server/month | <$0.001 |

## 6. Dependencies

- Existing services: server membership, Appwrite, audit log.
- New libraries:
  - Go: `golang.org/x/image/draw`, `image/gif`.
  - Flutter: `lottie: ^3.1.2`, `visibility_detector: ^0.4.0+2`.

## 7. Observability

- Metrics: `flicko_animated_icon_upload_total`, `..._upload_reject_total{reason=...}`, `..._render_pause_total{reason=...}`.
- Logs: `server_id`, `format`, `size_bytes`.
- Traces: `icons.validate`, `icons.upload`, `icons.fallback`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Lottie parser OOM | server crash | sandbox parse with mem cap |
| GIF resize huge | latency spike | strict pre-check size + frame count |
| CDN miss | sidebar shows static | always serve static_url alongside |
| Appwrite rate limit | uploads queue | backoff + retry up to 3× |
