# Middleware Protection Pipeline

> **Reading time:** ~8 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Every HTTP request to a Flicko Go service must pass sequentially through a gauntlet of Middleware handlers before any database or business logic is touched. Failing any step instantly kills the request wrapper and returns a standard error JSON.

---

## 1. The Global Pipeline

The `chi` router applies these in order:

```go
r.Use(middleware.RequestID)         // 1. Logging Traceability
r.Use(middleware.RealIP)            // 2. IP spoofing mitigation
r.Use(middleware.Logger)            // 3. STDOUT audit log
r.Use(middleware.Recoverer)         // 4. Panic isolation
r.Use(LimitMiddleware)              // 5. Redis Rate Limiter
```

1. **RequestID**: Injects `X-Request-Id`. If the backend fat-fingers a nil pointer and crashes, the mobile app shows the user an error ID. The developer simply searches their Loki logs for that `X-Request-Id` to find the exact stack trace.
2. **RealIP**: Because NGINX acts as a reverse proxy, the Go app thinks every request comes from `172.18.0.2` (Docker internal). This strips the docker wrapping and reads `X-Forwarded-For` inserted by Cloudflare.
3. **Recoverer**: If a buggy handler accidentally causes a divide-by-zero or nil pointer dereference, Go would normally crash the entire binary (dropping all 10k connections). `Recoverer` catches the `panic()`, halts only that specific goroutine, logs the panic, and safely returns `500 Internal Server Error`.

---

## 2. API Security Pipeline

Applied exclusively to the `/api/v1/` group router:

```go
api.Use(CSRFMiddleware)             // 6. Cross-Site Request Forgery 
api.Use(JSONContentMiddleware)      // 7. Header Validation
api.Use(AuthJWTVerifier)            // 8. Identity Verification
```

### CSRF Middleware
Checks `r.Method`. If it's a mutation (`POST`, `PUT`, `DELETE`, `PATCH`), it verifies the request contains a custom header: `X-CSRF-Token: 1`. Native mobile apps enforce this easily. Browsers executing malicious hidden forms cannot attach custom headers, completely stopping the vector.

### JSONContent Middleware
Flicko parses JSON. If an attacker sends a massive URL-encoded payload or XML bomb, the parser might slow down. This middleware runs `if r.Header.Get("Content-Type") != "application/json" { drop() }`, saving CPU cycles.

### Auth JWT Verifier
The absolute most critical file (`internal/middleware/auth.go`).
It extracts the `Bearer ` token. Validates its structural integrity. Mathematically verifies its `HMAC-SHA256` signature using our `.env` secret. Validates the `exp` (expiration) claim. Extracts the `sub` (User UUID claim). And finally, securely injects it into `<r.Context()>` so downstream controllers can use without re-validating.

---

## 3. Stripe Security Pipeline

To prevent malicious users from forging payment confirmations, the Webhook router bypasses the JWT and CSRF validators, and instead uses:

```go
stripeGrp.Use(StripeSignatureVerifier)
```

The `StripeSignatureVerifier` captures the raw byte body (`io.ReadAll(baseBody)`) before it gets manipulated, computes the expected hash using our `STRIPE_WEBHOOK_SECRET`, compares it securely against the `Stripe-Signature` query header (using constant-time compare to thwart timing attacks), and drops it if invalid.

---

## Related Documentation

- [Backend: Controllers](../backend/controllers.md) — What happens *after* the middleware pipeline is finished.
- [Security: Overview](overview.md) — The wider context of defense in depth.
