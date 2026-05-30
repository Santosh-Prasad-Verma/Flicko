# Game Clip Sharing — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 2 |
| 1 | Migration 153 | 1 |
| 2 | Uploader + transcoder | 5 |
| 3 | Desktop ring buffer (Tauri plugin) | 5 |
| 4 | Mobile screen-rec | 4 |
| 5 | Trim editor | 3 |
| 6 | Channel clip wall | 3 |
| 7 | Audio fingerprint (Chromaprint) | 3 |
| 8 | QA + DMCA flow | 3 |
| 9 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/153_clips.up.sql`
- [ ] `backend/internal/services/gaming/clips/{uploader,transcoder,trim,fingerprint}.go`
- [ ] `backend/internal/handlers/clips_handler.go`
- [ ] Existing `attachment_service` extension
- [ ] Mod queue + DMCA inbox
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/gaming/clips/`
- [ ] `CapturePopup`, `TrimScreen`, `ClipWallScreen`, `ClipPlayerScreen`
- [ ] Riverpod, Hive draft caching
- [ ] L10n + golden tests

## Desktop
- [ ] `desktop/src-tauri/src/clip_buffer.rs` (Rust ring buffer wrapping ffmpeg)
- [ ] Hotkey (default Alt+F10) registration

## Files
```
backend/internal/services/gaming/clips/...        (new)
backend/internal/handlers/clips_handler.go        (new)
mobile/lib/features/gaming/clips/...              (new)
desktop/src-tauri/src/clip_buffer.rs              (new)
docker/workers/ffmpeg-clips.Dockerfile            (new)
supabase/migrations/153_clips.up.sql              (new)
```

## Test
- Buffer fidelity: clip exact last 60s with 0.5s tolerance.
- Concurrent uploads: 50/min hold without queue blow-up.
- DMCA: pre-seeded fingerprint blocks.
- Mobile permission denied path.

## Rollout
- Flag `feature.clips.enabled`. Default OFF.
- Beta on 5 gaming servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Storage cost | retention windows + saved-only persistence |
| DMCA | fingerprint + DMCA inbox |
| Mobile foreground rec restrictions | fallback to share-from-system |

## Cost
$0 free tier; storage scales near-zero per clip if retention enforced.
