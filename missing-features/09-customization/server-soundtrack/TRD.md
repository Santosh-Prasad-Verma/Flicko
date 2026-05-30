# TRD - Server Soundtrack

Feature: Server-wide background ambience music. A single curated royalty-free track loops at low volume (default -22 LUFS, ducked under voice) for every member of a server. Admins pick the track per server from a curated library. Members can mute or override locally.

## 1. Goals & Non-Goals

Goals:
- Per-server ambient audio that loops indefinitely without operator intervention.
- Curated, license-clean track library (CC0 / royalty-free) managed by platform admins.
- Per-member mute that survives across sessions and devices.
- Negligible impact on voice channel intelligibility (LiveKit ducking).

Non-Goals:
- User-uploaded tracks (out of scope; covered by separate "custom audio" feature).
- DRM playback or paid music catalogs.
- Synchronized cross-member playback (each client loops independently).

## 2. Architecture

```
+--------------+    REST     +-------------------+    pgx     +-------------+
|  Mobile App  | <---------> |  Go API Gateway   | <--------> |  Supabase   |
|  (Flutter)   |             |  /api/v1/server   |            |  Postgres   |
|              |             |  /soundtrack      |            |  (mig 211)  |
+------+-------+             +---------+---------+            +------+------+
       |                               |                             |
       | LiveKit SFU                   | publish event               | RLS
       | (low-pri audio)               v                             |
       v                       +-----------------+                   |
+--------------+               |   Centrifugo    |                   |
|  LiveKit     |<------------- |   pub/sub       |                   |
|  Cloud       |   ingest      | server.{id}.    |                   |
+------+-------+               | soundtrack      |                   |
       ^                       +-----------------+                   |
       | pull HLS / Opus loop                                        |
       |                                                             |
+------+--------+                                              +-----+------+
|   Appwrite    |                                              |   Redis    |
|  Storage      |                                              |   cache    |
|  bucket:      |                                              | active     |
|  soundtracks  |                                              | track key  |
+---------------+                                              +------------+
```

Components:
- Go service `internal/soundtrack` exposes REST + Centrifugo publisher.
- LiveKit ingests the looping Opus stream as a low-priority audio track on the server's room (`audio_priority=4`).
- Appwrite bucket `soundtracks` holds OGG/Opus masters; signed URLs issued to clients (TTL 1h).
- Redis caches `soundtrack:server:{server_id}` for hot-path reads (TTL 300s, invalidated on update).

## 3. REST Routes

All routes under `/api/v1`. Auth: Supabase JWT. Audit: server admin actions logged via `audit_log` table.

| Method | Path                                          | Auth        | Purpose                          |
|--------|-----------------------------------------------|-------------|----------------------------------|
| GET    | /soundtracks/library                          | member      | List curated tracks (paginated)  |
| GET    | /soundtracks/library/:track_id                | member      | Track metadata + preview URL     |
| GET    | /servers/:server_id/soundtrack                | member      | Active track for the server      |
| PUT    | /servers/:server_id/soundtrack                | admin+      | Set active track (body: track_id, volume, enabled) |
| DELETE | /servers/:server_id/soundtrack                | admin+      | Disable soundtrack on server     |
| GET    | /me/soundtrack-overrides/:server_id           | member      | Local mute / volume override     |
| PUT    | /me/soundtrack-overrides/:server_id           | member      | Update mute / volume             |
| POST   | /admin/soundtracks/library                    | platform    | Upload new track (multipart)     |
| PATCH  | /admin/soundtracks/library/:track_id          | platform    | Update metadata or retire        |

Request/response example:

```
PUT /api/v1/servers/srv_42/soundtrack
{
  "track_id": "trk_lofi_rain",
  "volume_db": -22,
  "enabled": true,
  "fade_seconds": 3
}
=> 200 { "active": {...}, "broadcast_id": "bcast_..."}
```

Centrifugo channel `server.{server_id}.soundtrack` pushes:

```
{ "type": "soundtrack.updated", "track_id": "trk_lofi_rain",
  "stream_url": "https://...signed.../loop.ogg", "volume_db": -22,
  "fade_seconds": 3, "version": 7 }
```

## 4. Non-Functional Requirements

- Latency: admin PUT to client receipt < 1.5s p95 via Centrifugo.
- Availability: 99.5% monthly; degraded mode falls back to last-known track in client cache.
- Bandwidth: Opus 48kbps mono, ~22 KB/min, target < 1.4 MB/hr per client.
- Storage: each track <= 8 MB master; library cap 500 tracks (4 GB).
- Loudness: tracks normalized to -22 LUFS at ingest; ducked -6 dB when voice active.
- Battery: client pauses playback when app backgrounded > 30s on mobile.
- Concurrency: cache invalidation safe under 10 concurrent admin writes via row version.

## 5. Observability

Metrics (Prometheus, prefix `flicko_soundtrack_`):
- `track_set_total{server_id_bucket,result}`
- `client_play_seconds_total{server_id_bucket}`
- `client_mute_total`
- `cdn_signed_url_issued_total{bucket=soundtracks}`
- `cache_hit_ratio` (gauge, server lookup)
- `centrifugo_publish_latency_ms` (histogram)

Logs (structured, JSON): event names `soundtrack.set`, `soundtrack.cleared`, `soundtrack.override`, `soundtrack.cdn_fetch_failed`. Always include `server_id`, `actor_id`, `track_id`, `correlation_id`.

Traces (OTel): span tree `http.PUT /soundtrack` -> `db.update` -> `redis.invalidate` -> `centrifugo.publish` -> `audit.write`.

Alerts:
- 5xx on `/soundtrack` > 2% over 10m.
- Cache hit ratio < 0.7 over 30m.
- CDN fetch failure rate > 5% over 15m (likely Appwrite bucket misconfig).

## 6. Failure Modes & Fallbacks

- Appwrite signed URL expired mid-playback -> client requests fresh URL via REST; retries with exponential backoff (1s, 3s, 9s, give up after 3).
- Track retired while in use -> server publishes `soundtrack.cleared`; clients fade out over `fade_seconds`.
- Centrifugo unreachable -> client polls `/soundtrack` every 60s as fallback.
- Low bandwidth (< 80 kbps): client downgrades to 32 kbps variant (pre-encoded), or pauses if no variant available.

## 7. Security & Compliance

- RLS on all 3 tables (members read, admins write to server table, platform-only writes to library).
- Signed URLs scoped to track id, member id, expiry 1h, single-use IP binding off (mobile NAT).
- License metadata required at upload: `license_kind`, `attribution_required`, `source_url`. Surfaced on track picker.
- Audit log entries are immutable, retained 365 days.

Migration: `211_server_soundtrack.sql`. See SCHEMA.md.
