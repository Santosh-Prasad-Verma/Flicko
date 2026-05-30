# TRD: Embeddable Widget

## Architecture
Three pieces.

1. **Loader** (`widget-embed/`): tiny vanilla-JS bundle (under 4 KB gz) hosted at `https://embed.flicko.app/v1/loader.js`. Site owners include this script with a single `<div data-flicko-embed>` element.
2. **Iframe App** at `chat.flicko.app/embed`: a stripped-down React build of the chat reader, served as a static SPA. Receives config via URL params and `postMessage`.
3. **Embed Backend** at `backend/internal/embed/`: REST endpoints for key management, public read-only feed, and presence; CORS allowlist enforcement.

## Loader Behavior
- Reads attributes from the placeholder div: `data-key`, `data-channel`, `data-theme`, `data-height`.
- Creates a sandboxed iframe with `sandbox="allow-scripts allow-same-origin allow-popups"` and `allow="clipboard-write"`.
- Sets `src` to `https://chat.flicko.app/embed?key=...&channel=...&theme=...&parent=<encoded host origin>`.
- Listens for `postMessage` events from the iframe to handle resize and join CTA clicks.
- No external dependencies. Hand-written, ES2020.

## Iframe App
- Built with Vite, React 18, single bundle. Code-split heavy components.
- On load, calls `GET /api/v1/embed/init?key=K&channel=C` with `Origin: <parent>`.
- Backend validates key + origin allowlist, returns: server name, channel name, latest 50 messages, presence count, branding config, Centrifugo connection token (read-only, scoped).
- Subscribes to Centrifugo channel `embed:{key}:{channel}` for new messages and presence updates.
- Renders: header (server avatar + name), message list (virtualized), presence pill, "Join the conversation" CTA, optional Flicko badge.

## Backend Endpoints
All under `/api/v1/embed/`.
- `POST /keys` admin-only: create embed key, body `{server_id, name, allowed_origins, allowed_channels, theme}`.
- `GET /keys` admin: list keys.
- `PATCH /keys/:id` admin: update origins, channels, theme.
- `POST /keys/:id/rotate` admin: regenerate the secret value.
- `DELETE /keys/:id` admin: revoke.
- `GET /init?key=K&channel=C` public: returns initial payload, requires `Origin` header to match allowlist.
- `GET /messages?key=K&channel=C&before=...` public: paginated history (max 50 per request).
- `POST /token` public: exchange embed key for Centrifugo subscription token, validates origin.

## CORS and Origin Validation
- `Origin` header on all public endpoints. If not in `embed_origins` for the key, return 403.
- Wildcards permitted: `https://*.example.com`. Validation in Go via custom matcher (no regex injection).
- Localhost only when key is in dev mode (`is_dev=true`).
- All public endpoints set `Access-Control-Allow-Origin: <validated origin>` (echoed, never `*`).

## Centrifugo Subscription Tokens
- Tokens are JWTs signed with the embed-specific secret, payload `{sub, channels: ["embed:K:C"], exp, ttl}`. TTL 5 minutes.
- Tokens grant `read` only. Centrifugo namespace `embed:` configured with publish disabled, presence enabled, history disabled.

## Rate Limiting
- Per-key view counter ticks up on `/init` calls. Free tier capped at 100k per month, enforced by token bucket plus monthly counter.
- Per-IP rate limit on `/init` (60 per minute) and `/messages` (120 per minute).

## Privacy
- The widget surfaces only messages from channels explicitly added to the key's `allowed_channels` list.
- User avatars render from a hashed CDN path; no email or identifying metadata returned.
- Messages from members with "hide_from_embeds" preference are filtered out server-side.

## Migration 245
Adds `embed_keys` and `embed_origins` tables, plus `embed_view_counters` aggregate table.

## Performance Targets
- Loader script size under 4 KB gz.
- Iframe initial load under 1.2 seconds p95 (cable, cold cache).
- `GET /init` p95 under 100 ms.
- New message Centrifugo push to render under 250 ms.

## Build Pipeline
- `widget-embed/` builds via esbuild with mangling and gzip pre-compression.
- Output deployed to S3 with CloudFront in front. CDN caches loader for 1 hour, busts on `vN` path version.
- `chat.flicko.app/embed` is a separate Vite build deployed alongside main app, asset hashing for long-term cache.

## Failure Modes
- Bad key: iframe shows neutral fallback "This Flicko widget is not available". No PII leaked.
- Origin mismatch: same neutral fallback.
- Centrifugo down: iframe falls back to long polling `/messages?since=...` every 4 seconds with banner "reconnecting".
- Backend 5xx: stale messages remain visible; "Refreshing" pill in header.

## Versioning
- Loader URL is versioned (`/v1/loader.js`). Breaking changes ship as `v2/`.
- Iframe app reads `version` from query and serves a compatible build snapshot for at least 12 months after a major bump.
