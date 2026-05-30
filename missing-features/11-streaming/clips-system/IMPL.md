# Clips System — Implementation Plan

Total budget: 6 weeks, 1 backend eng, 1 mobile eng, 0.5 design, 0.25 ML eng for Phase 4.

## Phase 1 — Backend Clip Pipeline (week 1-2)

Goal: clip create -> ready MP4 URL via API in p95 <= 9 s.

### Backend

- [ ] Apply migration `231_clips_system.sql`.
- [ ] `backend/internal/clips/api/`:
  - [ ] `POST /clips` handler: validate range, rate-limit via `internal/ratelimit` (5/min, 60/day), insert row, publish `flicko.clips.transcode`.
  - [ ] `GET /clips/:slug` handler: read clip, return mp4_url + thumb. 202 if status != ready.
  - [ ] `GET /clips/:slug/oembed` handler: returns oEmbed JSON for share unfurls.
  - [ ] `POST /clips/:slug/view` handler: writes `clip_views`, increments `view_count` via debounce (max 1/viewer/clip/day).
  - [ ] `POST /clips/:slug/like` / `DELETE /clips/:slug/like`.
- [ ] `backend/internal/clips/worker/main.go` — separate binary, NATS consumer of `flicko.clips.transcode`, queue group `clip-workers`.
  - [ ] Resolve segment range from `vod_segments` (vod source) or LiveKit Egress hot buffer (live source).
  - [ ] Build a concat list, run ffmpeg with `-c copy` if t_start aligns with IDR else reencode.
  - [ ] Generate thumbnail with `ffmpeg -ss <half> -frames:v 1 -vf scale=480:-2`.
  - [ ] Upload mp4 + thumb to Appwrite bucket `clips-hot`.
  - [ ] Update clip row, publish `flicko.clips.transcoded`.
- [ ] Advisory lock (`pg_try_advisory_lock(hashtext(clip_id))`) inside worker to dedupe NATS redeliveries.
- [ ] OTel + Prom metrics + Sentry. SLO histogram on `flicko_clip_create_to_ready_seconds`.

### Tests

- Unit: ffmpeg copy-mode vs reencode decision logic.
- Integration: spawn LiveKit + ffmpeg-worker, push 3 min stream, fire 10 clip requests at random offsets, assert all reach `ready` with valid mp4 (mediainfo check).
- Load: 100 concurrent clip requests, p95 <= 9 s, error rate <= 0.5%.

### Exit criteria

- 1000 clips in staging, all `ready`, p95 8.4 s in measurements.
- mp4 plays in Chrome, Safari iOS, Android Chrome, VLC.

## Phase 2 — Mobile Capture + Detail (week 3)

### Mobile

- [ ] `mobile/lib/features/clips/data/clip_repository.dart`.
- [ ] `mobile/lib/features/clips/presentation/clip_capture_sheet.dart` (UIUX screen 1).
- [ ] `mobile/lib/features/clips/presentation/clip_detail_screen.dart` (UIUX screen 2).
- [ ] `mobile/lib/features/clips/widgets/share_sheet.dart` with native share + TikTok/X deep links.
- [ ] Polling loop with exponential backoff (300 ms, 600 ms, 1.2 s ...) up to 12 s; fall back to long poll on websocket if available.
- [ ] Hook clip button into the live player toolbar (`stream_viewer_screen.dart`).
- [ ] Web equivalent: `web/clips/[slug].tsx` for share unfurls and direct opens.

### Tests

- Flutter widget tests for sheet states (idle, clipping, ready, error).
- Manual: capture 30 / 60 / 90 / 5 min; verify each plays back.

### Exit criteria

- 95% of internal team test clips render in < 9 s on prod-like staging.
- Share-link unfurls correctly on Twitter, Discord, Slack, iMessage.

## Phase 3 — Vertical Clips Feed (week 4-5)

### Backend

- [ ] `GET /clips/feed?algo=for_you|following|trending`:
  - `following`: clips from creators the viewer follows, ordered by created_at desc.
  - `trending`: precomputed materialized view `clip_trending_24h` refreshed every 10 min, ranked by weighted score (views + 5*likes + 20*shares + decay).
  - `for_you`: simple bandit on top of trending: 70% trending, 20% following, 10% explore (random from same language).
- [ ] Pagination cursor: `(score, clip_id)` for trending, `(created_at, clip_id)` for following.
- [ ] Pre-warm CDN: feed handler returns next clip's mp4_url which the client preloads.

### Mobile

- [ ] `mobile/lib/features/clips/presentation/clips_feed_screen.dart` with `PageView.builder`, snap-scroll vertical.
- [ ] Pre-buffer next 1 clip via `video_player` controller pool of 3.
- [ ] Tab bar (`For You`, `Following`, `Trending`) with persisted last tab.
- [ ] Bottom nav entry "Clips" with TikTok-like icon.

### Tests

- 50-clip feed scroll on mid-tier Android (Pixel 4a): no jank > 16 ms / frame, RAM stable < 220 MB.
- iOS Safari web: PWA mode plays inline with sound after first user gesture.

### Exit criteria

- Median session length on Clips tab >= 4 min within 2 weeks of launch.

## Phase 4 — Reports + Moderation + Cold Tier (week 6)

### Backend

- [ ] `POST /clips/:slug/report` handler.
- [ ] Internal `GET /admin/clip-reports?status=pending` handler with mod role gate.
- [ ] `POST /admin/clips/:slug/remove` handler — sets `removed_reason`, nulls mp4 urls, marks status=`removed`, queues purge.
- [ ] `clip-archiver` cron — 30 day promotion to R2, similar to vod-archiver.
- [ ] Auto-flag heuristic: if `report_count >= 5` within 1 h, auto `pending_review` and surface to mods.

### Mobile

- [ ] Report dialog with reasons.
- [ ] "Removed" state on Clip Detail page.

### Tests

- Mod queue happy path: report -> review -> remove -> public 410.
- Cold archive: 30-day-old clip ends in R2, removed from Appwrite, mp4_url updated.

## Test Plan Summary

- Unit: 80% coverage on clips api, worker decision logic, RLS.
- Integration: ffmpeg in CI with a fixture HLS stream (10 segments).
- E2E: BrowserStack matrix on iOS 16 / Android 11 / Chrome / Safari.
- Load: k6 script ramping 0 -> 1000 clip-creates over 5 min; SLO assertion.
- Chaos: kill ffmpeg-worker mid-render, assert NATS redelivery brings clip to ready within SLO.

## $0 Cost Path

- ffmpeg-worker on existing K3s cluster, scaled by KEDA on NATS queue depth. Spot nodes only.
- Appwrite hot already paid as fixed self-host. Each clip ~ 30 MB; with 30 day retention, 10k clips/day -> ~9 TB. Existing Appwrite cluster has 12 TB free.
- R2 free tier covers cold storage growth for first ~6 months.
- Whisper-based caption burning is Phase 5+, not in this budget.
- Total marginal infra spend MVP: $0; first paid bill projected ~ $40/mo at 50k DAU.

## Risk Log

- ffmpeg version drift breaks copy-mode detection. Mitigation: pin `ffmpeg=6.1` in worker image, smoke test in CI.
- NATS at-least-once causes double clips visible briefly. Mitigation: advisory lock + idempotent Appwrite filename `clip_{id}.mp4`.
- TikTok deep link API changes (no public spec). Mitigation: graceful copy-link fallback.
- Vertical feed RAM on low-end Android. Mitigation: clamp controller pool to 2 below 3 GB RAM devices.

## Done Definition

- All 12 success metrics across PRD wired into Grafana.
- Public clip URL works as oEmbed for X, Discord, Slack within 1 week of launch.
- Mod queue p95 time-to-resolve < 30 min during business hours.
