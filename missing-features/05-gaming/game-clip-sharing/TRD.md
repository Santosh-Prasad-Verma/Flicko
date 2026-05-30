# Game Clip Sharing — TRD

## Architecture
```
Desktop ring buffer / mobile screen rec
  ↓ (multipart upload)
Backend uploader → Appwrite hot
  ↓ NATS flicko.clips.transcode
ffmpeg worker → HLS variants + thumbnail
  ↓
Postgres clips → Centrifugo → channel feed
```

## Components
- Desktop: Tauri plugin `clip-buffer` Rust ring buffer w/ ffmpeg keyframe align.
- Mobile: `mobile/lib/features/gaming/clips/`, uses `flutter_screen_recording` and `image` packages.
- Backend: `backend/internal/services/gaming/clips/{uploader,trim,transcode_dispatch}.go`
- Worker: ffmpeg pod consuming NATS subject `flicko.clips.transcode`.
- Storage: Appwrite hot 30d → R2 cold 60d → delete unless `saved=true`.

## API
```
POST /clips (multipart) → {id, status:'queued'}
PATCH /clips/:id {trim_in, trim_out, caption}
GET /clips/:id
GET /channels/:id/clips?cursor=…
POST /clips/:id/save (pin to user library)
POST /clips/:id/react {emoji}
```

## NFRs
| NFR | Target |
|-----|--------|
| Capture→ready | <30s for 60s clip |
| Player startup | <1.5s p99 |
| Storage cost | <$0.001/clip |

## Observability
- `flicko_clips_uploads_total`
- `flicko_clips_transcode_seconds`
- `flicko_clips_views_total`

## Failure
| Failure | Mitigation |
|---------|------------|
| ffmpeg crash | retry 2× with reduced bitrate |
| Upload disconnect | tus-style resume |
| DMCA hit | block + notify |
