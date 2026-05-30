# APPFLOW — Stream Chat Overlay

## 1. Streamer Adds Overlay to OBS
1. Streamer opens Dashboard → Stream → Chat Overlay tab.
2. Selects theme (default/neon/minimal) and fade timeout, clicks "Generate URL".
3. Frontend calls `GET /v1/streams/{id}/chat/overlay-token` which returns `{token, url}` where `url = https://stream.flicko.app/overlay/{stream_id}?token=...&theme=neon`.
4. Streamer copies URL into OBS browser source (1920x1080 transparent).
5. Overlay SPA loads, validates token with `chat-api`, then opens Centrifugo subscription with the token as connection JWT.
6. Centrifugo replays last 50 messages so test rooms show history immediately.

## 2. Viewer Sends Message
1. Viewer types in composer, hits Enter.
2. Client posts `POST /v1/streams/{id}/chat` with `{text, client_id}` (client_id is a ULID for dedup).
3. `chat-api`: checks Supabase JWT → resolves `user_id` → fetches mode flags from Redis → checks ban/timeout cache → checks slowmode bucket.
4. If allowed, calls Centrifugo `publish` API to `stream-chat:<id>` with payload `{message_id, user_id, username, badges, text, emotes, ts}`.
5. Centrifugo broadcasts to all subscribers; persistence proxy hook fires → buffer worker batches into Postgres.
6. Client receives its own publish via Centrifugo (server confirms ordering) and replaces optimistic bubble.

## 3. Overlay Receives Message
1. Centrifugo pushes the message frame to the overlay WS.
2. Overlay JS deserializes, sanitizes text, replaces emote codes with `<img>` nodes against `cdn.flicko.app`.
3. New `<div class="bubble">` appended; CSS animation triggers slide+fade in.
4. Setup `setTimeout(removeBubble, fadeMs)` to fade out and remove.
5. If overlay receives a `delete` control frame from `stream-chat-ctrl:<id>`, matching bubble is removed instantly with a 120 ms shrink animation.

## 4. Slowmode Activation
1. Streamer toggles "Slowmode 30s" chip in dashboard.
2. UI calls `POST /v1/streams/{id}/chat/mod/mode` with `{slowmode_seconds: 30}`.
3. `chat-api` writes to Redis `chat:{sid}:mode slowmode 30` and broadcasts a `mode-change` control frame.
4. All viewer clients show the slowmode indicator and the dashboard chip turns active.
5. Subsequent publishes use the new TTL on `chat:{sid}:sm:{uid}`.

## 5. Moderator Times Out a User
1. Mod hovers a message, clicks Timeout 10m.
2. Frontend calls `POST /v1/streams/{id}/chat/mod/timeout` with `{user_id, duration_seconds: 600, reason}`.
3. `chat-api` inserts into `stream_chat_bans` with `expires_at = now() + 10m`.
4. Cache `chat:{sid}:ban:{uid}` set with TTL matching expiry.
5. Audit log entry written.
6. Control frame `{op: 'timeout', user_id, expires_at}` broadcast — the target client disables its composer with countdown; mods see toast confirmation.

## 6. Late Joiner Replay
1. Viewer opens stream 20 minutes after start.
2. Centrifugo subscription includes `recover: true` so server replays last 50 messages from history buffer.
3. Replayed messages render with a 0 ms fade-in (instant) and dim 70% opacity to indicate replay.
4. New live messages render at 100% opacity normally.

## 7. Reconnection
1. WS drops (network blip, Centrifugo node restart).
2. Centrifugo SDK retries with exponential backoff (250 ms → 4 s).
3. On reconnect, `recover: true` replays missed messages by stream position offset.
4. UI shows "Reconnecting..." amber banner during reconnect; clears on resume.
5. If reconnect fails for 60 s, banner turns red with manual "Retry" button.

## 8. Stream Ends
1. RTMP ingest stops, stream state moves to `ended`.
2. Background job archives chat: copies last 24h of `stream_chat_messages` to cold storage.
3. Centrifugo channel TTL expires after 1 h, dropping any lingering subscribers.
4. Overlay token revoked; URL returns "Stream is offline".
5. Dashboard chat panel switches to read-only archive view.

## 9. Spam Burst Mitigation
1. AutoMod detects 50+ identical messages in 30 s window.
2. Triggers automatic slowmode 5s for 5 minutes.
3. Notification banner sent to streamer: "Spam burst detected, slowmode auto-enabled".
4. Streamer can override via toolbar.

## 10. Pinning a Message
1. Mod clicks Pin on a bubble.
2. `POST /v1/streams/{id}/chat/mod/pin` with `{message_id}`.
3. Existing pin cleared (only one pinned at a time).
4. Control frame `{op: 'pin', message_id, payload}` broadcast.
5. Overlay and chat panels render the pin at the top with a pin icon and 200 ms scale-in.
6. Auto-unpin after 30 minutes unless extended.

## 11. Custom Emote Upload
1. Streamer goes to Channel Settings → Emotes.
2. Drops PNG/WebP up to 256 KB; client uploads to Supabase storage bucket `chat-emotes`.
3. `POST /v1/channels/{id}/emotes` registers row in `stream_chat_emotes` with `code`, `image_url`, `tier`.
4. Emote becomes available immediately to the channel; picker refreshes via SWR.
5. Globally-allowed emotes sync to other channels by emote moderation team approval.
