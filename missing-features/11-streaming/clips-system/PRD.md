# Clips System — PRD

**One-line:** Let any viewer capture the last 30/60/90 seconds of a live stream as a shareable MP4 in under 10 seconds, with a thumbnail, a title, and a public URL that plays everywhere.

## Problem

The funniest, most surprising, and most viral moments of a stream happen in 5 to 60 second bursts. Without a clipping system the audience has no way to capture and share these moments outside of screen recordings, and the creator loses the single highest-leverage growth channel: short-form clips on TikTok, Reels, Shorts. Twitch Clips alone drives an estimated 30% of new-channel discovery.

## Jobs To Be Done

- **Excited viewer**: "When something hilarious just happened, I want to capture it in 2 taps so I can share it before the moment passes."
- **Creator**: "When I want to repurpose my stream into TikToks, I want a library of the best clips from my own community so I don't have to re-watch the whole VOD."
- **Discovery viewer**: "When I open Flicko's Clips feed, I want vertical short-form clips so I can find new creators in the same way I scroll TikTok."
- **Moderator**: "When clip content violates TOS, I want a fast report and remove flow so I can act before it spreads."
- **External viewer**: "When a friend sends me a Flicko clip link, I want it to play instantly without an account or app install."

## Scope

In:
- "Clip the last N seconds" button in the live player (30 / 60 / 90 default; 5-300 s allowed for creator and mods).
- Server-side clip job: pull last-N from LiveKit Egress segment buffer or from in-progress VOD, ffmpeg trim to MP4 (H.264 + AAC, faststart).
- NATS subject `flicko.clips.transcode` fan-out to ffmpeg workers.
- Auto-thumbnail at 50% of clip duration, plus an "edit thumbnail" frame picker.
- Auto-title from chapter context if available, else "Clip from <stream title>".
- Vertical Clips feed (TikTok-style) with infinite scroll and auto-advance.
- Share to: web URL, copy link, native share sheet, in-app DM, X, TikTok deep link.
- Reporting + moderation queue.

Out:
- Multi-clip stitching / editor timeline (Phase 5+).
- AI auto-caption burning (later, ties to Whisper output).
- Clip monetization (ads / tips on clips) — separate spec.

## Success Metrics

| Metric | Target | Window |
|---|---|---|
| Clip create -> playable URL p95 latency | <= 9 s | rolling 7d |
| Clip created per 1k live concurrent viewers per hour | >= 18 | rolling 30d |
| % of clips watched by at least 1 non-creator viewer within 24 h | >= 65% | rolling 30d |
| Clip share-out rate (off-platform shares / clip creates) | >= 14% | rolling 30d |

## Competitive Snapshot

| Platform | Default length | Custom length | Speed (tap -> URL) | Vertical feed | Off-platform share |
|---|---|---|---|---|---|
| Twitch Clips | 30 s | 5-60 s | ~7 s | No | Limited |
| YouTube Live Clips | 30 s | 5-60 s | ~12 s | Shorts | Yes |
| Kick Clips | 30 s | 5-90 s | ~10 s | No | Yes |
| TikTok Live Replay | n/a | n/a | n/a | Yes | Native |
| **Flicko Clips** | **60 s** | **5-300 s** | **<=9 s** | **Yes** | **Yes (incl. TikTok deep link)** |

Differentiator: longest custom range at 5 minutes, vertical Clips feed for discovery, and the 9 second SLA which is industry-leading.

## Risks

- ffmpeg worker queue saturates during big streams. Mitigation: per-stream rate limit (5 clips/min/viewer), priority queue for first-time clippers.
- Clip captures NSFW content from a stream that was fine in context. Mitigation: clip retains stream's mature flag; viewer report flow with 24/7 trust-and-safety routing.
- Clip URL becomes a vector for harassment if linked to viewer name. Mitigation: clip page shows the streamer prominently, the clipper as a small attribution.
- MP4 muxing memory blowup on 5 min clips. Mitigation: ffmpeg `-movflags +faststart` with single-pass, RAM limit 512 MB per worker.

## Rollout

Phase 1 (week 1-2): backend clip job, MP4 output, public URL.
Phase 2 (week 3): in-player "Clip" button, share sheet.
Phase 3 (week 4-5): vertical Clips feed.
Phase 4 (week 6): reports + moderation queue.
Phase 5 (later): captions, multi-clip stitching, monetization.

## Open Questions

- Does the clip URL auto-play with sound on web? Browsers block sound autoplay; we play muted with a tap-to-unmute affordance, like TikTok's web embeds.
- Do we host the MP4 on Appwrite or R2? MVP: hot clips on Appwrite for first 30 days, then R2 for cold.
- Do we let viewers re-clip from a VOD after stream ends? Yes, Phase 2.5, using the VOD HLS segments instead of the live egress buffer.
