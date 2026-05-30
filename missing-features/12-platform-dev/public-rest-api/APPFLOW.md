# APPFLOW: Public REST API

## OAuth Authorization Code + PKCE
```mermaid
sequenceDiagram
    participant App as Third-party App
    participant U as User Browser
    participant Auth as oauth-server
    participant API as api-gateway
    App->>App: gen code_verifier, code_challenge=S256(verifier)
    App->>U: redirect to /oauth/authorize?client_id&scope&redirect&code_challenge
    U->>Auth: GET /authorize
    Auth->>U: login + consent screen
    U->>Auth: approve scopes + select server
    Auth->>U: 302 redirect_uri?code=...
    U->>App: callback with code
    App->>Auth: POST /token (code, code_verifier, client_id, secret)
    Auth->>Auth: verify PKCE, exchange
    Auth-->>App: access_token, refresh_token, expires_in
    App->>API: GET /v1/me (Bearer access_token)
    API->>Auth: introspect (cached)
    API-->>App: 200 user payload
```

## Refresh
```mermaid
sequenceDiagram
    participant App
    participant Auth
    App->>Auth: POST /token grant=refresh
    Auth->>Auth: rotate refresh, mint new access
    Auth-->>App: new tokens, old refresh invalidated
```

## Rate Limit Decision
```mermaid
sequenceDiagram
    participant App
    participant GW as api-gateway
    participant R as Redis
    App->>GW: GET /v1/messages
    GW->>R: INCR sliding window key{app}{user}{route}
    alt under cap
        R-->>GW: count
        GW->>GW: forward to backend service
        GW-->>App: 200 + X-RateLimit headers
    else over cap
        R-->>GW: count > limit
        GW-->>App: 429 + Retry-After
    end
```

## Webhook Delivery
```mermaid
sequenceDiagram
    participant Bus as NATS
    participant WD as webhook-dispatcher
    participant Sub as Subscriber URL
    Bus->>WD: event message.created
    WD->>WD: lookup subscriptions matching event
    loop per subscription
        WD->>WD: sign body HMAC-SHA256
        WD->>Sub: POST with X-Flicko-Signature, X-Flicko-Timestamp
        alt 2xx
            Sub-->>WD: 200
        else non-2xx
            WD->>WD: schedule retry (1m,5m,30m,2h,12h)
        end
    end
```

## Versioning State
```
client default = first call's API version
explicit header = override per request
deprecated version = adds Sunset header 6 mo before removal
removed version = 410 Gone with link to migration doc
```

## Token Lifecycle
```
created -> active -> [refreshed -> active'] | [revoked -> dead] | [expired -> dead]
revoked: server-side blacklist row in api_tokens.revoked_at, propagated to gateway via Postgres LISTEN within 1 s.
```

## Edge Cases
- Clock skew on PKCE check: tolerance 60 s.
- Redirect URI mismatch: refuse with `invalid_redirect_uri` and log to security audit.
- Concurrent refresh: refresh tokens are single-use; second use marks family compromised, all tokens in family revoked, owner emailed.
- API token rotation: dual-active window 24 h with both tokens valid.
- Webhook receiver flaps: circuit breaker after 50 consecutive failures, suspends subscription with notification.
- Idempotency-Key reuse with different body: returns 409 with `idempotency_conflict`.
- Scope downgrade mid-session: token still valid until expiry; new requests beyond removed scope return 403 with `scope_required`.
- 429 inside a 200-batch endpoint: per-item failures returned in batched response, top-level 200 retained.

## Sandbox Auth
- Tokens prefixed `flk_test_` route to a separate read-only mirror DB.
- Test webhook receiver provided at `/sandbox/webhooks/inbox` with viewable history for 1 h.
