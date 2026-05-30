# TRD — Stream Chat Overlay

## 1. Architecture Overview
The chat path is a write-through pipeline: client publish → Go API ingest → validation/rate-limit → Centrifugo broadcast → async Postgres persistence. The overlay is a static SPA that subscribes to the same Centrifugo channel via a signed JWT and renders messages with a CSS animation pipeline.

```
[Mobile/Web Client] --HTTPS--> [chat-api (Go)]
        |                         |---> [Redis: rate-limit, slowmode, mode-flags]
        |                         |---> [Centrifugo cluster] --WSS--> [Overlay SPA]
        |                                       |
        |                                       +---> [persist worker] --COPY--> [Postgres]
        +-----WSS (read)------> [Centrifugo cluster]
```

## 2. Components
- `chat-api`: Go service exposing REST `POST /v1/streams/{id}/chat` and `POST /v1/streams/{id}/chat/mod`. Authenticates with Supabase JWT.
- `chat-persist`: background worker (same binary, separate goroutine pool) consuming a Centrifugo HTTP proxy hook. Writes to `stream_chat_messages` via COPY in 250 ms windows.
- `chat-mod`: handler set for moderator actions, writes to `stream_chat_bans` and broadcasts control frames.
- `overlay-web`: static bundle hosted on Cloudflare Pages; subscribes to Centrifugo with overlay-scoped JWT.
- `centrifugo`: 3-node cluster with NATS broker (reusing the platform NATS for engine sync), namespace `stream-chat`.
- `redis-chat`: dedicated Redis (cluster mode, 3 shards) for slowmode buckets and mode flags. Keys keyed by `chat:{stream_id}:*`.

## 3. Centrifugo Configuration
- Namespace `stream-chat` with `presence: true`, `history_size: 50`, `history_ttl: 1h`, `recover: true`, `position: true`.
- Channel pattern `stream-chat:<stream_id>` for messages, `stream-chat-ctrl:<stream_id>` for mod control frames.
- Engine: NATS broker for inter-node fan-out, Redis presence backend.
- Connection JWT signed by `chat-api` using HS256 secret rotated every 7 days.

## 4. API Surface
- `POST /v1/streams/{id}/chat` body `{text, client_id, reply_to?}`. Returns `{message_id, ts}`. Rejects with 429 on slowmode, 403 on ban/follower-only.
- `POST /v1/streams/{id}/chat/mod/timeout` body `{user_id, duration_seconds, reason}`.
- `POST /v1/streams/{id}/chat/mod/ban` body `{user_id, reason}`.
- `POST /v1/streams/{id}/chat/mod/delete` body `{message_id}`.
- `POST /v1/streams/{id}/chat/mod/mode` body `{slowmode_seconds?, emote_only?, follower_only_minutes?}`.
- `GET /v1/streams/{id}/chat/emotes` returns global + channel emotes.
- `GET /v1/streams/{id}/chat/overlay-token` returns short-lived JWT for browser source URL.

## 5. Rate Limiting and Slowmode
- Token bucket per `(stream_id, user_id)` stored in Redis: `INCR chat:{sid}:rl:{uid}` with `EXPIRE`.
- Default: 5 messages per 10 seconds for non-mods, 30 per 10 seconds for mods.
- Slowmode adds a hard floor: `SET chat:{sid}:sm:{uid} 1 EX <seconds> NX` — if SET fails, return 429 with `retry_after`.
- Emote-only check uses a regex stripping `:[a-z0-9_-]{2,32}:` tokens; if remaining text trim length > 0, reject.

## 6. Moderation
- `stream_chat_bans` rows checked on every publish via Redis-cached lookup (`chat:{sid}:ban:{uid}` TTL 60s).
- Timeout writes a row with `expires_at = now() + interval`; ban writes `expires_at = NULL`.
- Delete broadcasts a control frame `{op:'delete', message_id}` over `stream-chat-ctrl:<id>` and soft-deletes the row (`deleted_at`).
- Mod actions audited in `audit_log` with `actor_user_id`, `target_user_id`, `action`, `payload`.

## 7. Overlay Web
- Vanilla TypeScript, no framework, bundled with esbuild. Total payload 78 KB gzipped.
- Connects to Centrifugo with `https://centrifugo.flicko.app/connection/websocket`.
- Renders messages into a stack of `.bubble` divs; each animates in via CSS `transform: translateY(8px) -> 0` + opacity over 220 ms.
- Auto-fade after 30 seconds (configurable via query param `?fade=60`).
- Theme picked via `?theme=neon|minimal|default`; custom CSS via `?css=<url>` (Pro only, validated against allowlist).

## 8. Persistence Worker
- Subscribes to Centrifugo HTTP `publish` proxy hook so the API only writes once.
- Buffers 256 messages or 250 ms whichever first; issues a single `COPY stream_chat_messages FROM STDIN`.
- On Postgres failure, drops to DLQ NATS subject `chat.persist.dlq` with 24h retention.

## 9. Scaling Targets
- 5,000 CCU per stream, 100 concurrent live streams = 500k WS connections platform-wide.
- Sustained 5k msg/s ingest, 50k msg/s fan-out at peak.
- Centrifugo nodes sized 4 vCPU / 8 GB; Redis cluster 3x cache.r7g.large.

## 10. Observability
- Prometheus metrics: `chat_publish_total`, `chat_publish_latency_ms`, `chat_drop_total`, `chat_ban_active`.
- Tracing via OTLP, span per publish covering ingest → broadcast → ack.
- Structured logs with `stream_id`, `user_id`, `mod_action` fields.

## 11. Failure Modes
- Centrifugo partition: client SDK auto-recovers with `recover: true`, replay last 50 messages.
- Redis outage: rate-limit fails open with a global 1 msg/sec cap enforced in-process.
- Postgres outage: persistence DLQ buffers; chat continues uninterrupted.
- Mod action failure: API returns 503 and the dashboard shows a retry banner.

## 12. Security
- Overlay JWT scoped to `stream_id` and channel name; rejected by Centrifugo if mismatch.
- Origin pinning on overlay URL (Referer must match `obs-browser://*` or allowlisted domains for browser sources, soft-checked).
- HTML escape all message bodies on render; emotes injected via `<img alt>` with sanitized URLs.
- CSP `default-src 'none'; img-src https://cdn.flicko.app; style-src 'self' 'nonce-*'; script-src 'self'`.
