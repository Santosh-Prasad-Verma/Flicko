# APPFLOW: Embeddable Widget

## Flow A: Admin creates an embed key
1. Admin opens `Server → Settings → Developers → Embeds`. Page calls `GET /api/v1/embed/keys?server_id=X`. Returns empty array.
2. Admin clicks "New embed key". Drawer opens.
3. Admin fills name "Marketing site", picks channels `#general` and `#announcements`, adds origin `https://example.com`, picks theme "auto", leaves dev mode off.
4. Admin clicks Save. SPA calls `POST /api/v1/embed/keys` with body. Backend inserts `embed_keys` row, fans-out to `embed_origins`, generates 32-byte random key with prefix `emb_live_`, stores SHA-256 hash.
5. Backend responds with raw key value (only shown once). SPA renders snippet card pre-filled with the key.
6. Admin copies snippet, pastes into their website's HTML before `</body>`.

## Flow B: Visitor loads the host page
1. Browser parses the host page, encounters `<script src="https://embed.flicko.app/v1/loader.js" async>`.
2. Loader downloads from CDN (cached, 4 KB gz).
3. Loader runs on `DOMContentLoaded`, finds all `<div data-flicko-embed>` elements.
4. For each placeholder, loader reads attributes, builds iframe URL, creates a sandboxed iframe with computed height. Inserts into the placeholder.
5. Iframe begins loading `chat.flicko.app/embed?key=...&channel=...&theme=...&parent=https%3A%2F%2Fexample.com`.

## Flow C: Iframe boots
1. Iframe SPA loads, reads URL params.
2. Calls `GET /api/v1/embed/init?key=K&channel=C` with `Origin: https://example.com`.
3. Backend looks up `embed_keys` by hashed key, joins `embed_origins`, validates origin against allowlist (with wildcard expansion).
4. If allowed, returns server name, channel meta, last 50 messages, presence count, branding config, Centrifugo subscription token (5 min TTL).
5. SPA renders skeleton, then full UI as soon as data arrives.
6. SPA opens Centrifugo connection, subscribes to `embed:{key}:{channel}`.

## Flow D: New message arrives
1. Member posts in `#general`. Existing message pipeline persists message and publishes to Centrifugo channels including `embed:{key}:{channel}` for every key that includes that channel.
2. Subscribed iframe receives the push, prepends to message list, animates in, scrolls if user is at bottom.
3. Presence count updates from periodic Centrifugo presence stats every 10 seconds.

## Flow E: Visitor clicks Join
1. Visitor clicks "Join Server". Iframe posts message to parent: `{type: "flicko:join-clicked", key: "emb_live_..."}`.
2. Iframe opens `https://flicko.app/invite/{server_slug}` in `_top`.
3. Loader on parent page receives the postMessage and fires an analytics event if the host has subscribed via `window.FlickoEmbed.on(...)` (optional API).

## Flow F: Origin mismatch
1. Bad actor copies snippet to `https://attacker.test`.
2. Iframe loads, calls `/init`. Backend sees `Origin: https://attacker.test`, no match in `embed_origins`. Returns 403 with neutral body.
3. Iframe shows neutral fallback "This Flicko widget is unavailable". Telemetry logs `origin_blocked` event with no PII.

## Flow G: Key rotation
1. Admin clicks "Rotate" on key row. Confirms modal.
2. Backend generates new key, updates the hashed value. Old key invalid effective immediately.
3. Existing iframe instances using old key fail their next Centrifugo refresh and show neutral fallback.
4. Admin must update the snippet on their website.

## Flow H: Centrifugo down (graceful degradation)
1. Iframe Centrifugo socket closes unexpectedly. Reconnect logic kicks in (3 attempts with backoff).
2. After 3 failures, switches to long polling mode: `GET /api/v1/embed/messages?key=K&channel=C&since=lastTs` every 4 seconds.
3. Header shows yellow "Reconnecting" pill until socket recovers.

## Flow I: Free tier view limit hit
1. Free server's monthly view counter reaches 100,000.
2. Subsequent `/init` calls return 429 with `{retry_after_days: 5}`.
3. Iframe shows soft fallback "This community has reached its monthly view limit. Try again later."
4. Admin sees red banner in Embeds page, with upgrade CTA.

## Flow J: Older messages on scroll
1. Visitor scrolls to top of message list.
2. iframe calls `GET /api/v1/embed/messages?key=K&channel=C&before=<oldestId>&limit=50`.
3. Backend returns next page (max 250 total per session).
4. Iframe prepends, preserves scroll position.

## Flow K: Hidden author preference
1. A member sets "Hide my messages from public embeds" in their privacy settings.
2. The message ingestion adds a `embed_visible=false` flag to messages from this member.
3. `/init` and `/messages` queries filter `embed_visible=true`.
4. Real-time pushes also skip these messages (Centrifugo channel publish gated by the flag).

## Flow L: Loader update
1. Loader is at `embed.flicko.app/v1/loader.js`. CloudFront cache 1 hour.
2. We deploy a backwards-compatible bug fix; CDN invalidation triggers refresh within minutes.
3. Breaking change ships at `v2/loader.js`; admins must update the snippet to opt in. `v1/` continues to serve for at least 12 months.
