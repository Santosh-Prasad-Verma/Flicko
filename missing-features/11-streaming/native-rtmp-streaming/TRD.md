# Native RTMP Streaming — Technical Requirements

## 1. Architecture Overview

```
                    ┌────────────┐
   OBS / PS5 / SRT  │            │   ingress.create()
 ──────────────────▶│  Azure ACS   │◀──────────────────┐
   rtmp://ingest/   │  Ingress   │                   │
                    │            │                   │
                    └─────┬──────┘                   │
                          │ track published          │
                          ▼                          │
                  ┌──────────────┐                   │
                  │  Azure ACS SFU │                   │
                  └───┬───────┬──┘                   │
        WebRTC (low)  │       │  ABR Egress (HLS)    │
                      ▼       ▼                      │
              Mobile App   HLS CDN (Bunny)           │
                      ▲                              │
                      │                              │
                      ▼                              │
                  Centrifugo  ◀───── Go Backend ─────┘
                stream-chat:<id>     stream_service.go
                stream:<id>          (extends existing)
```

Two playback paths — SFU for in-app low-latency, HLS for embeds, browsers without WebRTC, and bandwidth fallback. The same source stream feeds both; Azure Media Egress takes care of the ABR ladder and writes segments to Bunny CDN backed by R2.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/streaming/native_rtmp/service.go` — extends `stream_service.go` with `CreateIngress`, `RotateKey`, `Revoke`.
- **Worker:** `backend/internal/services/streaming/native_rtmp/health_worker.go` — polls Azure Media Ingress every 15 s, reconciles `streams.state`.
- **Handler:** `backend/internal/handlers/streaming/native_rtmp_handler.go`.
- **Models:** `backend/internal/models/stream.go` (shared with `vod-storage`).
- **Webhook:** `backend/internal/handlers/streaming/azure_acs_webhook.go` — receives `ingress_started`, `ingress_ended`, `track_published`.
- **Repo:** `backend/internal/repo/stream_repo.go`.

### Mobile (Flutter)
- `mobile/lib/features/streaming/native_rtmp/`
  - `data/`: `stream_dto.dart`, `stream_repository.dart`, `azure_acs_remote_datasource.dart`.
  - `domain/`: `stream.dart`, `usecases/start_stream.dart`, `usecases/get_stream_key.dart`.
  - `application/`: `stream_provider.dart`, `viewer_provider.dart`, `key_provider.dart`.
  - `presentation/`: `stream_setup_sheet.dart`, `stream_view_screen.dart`, `live_indicator.dart`.

### Infra
- DB: Supabase Postgres tables `streams`, `stream_keys` (see `SCHEMA.md`).
- Realtime: Centrifugo channel `stream:<stream-id>` (state, viewers, donation overlays).
- Cache: Redis keys `stream:active:<channel-id>` TTL 60 s.
- Storage: nothing in v1; `vod-storage` handles segment retention.
- Search: not indexed (live data, ephemeral).
- AI: none for v1 (transcription is opt-in via `ai-voice-transcription` overlay).
- Queue: NATS subjects `flicko.stream.events.started`, `flicko.stream.events.ended`.

## 3. API Contracts

### REST

```
POST   /api/v1/channels/:cid/streams/key           returns ingress URL + key (one-time)
POST   /api/v1/channels/:cid/streams/key/rotate    rotate; invalidates old key
DELETE /api/v1/streams/:sid                        revoke + force disconnect
GET    /api/v1/streams/:sid                        public live state + viewers
GET    /api/v1/streams/:sid/playback               returns SFU token + signed HLS URL
GET    /api/v1/channels/:cid/streams/active        most recent active stream
```

### Centrifugo

- Channel: `stream:<stream-id>`
- Events:
  - `stream.started` `{stream_id, started_at, ingest_protocol}`
  - `stream.ended`
  - `stream.viewers` `{count}` published every 5 s
  - `stream.bitrate` `{kbps}` for the stream owner only
  - `stream.title_changed`

### Sample payloads

```jsonc
// POST /channels/:cid/streams/key  (response, one-time reveal)
{
  "stream_id": "5b4e...",
  "ingest_url": "rtmps://ingest-eu1.flicko.app/live",
  "stream_key": "fk_live_J5x2-...-9aQ",
  "key_prefix": "fk_live_J5x2",
  "expires_at": "2026-09-30T00:00:00Z"
}
```

```jsonc
// GET /streams/:sid/playback
{
  "sfu": {
    "url": "wss://sfu.flicko.app",
    "token": "eyJ..."
  },
  "hls": {
    "url": "https://hls.flicko.app/s/5b4e.m3u8?Policy=...&Signature=...",
    "ll": true
  },
  "abr": [
    { "name": "1080p60", "bitrate_kbps": 6000 },
    { "name": "720p60",  "bitrate_kbps": 3500 },
    { "name": "480p30",  "bitrate_kbps": 1500 },
    { "name": "audio",   "bitrate_kbps": 96  }
  ]
}
```

## 4. Permissions & Auth

- `stream.publish` (server scope) — granted to roles flagged `can_stream`.
- `stream.view` — derived from channel visibility.
- `stream.moderate` — server admins; required for `DELETE /streams/:sid` and `rotate`.
- Stream key never leaves the database in plaintext after the first reveal — argon2id hash, 16-byte salt.
- Ingress signed JWT scoped to `room=<channel-id>`, `participant=<stream-id>`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Ingress publish-to-SFU latency | <250 ms p50 |
| Glass-to-glass SFU | <800 ms p50 |
| Glass-to-glass LL-HLS | <2.5 s p50 |
| Ingest start success rate | ≥99.5% per region |
| Concurrent streams per server (free tier) | 3 |
| Concurrent viewers per stream (free tier) | 500 |
| Storage cost per stream-hour | $0 (no VOD) |
| Compute cost per viewer-hour | <$0.0009 (Bunny + Azure ACS) |
| GDPR | EU streamers routed to Azure ACS Cloud `eu-west` |

## 6. Dependencies

- Azure ACS Cloud — Ingress + Egress + SFU (existing contract).
- Bunny CDN — HLS edge (existing contract, $0.01/GB).
- Cloudflare R2 — origin store for HLS segments (existing).
- `azure_acs-sdk-go v2.6.0`, `azure_acs-server-sdk` for ingress.
- Mobile: `azure_communication_calling: ^2.4.5`, `better_player: ^0.0.84`.

## 7. Observability

- Metrics:
  - `flicko_stream_ingress_started_total{protocol}`
  - `flicko_stream_publish_duration_seconds`
  - `flicko_stream_viewers` (gauge per stream-id, sampled 5 s)
  - `flicko_stream_egress_bandwidth_bytes`
- Logs: structured; PII-stripped; level `INFO` for state changes, `WARN` for retries, `ERROR` to Sentry.
- Traces: OTel spans wrap `CreateIngress`, `RotateKey`, every webhook.
- Dashboard: Grafana board `streaming/native-rtmp` with ingress success, viewer count, bitrate p50/p99.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Azure Media Ingress region down | streamers in region cannot publish | DNS fail-over to nearest region; UI shows banner |
| HLS CDN slow | viewers stutter | client falls back to SFU automatically |
| Stream-key leak | unauthorized publish | one-publisher-per-key check; auto-revoke on duplicate |
| Webhook lost | stale `streams.state=live` | health worker reconciles every 15 s |
| Bandwidth abuse | runaway egress cost | per-server quota + Prometheus alert at 80% |
| Encoder reconnect storm | thundering herd | Ingress side handles backoff; we cap retries at 5 in 60 s |
