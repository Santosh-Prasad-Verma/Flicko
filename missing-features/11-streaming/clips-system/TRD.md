# Clips System — TRD

## Architecture

```
   +-------------+        POST /clips        +----------------+
   | Mobile/Web  | ------------------------> |  clips-api (Go)|
   +-------------+                           +-------+--------+
                                                     |
                                                     | INSERT clips(status=queued)
                                                     v
                                            +--------+--------+
                                            |   Postgres      |
                                            +--------+--------+
                                                     |
                                            NATS publish
                                            flicko.clips.transcode
                                                     |
                                                     v
                       +-----------------------------+----------------------+
                       |                                                    |
                       v                                                    v
              +--------+----------+                              +----------+--------+
              |  ffmpeg-worker N  |   (NATS queue group)         |  ffmpeg-worker M  |
              +--------+----------+                              +----------+--------+
                       |                                                    |
                       | 1) pull HLS segments around (now - N) .. now       |
                       |    from LiveKit Egress hot path or vod_segments    |
                       | 2) ffmpeg concat + trim + mux MP4 + thumbnail      |
                       | 3) chunkedUpload to Appwrite bucket clips-hot      |
                       | 4) UPDATE clips SET status=ready, mp4_url=...      |
                       v
              Appwrite Storage (clips-hot)  ---- 30d ----> R2 (clips-cold)
                       |
                       v
                  CDN -> viewers
```

In-flight live clip path uses the LiveKit Egress segment ring buffer (last 5 minutes) which `vod-recorder` already writes to Appwrite. The clip worker reads from that buffer; for clips beyond 5 minutes back or when the stream has ended, it reads from `vod_segments`.

## REST Routes

All under `/api/v1/clips`.

| Method | Path | Purpose | Auth |
|---|---|---|---|
| POST | `/` | create clip from a live stream or VOD; body `{stream_id?, vod_id?, t_start_ms?, duration_ms, title?}` | viewer |
| GET | `/:id` | metadata + mp4 URL + thumbnail | public |
| GET | `/:id/oembed` | oEmbed endpoint for Twitter, Discord, Slack | public |
| GET | `/feed` | vertical feed `cursor` + `algo=for_you|following|trending` | public |
| GET | `/users/:handle/clips` | clips made by this user (clipped or featured) | public |
| GET | `/streams/:stream_id/clips` | clips from a stream/creator | public |
| PATCH | `/:id` | edit title or thumbnail (clipper or creator) | owner |
| DELETE | `/:id` | soft delete | owner |
| POST | `/:id/view` | view ping (debounced) | viewer |
| POST | `/:id/report` | report TOS violation | viewer |
| POST | `/:id/like` / `DELETE /:id/like` | like / unlike | viewer |

Internal NATS subjects:
- `flicko.clips.transcode` — request to render
- `flicko.clips.transcoded` — completion event (analytics, push notify clipper)
- `flicko.clips.archive` — cron to push to R2
- `flicko.clips.report` — moderator queue

## Non-Functional Requirements

- **Tap to URL p95 <= 9 s**: enforced as SLO. Worker pool autoscales on queue depth.
- **Concurrent clip jobs**: 100 in-flight, 1000/min throughput at peak.
- **Failure rate <= 0.5%**: ffmpeg deterministic with locked version; idempotent retry on NATS redelivery.
- **MP4 spec**: H.264 high@4.0, AAC-LC 128k, faststart, max 1080x1920 (vertical) or 1920x1080 (horizontal). Bitrate cap 6 Mbps.
- **Length**: 5-300 s. Default 60 s. Above 120 s only for creators and mods of the source stream.
- **Per-viewer rate limit**: 5 clips / min, 60 / day. Token bucket in Redis.
- **CDN**: 1 h browser cache, 24 h edge cache, signed URL not required for public clips.

## Observability

Metrics:
- `flicko_clip_create_to_ready_seconds` histogram (the SLO metric)
- `flicko_clip_transcode_duration_seconds` histogram, label `length_bucket`
- `flicko_clip_queue_depth` gauge
- `flicko_clip_worker_inflight` gauge
- `flicko_clip_failures_total{reason}`
- `flicko_clip_views_total`, `flicko_clip_shares_total`

Logs: `clip_id`, `stream_id`, `vod_id`, `clipper_id`, `t_start_ms`, `duration_ms`. ffmpeg stderr to file, last 200 lines on failure.

Traces: span tree `clip.create -> clip.transcode -> clip.upload -> clip.finalize`.

Alerts:
- p95 create_to_ready > 12 s for 3 windows: page.
- queue_depth > 500 for 10 min: page.
- failure rate > 2% over 5 min: page.

## Encoding & Cost

ffmpeg command (one shot):

```
ffmpeg -ss <t_start> -i <concat_list.txt> -t <duration> \
       -c:v libx264 -preset veryfast -crf 23 \
       -c:a aac -b:a 128k \
       -movflags +faststart \
       -pix_fmt yuv420p \
       <out.mp4>
```

For inputs already H.264 with aligned keyframes (always true since LiveKit egress uses 2 s GOP), we use `-c copy` when t_start hits a keyframe boundary, dropping CPU cost ~10x. The worker checks segment IDR locations and chooses copy vs reencode.

Average clip render: 60 s clip ~ 1.4 s wall on a 4-vCPU worker (copy mode), ~4.5 s on reencode.

Storage:
- 60 s vertical 1080x1920 @ 4 Mbps -> 30 MB. Hot 30 days.
- Hot cost: 30 MB * $0.005/GB-mo * 30d = ~$0.0045/clip.
- Cold cost: $0.015/GB-mo * 0.03 GB = ~$0.00045/clip-month indefinite.

At 10k clips / day for 30 days = 300k hot clips ~ 9 TB hot. ~$45/mo hot, $135/mo cold cumulative growth. Within MVP budget.

## Failure Modes

- **Source segments missing**: worker waits up to 8 s for the segment to land, else fails with `source_unavailable`.
- **ffmpeg OOM**: worker traps SIGKILL, marks clip `errored`, requeues once.
- **Appwrite upload fail**: retry 3x, then write to R2 directly; the clip is born cold but visible.
- **Public clip page hit before mp4_url set**: API returns 202 with `retry_after=2`; mobile shows "rendering..." card.
