# Game Clip Sharing — PRD

> **One-line:** Capture, store, and share 30–90s game clips from desktop and mobile with auto-thumbnails and HLS playback.
> **Effort:** L
> **Priority:** P1

## Problem
Sharing gameplay highlights today means uploading to YouTube/Twitch and pasting a link. A native clip surface with auto-capture and instant share keeps the moment in-server and contextual.

## Users
- Streamers wanting quick re-shares without VOD editing.
- Casual players sharing funny moments.
- Esports server admins archiving plays.

JTBDs:
1. Hotkey-clip the last 30/60/90s without thinking.
2. Trim and post in <60s.
3. Browse channel's clip wall.

## Goals
- Hotkey + button capture
- 1080p60 source, multi-bitrate HLS output
- Auto thumbnail at peak audio
- Share link to specific clip outside Flicko

Non-goals: Full timeline editor (just trim).

## Scope
- [ ] Desktop ring buffer (last 60s always recording)
- [ ] Mobile screen-record API integration
- [ ] Server transcode pipeline
- [ ] Clip wall per channel
- [ ] Reactions on clips

## Metrics
| Metric | Target |
|--------|--------|
| Capture-to-shareable | <30s p50 |
| Daily clips per active gaming server | >5 |
| Storage cost / clip | <$0.001 |

## Risks
- Storage cost. Mitigation: 30d hot, 60d cold, then delete unless saved.
- DMCA. Mitigation: Chromaprint fingerprint + DMCA inbox.
- Bandwidth. Mitigation: client-side compression before upload.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Medal.tv | Standalone | Tied to Flicko server |
| Outplayed | PC only | Cross-platform |
| Discord Stage clips | Limited | Native + searchable |
