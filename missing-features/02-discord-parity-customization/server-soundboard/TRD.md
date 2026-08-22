# Server Soundboard — Technical Requirements

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│ Mobile (Flutter)                                                  │
│                                                                   │
│   SoundboardSheet ──► PlayClipUseCase ──► SoundboardRepo          │
│        │                                       │ HTTPS            │
│        │                                       ▼                  │
│        │                              POST /soundboard/play        │
│        │                                                          │
│   Azure ACSRoom ◄── data-track event 'soundboard.play' ──► AudioMix │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ Go backend                                                        │
│                                                                   │
│   soundboard_handler.go                                           │
│        │                                                          │
│        ▼                                                          │
│   soundboard_service.go                                           │
│        ├─ permissions_service (PLAY/UPLOAD/MANAGE)                │
│        ├─ cooldown_service (Redis INCR + EXPIRE)                  │
│        ├─ audio_normalize_service (ffmpeg) — async                │
│        ├─ moderation_service (hash check)                         │
│        ├─ appwrite_client                                         │
│        └─ azure_communication_calling.PublishData()                            │
│                                                                   │
│        ▼                                                          │
│   Postgres soundboard_clips, soundboard_default_clips             │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                        ┌───────────┐
                        │ Azure ACS   │ fans out data-track event
                        │ SFU       │ peers fetch clip URL via
                        │           │ signed token, decode, mix
                        └───────────┘
```

Audio bytes are NOT pushed through Azure ACS data tracks. Only an event `{clip_id, played_by, started_at}` is broadcast, and each peer fetches the opus URL (cached on edge / device) and plays locally. This keeps SFU bandwidth flat regardless of room size.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/soundboard_service.go`
- **Handlers:** `backend/internal/handlers/soundboard_handler.go`
- **Models:** `backend/internal/models/soundboard.go`
- **Workers:**
  - `backend/internal/services/soundboard/transcode_worker.go` (NATS consumer for ffmpeg/opus encode + LUFS normalize).
- **Repo:** `backend/internal/repo/soundboard_repo.go`
- **Cooldown:** `backend/internal/services/soundboard/cooldown.go` (Redis-backed token bucket).

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/server_soundboard/`
  - `data/` repository, dto, datasource.
  - `domain/` entities (`SoundboardClip`, `Cooldown`).
  - `application/` providers (`soundboardClipsProvider(serverId)`, `playClipProvider`, `recentClipsProvider`).
  - `presentation/` `SoundboardSheet` (replaces stub at `mobile/lib/features/voice/presentation/soundboard_sheet.dart`), `ClipUploadScreen`, `ClipManageScreen`, `ClipChip`.
- **Audio mixer:** `mobile/lib/features/voice/services/soundboard_audio_mixer.dart` — uses `just_audio` to play opus alongside Azure ACS voice; ducks 25% on spike.

### Infra
- DB: Postgres tables in `SCHEMA.md`.
- Realtime: Azure ACS data tracks on existing room sid, plus Centrifugo `server:{server_id}` for library updates.
- Cache: Redis keys `sb:cd:{server_id}:{user_id}`, `sb:lib:{server_id}` (5m), `sb:recent:{room_sid}` (LIST trim 10).
- Storage: Appwrite bucket `soundboard-clips` (original + opus).
- Audio: ffmpeg via `os/exec` for transcode + LUFS normalize.
- Queue: NATS `flicko.soundboard.transcode`.

## 3. API Contracts

### REST

```
GET    /api/v1/servers/:sid/soundboard            list (defaults + custom + permissions)
POST   /api/v1/servers/:sid/soundboard            multipart upload (mod)
PATCH  /api/v1/servers/:sid/soundboard/:cid       rename / re-emoji / disable
DELETE /api/v1/servers/:sid/soundboard/:cid       remove (mod)
POST   /api/v1/voice/rooms/:rid/soundboard/play   trigger playback
PATCH  /api/v1/servers/:sid/soundboard/settings   per-role perms + cooldown
POST   /api/v1/soundboard/clips/:cid/report       member report
```

### Azure ACS data-track payload

```jsonc
{
  "type": "soundboard.play",
  "clip_id": "0c2a...",
  "clip_url": "https://appwrite.flicko.dev/.../clip.opus",
  "played_by": "user_9f...",
  "name": "GG WP",
  "emoji": "🏆",
  "started_at": "2026-05-29T11:00:00.123Z"
}
```

### POST play request/response

```jsonc
// request
{ "clip_id": "0c2a..." }

// 200
{
  "ok": true,
  "started_at": "2026-05-29T11:00:00.123Z",
  "next_play_in_ms": 5000
}

// 429 cooldown
{ "error": "cooldown", "retry_after_ms": 3500 }

// 403 no permission
{ "error": "missing_permission", "required": "SOUNDBOARD_PLAY" }

// 422 clip disabled
{ "error": "clip_disabled" }
```

## 4. Permissions & Auth

Three new permission bits added to `PermissionFlags`:
- `SOUNDBOARD_PLAY` (default: `@everyone`)
- `SOUNDBOARD_UPLOAD` (default: roles with `MANAGE_MESSAGES`)
- `SOUNDBOARD_MANAGE` (default: roles with `MANAGE_SERVER`)

Members must have `SOUNDBOARD_PLAY` for the channel/server AND be currently joined to the Voice room targeted.

RLS in `SCHEMA.md`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Playback latency (tap → all peers play) | p95 <250 ms |
| POST /play p50 | <60 ms |
| POST /play p99 | <180 ms |
| Upload p95 (sync part) | <800 ms |
| Transcode worker p95 | <4 s |
| Throughput plays | 200 rps cluster |
| Availability | 99.9% |
| Storage cost | <$0.005 / server / month |
| Egress (CDN) | <$0.05 / 1k plays |
| GDPR | clip rows cascade on `users.delete`; original blobs purged within 24h |

## 6. Dependencies

- Azure ACS Go SDK (already integrated): `github.com/azure_acs/protocol` for data-track API.
- `os/exec` ffmpeg — version pinned in Dockerfile.
- `github.com/redis/go-redis/v9` (existing).
- Existing `services/permissions_service.go`, `services/voice_service.go`, `services/moderation_service.go`.
- Mobile: `just_audio: ^0.10.0`, `azure_communication_calling: ^2.4.0` (already in `mobile/pubspec.yaml`).

## 7. Observability

- Metrics:
  - `flicko_soundboard_plays_total{result="ok|cooldown|forbidden|disabled"}`
  - `flicko_soundboard_play_latency_seconds` (histogram)
  - `flicko_soundboard_uploads_total{result}`
  - `flicko_soundboard_transcode_duration_seconds` (histogram)
  - `flicko_soundboard_storage_bytes` (gauge)
- Logs: structured at INFO `{event, server_id, user_id, clip_id, room_sid}`. Errors → Sentry.
- Traces: OTel spans `sb.play`, `sb.upload`, `sb.transcode`, `sb.cooldown`.
- Dashboards: Grafana `Soundboard` board.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Azure ACS data publish fails | clip plays only locally | retry 1× then mark play failed; UI greys chip briefly |
| Appwrite slow → clip URL 404 | peer can't fetch | each peer falls back to BlurHash-style "🔊 unavailable" chip; reportable |
| Cooldown Redis down | naive UI state would allow spam | service falls back to 5s in-memory cap per process; degraded but safe |
| Transcode worker crash | upload stuck `processing` | retry 3× then mark `failed`; mod can re-upload |
| Banned-hash false positive | legit clip rejected | mod appeal via existing `moderation_actions_handler.go` |
| Network spike (1000 plays/sec spam) | cooldown saves us; upstream rate-limit | Redis token bucket + global per-server play rate cap |

## 9. Security & Privacy

- Clip URLs are short-lived signed Appwrite URLs (1h) issued per Voice room session.
- Recording detection: not blocked but logged as `clip_played_in_recorded_room` (Azure ACS egress flag).
- Stripping EXIF / metadata is a no-op for audio, but ffmpeg transcode rewrites container so any private id3 tags are dropped.
