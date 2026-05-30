# Short Videos — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + content policy review | 3 |
| 1 | Migration 237 + pgvector | 2 |
| 2 | Upload + storage tier | 3 |
| 3 | Transcoder + captioner workers | 5 |
| 4 | Feed ranker (recency × engagement v1) | 3 |
| 5 | Mobile recorder | 5 |
| 6 | Vertical feed UI | 5 |
| 7 | Engagement endpoints + UI | 3 |
| 8 | Mod queue + reports | 3 |
| 9 | NSFW classifier integration | 3 |
| 10 | Audio fingerprint (Chromaprint) | 3 |
| 11 | QA + load test | 4 |
| 12 | Beta + GA | 5 |

## Backend
- [ ] `supabase/migrations/237_short_videos.up.sql` (with pgvector)
- [ ] `backend/internal/services/streaming/shortvids/{service,uploader,transcoder,captioner,ranker,feed}.go`
- [ ] `backend/internal/services/streaming/shortvids/audio_fp.go` (Chromaprint)
- [ ] `backend/internal/handlers/short_video_handler.go`
- [ ] Existing `attachment_service` extension for video MIME
- [ ] Mod queue extension for short videos
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/streaming/shortvids/`
- [ ] Recorder: `RecorderScreen` (uses `camera` + `image_picker`)
- [ ] Feed: `ShortFeedScreen` (PageView vertical)
- [ ] Detail: `ShortDetailScreen` (comments, share)
- [ ] Profile gallery integration: `ShortsTab` in profile
- [ ] Engagement throttling provider
- [ ] Captions toggle widget
- [ ] L10n + golden tests

## Worker
- ffmpeg pod handling NATS `flicko.shorts.transcode` and `flicko.shorts.caption`.
- Whisper.cpp build with quantized model for speed.

## Files
```
backend/internal/services/streaming/shortvids/...        (new)
backend/internal/handlers/short_video_handler.go         (new)
mobile/lib/features/streaming/shortvids/...              (new)
docker/workers/ffmpeg-shorts.Dockerfile                  (new)
supabase/migrations/237_short_videos.up.sql              (new)
```

## Test
- E2E: record → upload → wait ready → appears in own profile.
- Load: 1k uploads/min for 10 min.
- NSFW classifier accuracy harness with seeded set.
- Privacy: friends-only video not visible to non-friend.
- DMCA: pre-seeded fingerprint → blocked.

## Rollout
- Flag `feature.short_videos.enabled`. Default OFF.
- Beta on 5 creator servers; gate `public` visibility behind separate flag.

## Risks
| Risk | Mitigation |
|------|------------|
| Storage cost | aggressive 30d hot, 60d cold, then archive |
| Toxic content | NSFW classifier + mod queue on public scope |
| Copyright | Chromaprint fingerprint + DMCA inbox |
| Bot spam | per-account daily upload cap |

## Cost (100k DAU, 1% post rate, 60s avg)
| Component | $/mo |
|-----------|------|
| Storage hot | ~$10 |
| Storage cold | ~$3 |
| Transcoding (existing pods) | $0 |
| Whisper | $0 (self-hosted) |
| **Total** | **~$13/mo** (smallest line item across all features) |

## Done
- Recorder + feed shipped
- Captions on every video
- Mod queue live
- Beta NPS ≥4
