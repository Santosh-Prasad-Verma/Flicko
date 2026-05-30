# IMPL: Public REST API

## Phases
- P0 (week 1-2): migration 242, oauth-server skeleton, app + token CRUD.
- P1 (week 3-4): api-gateway with auth middleware, scope check, problem+json errors.
- P2 (week 5-6): rate limiter (Redis sliding window) + per-route overrides.
- P3 (week 7-8): read endpoints (servers, channels, messages, members, presence).
- P4 (week 9-10): write endpoints, idempotency-key middleware, audit log.
- P5 (week 11-12): webhook-dispatcher, HMAC, retries, circuit breaker.
- P6 (week 13-14): OpenAPI spec autogen + docs portal + sandbox.
- P7 (week 15): partner beta, GA.

## Backend Tasks
- `backend/internal/oauth/authorize.go` consent UI handler, code issuance.
- `backend/internal/oauth/token.go` token + refresh + introspect + revoke + jwks.
- `backend/internal/oauth/pkce.go` S256 verifier check.
- `backend/internal/oauth/family.go` refresh family rotation, compromise detection.
- `backend/internal/api/middleware/auth.go` Bearer parser, scope check.
- `backend/internal/api/middleware/ratelimit.go` Redis sliding window.
- `backend/internal/api/middleware/idempotency.go` 24h dedupe, 409 on conflict.
- `backend/internal/api/middleware/version.go` Flicko-Api-Version header pinning.
- `backend/internal/api/middleware/audit.go` per-request log line.
- `backend/internal/api/v1/servers.go` list/get.
- `backend/internal/api/v1/channels.go`.
- `backend/internal/api/v1/messages.go` list/post/edit/delete.
- `backend/internal/api/v1/members.go`.
- `backend/internal/api/v1/reactions.go`.
- `backend/internal/api/v1/plugins.go` (proxy to plugin-registry).
- `backend/internal/api/v1/store.go` (proxy to store-api).
- `backend/internal/api/v1/webhooks.go`.
- `backend/cmd/webhook-dispatcher/main.go` NATS consumer, signed POST, retries.
- `backend/internal/openapi/gen.go` reads handler tags, emits openapi.json.
- `backend/db/migrations/242_public_api.sql`.

## Docs Portal (Web)
- `web/apps/developer/src/routes/index.tsx` home + quickstart.
- `web/apps/developer/src/routes/apps/index.tsx` apps list.
- `web/apps/developer/src/routes/apps/[id].tsx` detail with credentials, scopes, rate-limit usage.
- `web/apps/developer/src/routes/playground.tsx` sandbox runner.
- `web/apps/developer/src/routes/spec.tsx` Stoplight Elements over openapi.json.
- `web/apps/developer/src/routes/oauth/authorize.tsx` consent screen.
- Static deploy on Vercel free tier.

## CLI
- `tools/flk/cmd/auth.go` device flow + token cache for CLI users.
- `tools/flk/cmd/api.go` `flk api GET /v1/servers` style invocation.

## SDK Stubs (post-GA)
- `sdks/js` TypeScript client generated from openapi.
- `sdks/python` async client generated from openapi.
- Generation in CI on each spec change.

## Test Plan
- Unit: PKCE S256 verify, refresh family rotation, sliding window math, idempotency dedupe, problem+json shape.
- Integration: full OAuth happy path including scope downgrade, refresh rotation, revoke.
- Conformance: openapi-validator on every endpoint response in CI.
- Load: 5k rps on read endpoints, p95 under 120 ms; 1k rps on writes, p95 under 250 ms.
- Webhook: 99% delivered within 30 s under 1k events/s, no duplicate after retries.
- Security: scope escalation rejected, redirect URI exact match, refresh family compromise detection trips on second use, HMAC verify rejects tampered body.
- Rate limit: app cap, user cap, ip cap each independently triggerable; headers correct; 429 includes Retry-After.
- Versioning: deprecated version returns Sunset header 6 mo before removal; removed version returns 410.

## Cost: $0
- Reuses existing Postgres, Redis, NATS, Go runtime; no new infra.
- Docs portal hosted on Vercel free tier; OpenAPI rendered with OSS Stoplight Elements.
- OAuth + JWKS in-process; no third-party identity provider.
- Webhook dispatcher horizontal-scales on existing worker pool.
- Spec autogen from handler annotations, no commercial schema tooling.

## Rollout
- Internal apps switch from gRPC to public API as dogfood (week 14).
- Partner beta with 25 invited apps; require security questionnaire.
- GA with public app registration, $0 fee.
- Soft-deprecate any legacy session-token endpoints over 12 months.

## Open Tickets
- FLK-API-301 oauth server
- FLK-API-302 gateway middleware
- FLK-API-303 rate limiter
- FLK-API-304 read endpoints
- FLK-API-305 write endpoints + idempotency
- FLK-API-306 webhooks
- FLK-API-307 docs portal
- FLK-API-310 SDKs
