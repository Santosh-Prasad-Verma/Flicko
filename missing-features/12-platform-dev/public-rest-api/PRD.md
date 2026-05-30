# PRD: Public REST API

## Summary
A documented, versioned, OAuth2-secured public REST API for Flicko that exposes a curated subset of platform capabilities (servers, channels, messages, voice events, plugins, store) to external developers and to first-party clients. Spec is OpenAPI 3.1, generated from Go handlers. Auth uses OAuth2 authorization-code with PKCE plus scoped API tokens for server-to-server.

## Problem
Today integrations either reach into private gRPC, use the mobile app session token, or scrape. None of these are stable. Plugin authors want to talk to Flicko from their own backend; CRM/CI tools want to send messages on a schedule; partner products want to show server status. We need a stable contract, predictable rate limits, and revocable credentials.

## Jobs To Be Done
- As a partner developer, I want to register an app, get a client id/secret, and call `POST /messages` with a token in 10 minutes.
- As a server admin, I want to authorize a third-party app with the smallest possible scope and revoke it later.
- As a Flicko platform operator, I want per-app and per-user rate limits I can tune at runtime.
- As a security engineer, I want an audit trail of every public API call by client and user.
- As a plugin author, I want the same endpoints to work whether I am running on-platform (capability tokens) or off-platform (OAuth).

## In Scope
- OAuth2 authorization-code with PKCE; refresh tokens.
- API tokens (long-lived, scoped, revocable) for server-to-server.
- OpenAPI 3.1 spec auto-generated; published at `/openapi.json` and rendered docs at `developer.flicko.io`.
- Endpoints: servers, channels, messages, members, reactions, presence, plugins (list/install), store (read), webhooks.
- Webhooks (outbound) signed with HMAC, replay protection.
- Versioning: header `Flicko-Api-Version: 2026-05-29` (date-pinned), default to most recent stable per app.
- Rate limits: per app, per user, per IP, sliding window.
- Error model: RFC 7807 problem+json.

## Out of Scope
- Voice media streaming (separate WebRTC API).
- Admin/internal endpoints.
- Bulk export beyond paginated reads.
- gRPC public endpoint (v2).

## Success Metrics
1. p95 latency under 120 ms for read endpoints, under 250 ms for write.
2. 99.95% monthly availability for `/v1/messages` and `/v1/servers/:id`.
3. 1,000 active OAuth apps within 12 months of GA.
4. Spec drift: 0 endpoints undocumented in production (CI-enforced).

## Competitive Landscape
| API | Auth | Versioning | Rate model | Webhooks |
|---|---|---|---|---|
| Discord API | Bearer + bot | URL `/v10` | Bucketed | Yes |
| Slack Web API | Bearer | None (deprecation notice) | Tier per method | Yes |
| Stripe API | Bearer | Date-pinned | Token bucket | Yes |
| Twilio | Basic + key | URL `/2010-04-01` | Per resource | Yes |
| Flicko (this) | OAuth2+PKCE / scoped tokens | Date-pinned header | Per app+user sliding | Yes (HMAC) |

## Risks
- Scope creep on day-1 endpoint set; lock to listed endpoints, defer rest.
- Rate limit gaming via multiple apps; mitigate with per-user secondary cap.
- Token leakage via mobile WebViews; require PKCE, refuse implicit grant.
- Webhook delivery storms after outage; cap retries 5 with exponential backoff and circuit breaker.

## Release Plan
- M1: OAuth provider, token issuance, OpenAPI scaffolding.
- M2: read endpoints with rate limit middleware.
- M3: write endpoints, webhooks.
- M4: docs portal, sandbox.
- M5: GA, partner program.

## Open Questions
- Whether to allow client-credentials grant for first-party use cases or restrict to PKCE only.
- Webhook signing key rotation cadence (default 90 days).
