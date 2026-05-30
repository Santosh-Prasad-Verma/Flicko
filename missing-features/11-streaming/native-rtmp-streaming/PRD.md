# Native RTMP Streaming — Product Requirements

> **One-line:** Twitch-grade RTMP ingest into any voice/stage channel with HLS playback.
> **Status:** Missing — to build
> **Category:** 11-streaming
> **Effort:** XL
> **Priority:** P0
> **Migration:** 230
> **Slug:** `native-rtmp-streaming`

## 1. Problem

Discord's "Go Live" forces users into a screenshare originating from the Discord app on the same device — there is no way to plug OBS / Streamlabs / a hardware encoder / a console capture card directly into a Discord voice channel. Streamers therefore split their audience between Twitch and Discord, lose interactive features (donations, clips, polls) when they fall back to screenshare, and pay Twitch's mature creator stack instead of paying Flicko.

Our own support tickets repeatedly ask:

- "Can I push my OBS feed into a stage?" (1,243 hits in `/forum/feature-requests`)
- "How do I stream my PS5 here without a capture card on my PC?" (412 hits)
- "Why does Go Live cap at 720p60 when my upload is 50 Mbps?" (290 hits)

Flicko already runs LiveKit for voice/video. LiveKit ships an Ingress service that accepts RTMP/SRT/WHIP and republishes as a SFU track. By exposing a per-channel ingress URL + stream key we get Twitch-grade ingest essentially for free; viewers consume the same SFU track in-app or fall back to an HLS rendition served by the existing LiveKit Egress.

## 2. Users & Use Cases

- **Primary persona:** *Variety streamer Maya* — runs OBS Studio, has 2k Twitch followers, wants to spin up a Flicko server as her community hub and stream there exclusively on weekends.
- **Secondary personas:**
  - Console gamer who wants to push from PS5/Xbox via the built-in Twitch RTMP encoder (we expose a Twitch-compatible URL).
  - Server owner running scheduled "movie nights" with a hardware encoder fed from a Blu-ray player.
  - Educator pushing a multi-cam classroom feed (Atem Mini → RTMP) into a stage channel.

**Top jobs-to-be-done**
1. As a streamer, I want to plug OBS into a Flicko channel using the same flow as Twitch, so that my existing setup works without changes.
2. As a viewer, I want to watch the stream at quality that matches the streamer's bitrate, so that I do not get the soft-720p Discord cap.
3. As a moderator, I want to revoke a stream key instantly when a streamer goes rogue, so that we never re-broadcast banned content.

## 3. Goals & Non-Goals

**Goals**
- One-click "Get Stream Key" UI inside any voice / stage channel.
- RTMP, RTMPS, SRT, and WHIP ingest at up to 1080p60 / 8 Mbps for v1.
- HLS output URL the viewer side can fall back to (LL-HLS, 2 s segments).
- ABR ladder: 1080p / 720p / 480p / audio-only.
- Stream-key rotation, revoke, and per-server quota.

**Non-Goals (v1)**
- Re-streaming to external services (covered later in `multi-platform-restream`).
- DVR / scrubbing during a live stream — handled by `vod-storage`.
- Subscriber-only streams — gated by entitlements feature.

## 4. Scope (v1)

- [ ] Server setting: enable streaming + per-channel toggle.
- [ ] `streams` row created lazily on first publish; deleted 24 h after disconnect if no VOD.
- [ ] Ingress endpoint provisioned via LiveKit Ingress API (RTMP_INPUT, WHIP_INPUT).
- [ ] Stream key stored hashed (argon2id) — only the prefix is shown after the first reveal.
- [ ] Live indicator on channel; viewer count via Centrifugo `stream:<id>`.
- [ ] HLS playlist served at `https://hls.flicko.app/s/<id>.m3u8` with signed cookie auth.
- [ ] Mobile player: ExoPlayer (Android) / AVPlayer (iOS) via `video_player` + `better_player`.
- [ ] Latency budget: <2.5 s glass-to-glass on LL-HLS, <800 ms on SFU.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Streams started / week | 5,000 within 60 d | `streams.created` event |
| Median ingest bitrate | ≥4.5 Mbps | LiveKit metrics |
| Viewer p99 join latency | <3 s | client OTel |
| % concurrent streams reaching ABR | ≥70% | LiveKit Egress |
| Cost per concurrent viewer-hour | <$0.0009 | infra spend / `stream_metrics` |

## 6. Open Questions / Risks

- **Stream-key leakage** — store hashed, rotate on suspicious geo change, kill-switch on >3 simultaneous publishers per key.
- **Ingest region selection** — map streamer's RTT to nearest LiveKit Cloud region; document the four regions in the UI.
- **DMCA pass-through** — we do not transcode audio for fingerprinting in v1; legal sign-off required before GA.
- **Console encoders** stuck on RTMP-FLV — confirm LiveKit Ingress accepts vanilla FLV-AAC.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord Go Live | App-only screenshare, 720p60 cap, no RTMP | True RTMP ingest, ABR, hardware encoders |
| Twitch | Excellent ingest, no community channels | Streaming sits inside the same chat as the community |
| YouTube Live | RTMP + HLS, no chat/voice fabric | Native voice + chat + donations + clips in one app |
| Owncast | Self-host RTMP → HLS | Multi-tenant, hosted, integrated with social graph |

## 8. Rollout

- Internal dogfood for two weeks with the engineering team's "after-hours" server.
- 1% beta restricted to verified servers with ≥50 members.
- Canary 10% → 50% → 100% over 14 days, watching ingest error rate and Egress cost.
- Kill switch: `feature.native_rtmp_streaming.enabled` (Doppler).
- Per-server soft cap of 3 concurrent streams during canary.
