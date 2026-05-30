# TRD: Public REST API

## Architecture
```
+-------------------------------------------------+
|  Edge (Cloudflare)                              |
|  - TLS, WAF, DDoS, IP rate limit                |
+----------------------+--------------------------+
                       |
                       v
+-------------------------------------------------+
|  api-gateway (Go)                                |
|  - auth (OAuth2 / API token)                     |
|  - rate limiter (Redis token bucket)             |
|  - request logger, audit                         |
|  - OpenAPI validator                             |
+--+--------------+----------------+--------------+
   |              |                |
   v              v                v
+--------+   +---------+   +----------------+
| chat   |   | plugin  |   | store-api      |
| svc    |   | reg     |   |                |
+--------+   +---------+   +----------------+
   |
   v
+-----------+
| Postgres  |
| oauth_*   |
| api_*     |
+-----------+

+-------------------+
| webhook-dispatcher| <- NATS bus -> services emit events
+-------------------+
```

## Components
- `api-gateway` Go service, single ingress.
- `oauth-server` integrated module: authorize, token, introspect, revoke, jwks.
- `webhook-dispatcher` worker: pulls events from NATS, signs, POSTs, retries.
- `openapi-gen` build-time tool reads handler annotations, emits `openapi.json`.

## OAuth2
- Endpoints: `/oauth/authorize`, `/oauth/token`, `/oauth/revoke`, `/oauth/introspect`, `/.well-known/jwks.json`.
- Grants: authorization_code with PKCE (S256 only), refresh_token. No implicit, no password.
- Access token: JWT RS256, 1 h; refresh token: opaque, 30 d sliding.
- Scopes: `read:servers`, `read:messages`, `write:messages`, `read:members`, `manage:plugins`, `read:store`, `webhooks:write`.

## API Tokens
- Created from developer portal; bound to app + optional server allowlist.
- Format `flk_pk_<envelope>_<random>`; only hash stored.
- Scopes subset of OAuth2.

## Versioning
- Header `Flicko-Api-Version: YYYY-MM-DD`; default per-app pinned at first call.
- Breaking changes ship under new dated version; old versions supported for 12 months.

## REST Routes (v1)
- `GET /v1/me`, `GET /v1/servers`, `GET /v1/servers/:id`, `GET /v1/servers/:id/channels`.
- `GET /v1/channels/:id`, `GET /v1/channels/:id/messages`, `POST /v1/channels/:id/messages`.
- `PATCH /v1/messages/:id`, `DELETE /v1/messages/:id`.
- `GET /v1/servers/:id/members`, `GET /v1/members/:id`.
- `POST /v1/reactions`, `DELETE /v1/reactions`.
- `GET /v1/plugins`, `POST /v1/servers/:id/plugins/:pid/install`.
- `GET /v1/store/listings`.
- `POST /v1/webhooks`, `GET /v1/webhooks`, `DELETE /v1/webhooks/:id`.

## Rate Limits
- Sliding window in Redis: app -> 600 rpm, user -> 300 rpm, ip -> 600 rpm.
- Per-route override table; write routes 60 rpm per user.
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.
- 429 returns `Retry-After` and problem+json body.

## NFRs
- Cold path read p95 under 120 ms; warm under 60 ms.
- 99.95% availability for chat read/write endpoints.
- Token validation under 4 ms (in-process JWKS cache).
- Webhook delivery 95% within 30 s, 99% within 10 min.

## Observability
- Request log with app id, user id, scope, route, status, latency.
- RED metrics per route, per app.
- Alerts: 5xx rate over 1% per route per 5 min; rate-limit denial spike per app over 1k/min.
- Trace propagation via `traceparent`.

## Security Review
- OAuth2 strict PKCE; redirect URI exact match including query.
- HSTS, TLS 1.2+, mTLS optional for partner tier.
- CSRF not applicable (no cookie auth on API), CORS allowlist per app.
- API token at-rest hashed with argon2id; only prefix shown after creation.
- Webhook HMAC SHA-256 with timestamp; replay window 5 min.
- Scope check at gateway plus defense-in-depth at service boundary.
- All write requests require `Idempotency-Key` header optional but recommended; deduped 24 h.
