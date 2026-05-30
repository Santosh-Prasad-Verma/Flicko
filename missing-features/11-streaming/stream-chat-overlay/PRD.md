# PRD — Stream Chat Overlay

## 1. Problem Statement
Flicko streamers running RTMP broadcasts have no first-class way to surface live chat inside their video composition. Today they paste an external Twitch/YouTube widget into OBS, which fragments identity (Flicko users vs anonymous chatters), bypasses Flicko moderation, and prevents reactions on Flicko-only emotes. Viewers on the Flicko mobile/web client cannot meaningfully participate either, because the existing channel chat is decoupled from the live stream surface and lacks slowmode, emote-only mode, and stream-scoped bans.

## 2. Goals
- Provide a real-time chat experience attached to every Flicko live stream, sharing identity with the platform.
- Expose a transparent web overlay (browser source) that streamers can drop into OBS, vMix, Streamlabs Desktop, or Restream.
- Give moderators stream-scoped tools: timeout, ban, delete message, slowmode, emote-only, follower-only.
- Support Flicko-native and channel-uploaded emotes with autocomplete.
- Sustain 5,000 concurrent chatters per stream with sub-500 ms p95 fan-out latency.

## 3. Non-Goals
- Cross-platform chat relay (Twitch/YouTube simulcast bridging) ships in a later track.
- Threaded replies and message reactions remain a regular channel feature, not stream chat.
- AI moderation (toxicity scoring) is scoped separately under the AutoMod feature.
- Voice chat overlays — handled by stage channels.

## 4. User Stories
- As a streamer, I add a single browser-source URL to OBS and chat appears with my brand colors and animations.
- As a streamer, I toggle slowmode (5s/15s/30s/1m/5m) when chat gets rowdy without leaving the dashboard.
- As a moderator, I can `/timeout @user 10m`, `/ban @user`, or click a message to delete it.
- As a viewer on mobile, I tap an emote in the picker and it appears in the overlay within 500 ms.
- As a viewer with a slowmode penalty, I see a countdown on the send button and a tooltip explaining why.
- As a streamer, I switch to emote-only mode for a hype moment and only emote messages render.

## 5. Success Metrics
- p95 message fan-out latency under 500 ms measured from publish to overlay render.
- 99.5% of messages delivered to all subscribed viewers (loss budget tracked via Centrifugo presence ack).
- Mod action median time-to-effect under 800 ms (delete propagates and overlay removes the bubble).
- 40% of live streams use the overlay within 60 days of GA.
- Less than 0.5% chat session disconnects per minute of stream (excluding viewer-side network drops).

## 6. Functional Requirements
- F1: Send/receive chat messages over Centrifugo channel `stream-chat:<stream_id>`.
- F2: Persist messages to `stream_chat_messages` for 30 days for replay and audit.
- F3: Slowmode enforcement via per-user token bucket keyed on `(stream_id, user_id)` in Redis.
- F4: Emote-only mode — server rejects messages whose text-stripped body is non-empty.
- F5: Follower-only mode — server checks `channel_followers` membership and minimum follow age.
- F6: Mod commands: `/timeout`, `/ban`, `/unban`, `/delete <msg_id>`, `/clear`, `/slow <sec>`, `/emoteonly`, `/followonly <minutes>`.
- F7: Emote picker fed by `stream_chat_emotes` (channel-owned + global Flicko set).
- F8: Public overlay URL `https://stream.flicko.app/overlay/<stream_id>?token=<signed>` with no auth UI.
- F9: Overlay theme presets (default, neon, minimal) plus custom CSS injection for Pro tier.
- F10: Replay-on-rejoin — late viewers see the last 50 messages on connect.

## 7. Non-Functional Requirements
- Centrifugo deployment with at least 3 nodes behind an NLB, sticky by `stream_id` hash.
- Postgres write amplification kept below 1 row per message via batched COPY every 250 ms.
- Overlay HTML/CSS/JS bundle under 80 KB gzipped to load fast on low-end OBS machines.
- WCAG 2.1 AA on the dashboard chat panel; overlay is presentational only (aria-hidden=true).
- All Cloud Functions and overlay traffic served via TLS 1.3; signed JWT for overlay tokens (HS256, 24h TTL).

## 8. Risks & Mitigations
- Risk: Centrifugo node failure mid-stream. Mitigation: client auto-reconnect with exponential backoff and replay buffer on the server.
- Risk: Spam floods overwhelming Postgres. Mitigation: rate-limit at edge (5 msg/10s default), drop persistence for messages already deleted by AutoMod.
- Risk: Overlay token leakage. Mitigation: bind tokens to stream_id and ip-class, rotate on stream restart.
- Risk: Emote bloat from large channel uploads. Mitigation: 256 KB per emote, 200 emotes per channel cap, lazy load on picker.

## 9. Out-of-Scope (v1)
- Polls, predictions, and giveaways embedded in chat (separate engagement track).
- Sub-only chat — gated behind subscriptions feature, not yet GA.
- Whispers/DMs from overlay context (use channel DMs).

## 10. Release Plan
- Internal alpha with 5 partner streamers for two weeks.
- Public beta with feature flag `chat_overlay_v1` to all Pro creators.
- GA when fan-out p95 holds under 500 ms across two consecutive weekly load tests at 5k CCU.
