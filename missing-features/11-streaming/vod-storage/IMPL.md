# VOD Storage — Implementation Plan

Total budget: 8 weeks, 1 backend eng, 1 mobile eng, 0.5 design.

## Phase 1 — Record + Hot Tier Player (week 1-3)

Goal: every public stream produces a playable HLS VOD within 5 minutes of stream end.

### Backend

- [ ] Apply migration `230_vod_storage.sql` (vods, vod_segments, vod_chapters, RLS, indexes).
- [ ] `backend/internal/vod/recorder/`: NATS subscriber for `livekit.egress.*`. Maintains an in-memory map of active egresses keyed by `egress_id`.
- [ ] `recorder.HandleSegment`: chunkedUpload to Appwrite bucket `vod-hot`, returns `hot_url + etag`, then `INSERT INTO vod_segments`.
- [ ] `recorder.HandleClose`: writes master.m3u8 to Appwrite, updates `vods.status='ready'`, publishes `flicko.vod.finalize`.
- [ ] `backend/internal/handlers/vod/get.go`: `GET /vods/:id` — joins vods + chapters + signed manifest URL.
- [ ] `backend/internal/handlers/vod/manifest.go`: `GET /vods/:id/manifest.m3u8` — proxies the hot manifest, signs segment URLs with 1 h TTL.
- [ ] `backend/internal/handlers/vod/list.go`: `GET /users/:handle/vods` — keyset pagination on `(created_at, id)`.
- [ ] `backend/internal/vod/module.go`: wires recorder, handlers, NATS subjects, OTel tracer.
- [ ] Prom metrics + Sentry tag.

### Mobile (Flutter)

- [ ] `mobile/lib/features/vod/data/vod_repository.dart` — fetch vod + chapters.
- [ ] `mobile/lib/features/vod/presentation/vod_player_screen.dart` — uses `video_player` + `chewie` for native HLS on iOS, `better_player` fallback for Android pre-7. fMP4 HLS works natively on both.
- [ ] `mobile/lib/features/vod/widgets/chapter_rail.dart`.
- [ ] Route: `/vod/:id` registered in `app_router.dart`.
- [ ] Profile tab "VODs" section: `mobile/lib/features/profile/widgets/vod_grid.dart`.

### Tests

- Go: `recorder_test.go` with in-memory NATS + fake Appwrite client. Verify segment idempotency on dup NATS deliveries.
- Go: `handlers/vod/get_test.go` for RLS edge cases (subscriber-only, deleted, errored).
- Flutter: widget test for `vod_player_screen` happy path + error path.
- E2E: spawn LiveKit locally, push 30 s of test video, assert a VOD row reaches `status=ready` and the manifest plays in headless Chrome.

### Exit criteria

- 100 streams in staging produce 100 ready VODs with no manual intervention.
- Player TTFB p95 < 1.8 s on 4G simulated.

## Phase 2 — Cold Tier Archive (week 4-5)

### Backend

- [ ] `backend/internal/vod/archiver/cron.go` — every 5 min picks up to 50 hot vods older than 7 days.
- [ ] `archiver.archiveVOD` — streams segment from Appwrite to R2 via io.Copy without buffering full segment in memory; updates `cold_url`, `archived_at`.
- [ ] After all segments archived, rewrites master playlist to point at R2 origin and uploads to R2.
- [ ] Bulk delete from Appwrite hot bucket; updates `vods.tier='cold'`, nulls `hot_manifest`.
- [ ] Idempotency: `archive_lock` advisory lock keyed on `vod_id` to prevent double archive.
- [ ] Failure backoff: if any segment fails, mark `vods.archive_attempts++` and retry next cron tick. After 6 attempts, page on call.

### Tests

- Unit: archive of a 10-segment vod, ensure all 10 segments end up in R2 with matching etags.
- Failure injection: simulate R2 PutObject failure on segment 5; ensure segments 0-4 stay archived and 5-9 are retried next tick.

### Exit criteria

- Bucket usage in Appwrite for VODs > 7 days drops to zero within one cron tick.
- R2 cost in test env matches projected $0.015/GB-month within 5%.

## Phase 3 — Whisper Chapters + Thumbnails (week 6-7)

### Backend

- [ ] `backend/internal/vod/whisper_worker/main.go` — separate process, NATS consumer of `flicko.vod.transcribe`.
- [ ] On finalize event, recorder publishes `flicko.vod.transcribe` with vod_id.
- [ ] Worker downloads audio rendition (audio-only HLS), runs `whisper.cpp tiny.en` for streams < 1k peak viewers, `small.en` otherwise.
- [ ] Topic boundary heuristic: split on silence > 4 s + cosine distance between rolling 60 s sliding windows of TF-IDF over transcript.
- [ ] Title via first noun phrase of the segment (spaCy via Python sidecar, or Go gse + heuristic).
- [ ] Insert into `vod_chapters`, set `vods.chapters_status='ready'`.
- [ ] Thumbnail sprite: ffmpeg one-shot at finalize, 10 thumbs/min, 160x90, packed into a 1600x900 JPEG + matching VTT.

### Mobile

- [ ] Chapter rail widget (Phase 1 placeholder swap).
- [ ] Scrub thumbnail preview that reads VTT + sprite.
- [ ] Auto-CC toggle wired to OS caption pref.

### Tests

- Whisper deterministic on the fixture audio (md5 of first 10 chapter titles is stable).
- Sprite VTT cue count == ceil(duration/6) and aligns with segment boundaries.

## Phase 4 — Privacy + Quota Dashboard (week 8)

### Backend

- [ ] `PATCH /vods/:id` validates visibility transitions; emits audit log.
- [ ] `DELETE /vods/:id` soft delete + 24 h grace.
- [ ] `vod_purge_worker` (every 30 min) for grace expiry.
- [ ] `GET /me/storage` returns `v_creator_storage` row plus quota.
- [ ] Quota enforcement at recorder admission: if `hot_bytes > 100 GB`, force tier='cold' immediately on finalize.

### Mobile

- [ ] VOD settings sheet (UIUX screen 3).
- [ ] Profile -> Storage screen with progress bars per tier.

### Tests

- Privacy matrix: public/unlisted/subs/private x viewer types (anon, follower, subscriber, creator, admin).
- Quota test: creator at 99 GB hot, finalize a 5 GB vod, expect immediate cold archive.

## $0 Cost Path

- LiveKit OSS self-hosted on existing K3s cluster.
- Appwrite OSS already running for hot media; reuse the existing bucket replication.
- R2 free tier: 10 GB storage + 1 M Class A ops/mo covers MVP for ~30 creators streaming 4 h/wk each.
- Whisper.cpp on the existing GPU spot instance during off-peak (2-7 AM) with NATS backpressure; CPU fallback on idle workers.
- Total incremental infra spend Phase 1-4: $0 in dev, ~$2-5/mo in prod for the first 50 creators.

## Risks Logged

- HLS in-app player on Android < 7 may need ExoPlayer wrapper; budget +2 days.
- Whisper accuracy on multi-speaker streams; chapter quality may regress, mitigation = manual override via UIUX.
- R2 Class A op count if segments are tiny; mitigation = 6 s segments keep ops/hour around 600/stream which is fine.
