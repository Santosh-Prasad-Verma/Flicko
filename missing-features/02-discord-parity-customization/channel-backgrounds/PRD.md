# Channel Backgrounds — Product Requirements

> **One-line:** Server admins upload a custom background image per channel; clients render it behind chat with opacity tuning.
> **Status:** Missing — to build
> **Category:** 02-discord-parity-customization
> **Effort:** M
> **Priority:** P1

## 1. Problem

Discord ships per-server "Server Banner" and Nitro-only "Server Profile" images, but **per-channel backgrounds are absent on Discord** and frequently requested. Telegram has per-chat wallpapers and dominates that vibe-driven aesthetic. Flicko's chat surface today renders as a flat gray-on-dark slab; visiting twenty different channels in a server is visually identical, which makes mid-sized servers feel like an inbox.

Evidence:
- 87 entries in our `#feedback` Slack channel ask for "channel themes" (Q4 2025–Q1 2026).
- Top voted item on our public Discourse: "Let mods set a vibe per channel" (412 upvotes).
- 6 of 8 community-event-channel admins on dogfood pinned a background image as the first message because they couldn't set one as channel art.

The unique angle: per-channel (not per-server, not per-user). A `#announcements` channel can feel official; a `#fan-art` channel can feel playful; both are in the same server.

## 2. Users & Use Cases

- **Primary persona:** Liam, 28, mod of a 5k-member gaming server. Runs distinct channels for ranked, casual, fan-art, and off-topic. Wants each to look different.
- **Secondary personas:**
  - Aesthetic-driven server owners (book clubs, k-pop, study groups).
  - Members who join those servers and want backgrounds to *not* harm readability.
  - Mobile-data-conscious users who want low-res or off entirely.

Top 3 jobs-to-be-done:
1. As a server admin, I want to set a background image per channel, so members feel they've moved between rooms.
2. As a member with poor eyesight, I want to dim or disable backgrounds so message text stays legible.
3. As a mod uploading a 4MB JPEG, I want a fast preview and a confirmation that members on slow data won't suffer.

## 3. Goals & Non-Goals

**Goals**
- Admins with `MANAGE_CHANNEL` permission can upload one image per channel.
- Auto-generated variants: `original` (max 1920×1080, JPEG quality 85), `mobile` (max 720p), `blurred` (kawase blur radius 24, ~80KB), `placeholder` (32×18 BlurHash string).
- Client renders background behind message list with member-controlled opacity 0–80% (default 30% dark / 12% light).
- Member can disable backgrounds globally (data-saver, accessibility).
- Image moderation pre-publish: hash check against existing CSAM/banned hashes (PhotoDNA-style via `safe_browsing_service`).

**Non-Goals (out of scope for v1)**
- Animated / video / Lottie backgrounds.
- Per-member background overrides per channel.
- Audio.
- Generative-AI background creation (revisit in 03-ai).
- Dark/light auto-recolor of background.
- Markdown-style inline message-bubble theming.

## 4. Scope (v1)

- [x] `channel_backgrounds` table with FK to `channels`.
- [x] Appwrite bucket `channel-backgrounds` with 4 file IDs per row.
- [x] `POST /api/v1/channels/:id/background` (multipart) → uploads + creates variants.
- [x] `DELETE /api/v1/channels/:id/background`.
- [x] `GET /api/v1/channels/:id/background` (public to channel members).
- [x] Realtime push on `channel:{id}` topic with new variant URLs.
- [x] Flutter: `ChannelBackgroundLayer` widget below `MessageList`.
- [x] Member opacity slider in `ChatSettings` (per-channel + global).
- [x] Hash + size + dimension validation; reject > 8 MB, > 4096 px any side.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Channels with background set | 8% of mod-managed channels in 30d | DB query |
| Members keeping backgrounds on (default) | ≥85% | settings telemetry |
| Median image size after variants | <250 KB combined for mobile load | Appwrite analytics |
| Time-to-first-paint regression | <40 ms p95 vs control | Sentry perf |
| Uploads rejected by moderation | <0.5% (false-positive ceiling) | service log |
| Cost per server / month | <$0.02 | Appwrite egress + storage |

## 6. Open Questions / Risks

- **Readability:** does default 30% opacity over busy images still pass AA? Mitigation: server-side image-mean-luminance check; if ambiguous, force a translucent dark scrim layer client-side.
- **Bandwidth:** mobile users on 3G. Mitigation: ship `mobile` variant first, BlurHash placeholder, and respect `Save-Data` header.
- **Moderation:** image-hash check needs a service we haven't shipped. We will reuse `services/safe_browsing_service.go` SHA256 hash list and add a worker stub that consults a published hash feed.
- **Storage growth:** 4 variants per channel, ~500 KB total. At 1M channels that's 500 GB. Mitigation: only store after admin actually uploads (most channels won't).

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Per-server banner only; no channel image | Per-channel granularity |
| Telegram | Per-chat wallpaper (1:1 chats only) | Group/channel parity |
| Slack | None | Pure parity win |
| Revolt | Per-channel allowed via custom CSS | Guard-railed default UX |

## 8. Rollout

- Internal dogfood (3 staff servers).
- 1% beta cohort of servers with > 100 members for one week.
- 10% → 50% → 100% over the following 10 days.
- Kill switch flag: `feature.channel_backgrounds.enabled`.
- Per-server kill switch: existing `server_settings.feature_overrides`.

## 9. Dependencies

- Appwrite storage (already used for avatars/attachments).
- `safe_browsing_service.go` hash check (existing).
- `permissions_service.go::HasChannelPermission` for `MANAGE_CHANNEL`.
- Centrifugo channel `channel:{channelID}` (already in use).
