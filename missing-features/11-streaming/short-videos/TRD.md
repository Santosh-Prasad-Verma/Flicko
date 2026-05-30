# Short Videos — TRD

## Architecture
```
phone (record/pick) → upload → ffmpeg worker → HLS variants
                                     ↓
                                 Whisper → captions VTT
                                     ↓
                          Postgres (short_videos)
                                     ↓
                Qdrant (embeddings) + Meilisearch (lex)
                                     ↓
                ranking worker → feed_signals → Centrifugo push
```

## Components
- Backend: `backend/internal/services/streaming/shortvids/{uploader.go, transcoder.go, captioner.go, ranker.go, feed.go}`
- Handler: `short_video_handler.go` — POST /shorts, GET /shorts/feed, POST /shorts/:id/like, etc.
- Worker: ffmpeg via NATS subject `flicko.shorts.transcode`; Whisper on `flicko.shorts.caption`
- Realtime: Centrifugo `feed:<user>` for push of new content
- Storage: Appwrite hot 30d, R2 cold 60d (180-day total or delete)

## API
```
POST /shorts (multipart) → {id, status:'queued'}
GET  /shorts/:id         → {id, hls_url, captions_url, author, likes, ...}
GET  /shorts/feed?scope=fyp|following|server:<id>&cursor=…
POST /shorts/:id/like
POST /shorts/:id/comment {text}
POST /shorts/:id/share
POST /shorts/:id/save
POST /shorts/:id/report  {reason}
```

## NFRs
| NFR | Target |
|-----|--------|
| Upload→playable | <90s p50 |
| Feed cold-start | <3s p99 |
| Per-video processing | <60s p99 (60s clip) |
| Storage cost | <$0.005/video |

## Observability
- `flicko_shorts_uploads_total`
- `flicko_shorts_transcode_seconds`
- `flicko_shorts_feed_serve_seconds`
- `flicko_shorts_dropoff_p50` from feed engagement
- Sentry for transcode failures.

## Failure
| Failure | Mitigation |
|---------|------------|
| ffmpeg OOM | bitrate ladder fallback |
| Whisper slow | retry 2× then ship without captions |
| Storage hot tier full | aggressive promote-to-cold |
| Feed rec stale | fallback recency-only ranking |

## Security
- Vertical 9:16 enforced on encode (rotate if needed).
- NSFW classifier (Open NSFW or NudeNet) blocks before publish.
- Audio fingerprint logged (Chromaprint) for DMCA matching.
