# TRD: Zapier and Make Integration

## Architecture
Three subsystems.

1. **OAuth Provider** at `backend/internal/oauth/`. Issues tokens scoped to specific servers and permissions for Zapier and Make to call Flicko on behalf of an admin.
2. **Trigger Pipeline** at `backend/internal/zapier/triggers/`. Listens to internal NATS subjects, evaluates subscription filters, and POSTs to subscriber URLs (Zapier and Make).
3. **Action API** at `backend/internal/zapier/actions/`. Public REST endpoints that Zapier and Make call to perform Flicko operations.

Plus partner-side definitions:
- **Zapier App Definition** at `integrations/zapier/`. JS files using the Zapier Platform CLI (`zapier-platform-core`).
- **Make App Definition** at `integrations/make/`. JSON manifest for Make's app builder.

## OAuth 2.0 Flow
- Authorization endpoint: `GET /oauth/authorize` with `client_id`, `redirect_uri`, `scope`, `state`.
- Consent screen lists the servers the user can grant, the requested scopes (`messages.send`, `members.read`, etc), and the integration name.
- Token endpoint: `POST /oauth/token` exchanges code for an access token (1 hour TTL) and refresh token (30 days, rotating).
- Tokens are stored hashed (sha256) in `oauth_tokens`.
- Per-token scope and server allowlist enforced on every API call.

## Trigger Pipeline
- A Zap or Scenario subscribes by calling `POST /api/v1/zap/subscribe` with `{event_type, server_id, target_url, filters}`.
- Backend writes to `zapier_subscriptions`. Refreshed in-memory every 30 seconds.
- When a NATS event matches, dispatcher evaluates filters (simple JSON path equals, contains, regex), then enqueues a delivery job.
- Delivery worker POSTs JSON payload to `target_url` with HMAC signature header `X-Flicko-Signature` (sha256 of body with shared secret).
- Retry policy: 1m, 5m, 25m, 2h, 12h. After 24h dead-letter to `zap_dead_letter` table.

## Action API
Public routes under `/api/v1/zap/actions/`. Each action endpoint:
- Validates OAuth token scope.
- Validates that the request server is in the token's allowlist.
- Applies rate limit (per-token bucket: 600 requests per hour Pro, 6000 Enterprise).
- Calls the same internal service the in-app UI uses; no direct DB writes from this layer.

Sample endpoints:
- `POST /api/v1/zap/actions/messages/send`
- `POST /api/v1/zap/actions/messages/dm`
- `POST /api/v1/zap/actions/members/add_role`
- `POST /api/v1/zap/actions/channels/create`
- `GET /api/v1/zap/searches/users?email=...`
- `GET /api/v1/zap/searches/channels?name=...`

## Zapier App Definition
File `integrations/zapier/index.js` declares:
- `authentication`: oauth2 with `authorizeUrl`, `getAccessToken`, `refreshAccessToken`, and a test call to `/api/v1/me`.
- `triggers`: one entry per trigger type with `key`, `display`, `operation` ({type: 'hook', performSubscribe, performUnsubscribe, perform, performList}).
- `creates`: one entry per action.
- `searches`: lookup endpoints.
- Schema fields per trigger and action with type hints (`string`, `dynamic` for channel/role pickers).

Dynamic dropdowns: channel and role pickers fetch via `GET /api/v1/zap/searches/channels?server_id={{bundle.inputData.server_id}}`.

## Make App Definition
JSON manifest under `integrations/make/app.json`. Modules of type `instant-trigger` (webhook subscribe), `action`, and `search`. Connection type `oauth2`. Communication blocks point to the same Flicko endpoints.

## Loop Detection
A bloom filter keyed by `(subscription_id, payload_hash)` sliding over 60 seconds. If 50+ hits, the subscription is paused and the admin notified. Counters in `zap_triggers` table updated nightly.

## Security
- Refresh tokens rotate on every use; previous token invalidated.
- Webhook target URLs must be HTTPS. Localhost and private IP ranges rejected at submission.
- HMAC signature on outbound webhooks; samples in our docs show how to verify.
- Action API requires `Idempotency-Key` header for create operations. Duplicate keys within 24h return the cached response.

## Migration 244
Adds `oauth_clients`, `oauth_tokens`, `zapier_subscriptions`, `zap_triggers`, `zap_actions`, `zap_dead_letter` tables. Indexes on subscription event type and server id.

## Performance Targets
- Trigger fire to outbound POST under 1 second p95.
- Action API call under 300 ms p95 (excluding partner network).
- Subscription index refresh under 200 ms.

## Partner SLAs
Both Zapier and Make publish their own SLAs. We aim to respond to partner platform reviews within 5 business days during certification.
