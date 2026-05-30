# VOD Storage — PRD

**One-line:** Automatically record every Flicko live stream, persist HLS playlists for 7 days on hot storage and indefinitely on cold storage, and let viewers replay, scrub, and chapter-jump from a polished VOD player.

## Problem

Flicko currently terminates a live stream the moment the broadcaster ends it. Viewers who arrived late, dropped connection, or live in a different timezone cannot watch what they missed. Creators lose the long tail of discovery, and our retention curve cliffs at the end of a live window. Twitch, Kick, and YouTube Live all retain VODs by default; without this we cannot compete for serious creators.

## Jobs To Be Done

- **Late viewer**: "When I open Flicko after a stream ended, I want to watch it from the start so I don't feel left out."
- **Returning fan**: "When my favorite creator was live while I was at work, I want to scrub to the moment everyone is talking about."
- **Creator**: "When my stream ends, I want a permanent URL I can share to Twitter and embed on my site so my work doesn't disappear."
- **Moderator**: "When a report comes in 3 days after a stream, I want to review the original footage so I can act on the report fairly."
- **Editor**: "When I want to make highlights, I want chapter markers so I can navigate to interesting moments without watching everything."

## Scope

In:
- Auto-record every public live stream via LiveKit Egress (HLS, fMP4, 6s segments)
- Hot tier on Appwrite Storage for the first 7 days, with `chunkedUpload` resumable writes
- Cold tier promotion to Cloudflare R2 after 7 days, with HLS rewrite to point at R2 origin
- VOD player (HLS.js on web, AVPlayer/ExoPlayer via `video_player` on mobile)
- Auto-chapter generation via Whisper transcription + lightweight topic boundary detection
- Per-VOD privacy: public, unlisted, subscriber-only, deleted
- Per-creator quota: 100 GB hot, 1 TB cold (Phase 1)

Out:
- Editing the VOD body itself (clipping is in `clips-system`)
- DVR rewind during a live stream (covered by `native-rtmp-streaming` later)
- Multi-bitrate ABR ladder beyond 1080p / 720p / 480p
- Subtitle authoring UI (auto-generated VTT only)

## Success Metrics

| Metric | Target | Window |
|---|---|---|
| % of streams that produce a playable VOD within 5 min of stream end | >= 97% | rolling 7d |
| VOD play start latency p95 (HLS first segment) | <= 1.8 s | rolling 7d |
| Hot-tier storage cost per concurrent stream-hour | <= $0.012 | monthly |
| 7-day VOD viewer return rate (viewers who watch a VOD after the live ended) | >= 22% | per creator |

## Competitive Snapshot

| Platform | Default retention | Chapters | Cold tier | Mobile scrub | Cost to creator |
|---|---|---|---|---|---|
| Twitch (Affiliate) | 14 days | Manual | None | Yes | Free |
| Twitch (Partner) | 60 days | Manual | None | Yes | Free |
| YouTube Live | Forever | Auto (AI) | Google internal | Yes | Free |
| Kick | 60 days | None | None | Yes | Free |
| Trovo | 14 days | None | None | Yes | Free |
| **Flicko** | **7d hot + forever cold** | **Auto (Whisper)** | **R2** | **Yes** | **Free** |

Differentiator: indefinite cold-tier retention plus auto-chapters at the free tier, where Twitch charges Partner status and Kick has none.

## Risks

- LiveKit Egress disconnects mid-stream and we lose the tail. Mitigation: Egress restarts on segment-watcher gap > 30 s, partial VOD is still saved.
- Appwrite chunked upload throttles at high concurrency. Mitigation: presigned PUT to R2 as a fallback hot tier when concurrent streams > 500.
- Whisper costs scale with stream-hour. Mitigation: transcribe at 0.5x with `tiny.en` for chapter boundaries; only upgrade to `small` for streams with > 1k peak viewers.

## Rollout

Phase 1 (week 1-3): record + hot tier + basic player.
Phase 2 (week 4-5): cold-tier promotion, signed URLs.
Phase 3 (week 6-7): chapters + thumbnail sprite.
Phase 4 (week 8): privacy controls, creator quota dashboard.

## Open Questions

- Do we expose download for the creator's own VODs? Likely yes, gated by KYC.
- Subscriber-only VODs need the subscription product; depends on monetization milestone.
- GDPR right-to-erasure on cold tier requires a tombstone in `vods.deleted_at` and an async R2 purge worker.
