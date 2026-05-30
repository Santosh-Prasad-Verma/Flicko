# VOD Storage — TRD

## Architecture

```
                 +-----------------+
  Live RTMP -->  |  LiveKit Ingress | -- WebRTC --> viewers (live)
                 +--------+--------+
                          |
                          v
                 +-----------------+
                 |  LiveKit Egress |  HLS, 6s fMP4 segments
                 +--------+--------+
                          |
                          v  segments + master.m3u8
                 +------------------------+
                 |  vod-recorder (Go svc) |
                 |  - listens NATS        |
                 |  - writes Appwrite     |
                 |  - inserts vod_segments|
                 +-----+-------+----------+
                       |       |
                       v       v
              Appwrite Storage   Postgres (Supabase)
              hot bucket: vod-hot   tables: vods, vod_segments
                       |
                  age >= 7d
                       v
            +-------------------------+
            | vod-archiver (Go cron)  |
            | - copies HLS to R2      |
            | - rewrites segment URLs |
            | - deletes from Appwrite |
            +-----+-------------------+
                  |
                  v
            Cloudflare R2 (cold)
            bucket: flicko-vod-cold

            Whisper worker (parallel)
            transcribes audio -> vod_chapters
```

## REST Routes

All under `/api/v1/vod`. Auth via JWT cookie or `Authorization: Bearer`.

| Method | Path | Purpose | Auth |
|---|---|---|---|
| GET | `/vods/:id` | metadata + signed playlist URL | viewer |
| GET | `/vods/:id/manifest.m3u8` | proxied master playlist with signed segment URLs | viewer |
| GET | `/vods/:id/chapters` | array of `{t_start, t_end, title}` | viewer |
| GET | `/vods/:id/thumbnail-sprite.vtt` | scrubbing thumbnail VTT | viewer |
| GET | `/users/:handle/vods` | paginated list, `cursor` + `limit` | public |
| PATCH | `/vods/:id` | update title, description, visibility | creator only |
| DELETE | `/vods/:id` | soft delete; hard purge after 24 h | creator/admin |
| POST | `/vods/:id/report` | TOS report | viewer |
| GET | `/vods/:id/download` | one-time signed URL, MP4 mux on demand | creator only |

Internal (NATS):
- `flicko.vod.segment_written` — published by recorder per segment
- `flicko.vod.finalize` — published when LiveKit Egress closes
- `flicko.vod.archive` — cron-triggered for promotion to R2
- `flicko.vod.transcribe` — fan-out to Whisper worker

## Non-Functional Requirements

- **Recording reliability**: lose <= 5 s of footage on Egress crash. Achieved by 6 s segment duration + idempotent segment numbering.
- **Playback start p95**: <= 1.8 s. Master playlist served from edge CDN, segments are 6 s, first segment is preloaded by player.
- **Scrub p95**: <= 800 ms to render keyframe. fMP4 with `EXT-X-INDEPENDENT-SEGMENTS` so any segment is decodable standalone.
- **Durability**: hot tier 11 9s (Appwrite/Backblaze B2 backed), cold tier 11 9s (R2). No single-region risk because R2 is multi-region.
- **Concurrency**: 1000 concurrent streams recording, 50k concurrent VOD viewers. Each segment is < 4 MB; CDN absorbs read traffic.
- **Recovery**: if `vod-recorder` dies mid-stream, the segment list is reconstructed from Appwrite list-files API on restart.

## Observability

Metrics (Prometheus):
- `flicko_vod_segment_write_duration_seconds` histogram
- `flicko_vod_finalize_lag_seconds` gauge (egress close -> playable)
- `flicko_vod_hot_bytes_total{creator_id}` counter
- `flicko_vod_cold_bytes_total{creator_id}` counter
- `flicko_vod_archive_failures_total` counter
- `flicko_vod_chapters_generated_total` counter

Logs: structured JSON, `stream_id`, `vod_id`, `segment_seq`. Errors pushed to Sentry with `vod` tag.

Traces: OTel spans `vod.record`, `vod.finalize`, `vod.archive`, `vod.transcribe`. Parent context comes from the live stream span.

Alerts:
- finalize_lag p95 > 5 min for 3 consecutive 5-min windows -> page
- archive_failures > 0 for 30 min -> warn
- hot bucket usage > 80% -> warn

## Encoding Profile

LiveKit Egress preset:
- Container: HLS (fMP4)
- Segment: 6 s, `keyframe_interval = 2 s`
- Codec: H.264 high@4.1, AAC-LC 128 kbps stereo
- Ladder: 1080p60 @ 6 Mbps, 720p30 @ 3 Mbps, 480p30 @ 1.2 Mbps
- Master playlist + per-rendition playlist + init.mp4 + segments

## Storage Cost Model

Hot (Appwrite, backed by B2 or self-hosted): $0.005 / GB-month read, free egress to our CDN.
Cold (R2): $0.015 / GB-month, $0 egress, $4.50 / million Class A ops.

A 2 h stream at 720p30 @ 3 Mbps -> ~2.7 GB.

Monthly cost for one creator with 4x weekly 2 h streams:
- Hot: 4 streams x 2.7 GB x ~1 week avg residence = 10.8 GB hot at any time -> $0.054/mo
- Cold: 16 streams/mo x 2.7 GB = 43 GB/mo accumulated, ~$0.65/mo for the first month, growing

Break-even vs. Twitch is fine because we monetize via tipping + subs, not storage.

## Failure Modes

- **Egress segment gap > 30 s**: insert `gap` row in `vod_segments`, the player skips the missing range.
- **Appwrite 429**: exponential backoff with jitter, max 5 attempts, then degrade to direct R2 PUT.
- **R2 archive partial**: keep hot tier until full archive succeeds; idempotent based on `vod_segments.archived_at`.
- **Whisper failure**: chapters become null, player hides the chapter rail.
