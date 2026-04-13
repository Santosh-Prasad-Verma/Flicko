# Rate Limiting Strategies

> **Reading time:** ~7 minutes · **Audience:** DevOps, Backend Developers · **Last Updated:** 2026-04-11

Rate limiting is essential to ensure API availability and protect against brute-force attacks. Flicko implements distinct limiters at both the Cloudflare Edge and the application (Go) level.

---

## 1. Edge Layer (Cloudflare WAF)

Cloudflare acts as our unmetered shock absorber.
The Cloudflare WAF holds a set of Rules designed to catch gross abuse before our VPS ever sees the traffic.

**Ruleset:**
- **DDoS generic:** Drops any IP sending >2,000 requests per 10 seconds.
- **Login Brute Force:** Blocks IP addresses hitting `/auth/token` more than 30 times in 1 hour.
- **Geo-Block (Optional):** Admins can toggle blocks on entire high-risk Autonomous System Numbers (ASNs) if a targeted Layer-7 HTTP flood is underway.

---

## 2. Distributed Application Limiter (Redis)

Because Cloudflare limits are too broad for specific user-level API quotas (and Cloudflare routes all mobile traffic through varied IP gateways), we implement a more precise sliding-window limiter directly inside the Go API utilizing Upstash Redis.

**Why Redis?**
If we used an in-memory limiter (like a standard Go `map[string]int`), a user could bypass limits simply by launching two connections that load-balance to two different `backend` NGINX workers. Because Redis is a shared data-plane, a counter incremented by Node A is instantly readable by Node B.

### Configuration (`backend/internal/middleware/ratelimit.go`)

Our limiter tracks users primarily by their `Authorization: Bearer` JWT payload UUID. If the route is unauthenticated, it falls back to tracking by the `X-Real-IP` header passed by NGINX.

```go
func RateLimiter() func(http.Handler) http.Handler {
    // Defines a limiter allowing 100 requests every 10 seconds
    limiter := tollbooth.NewLimiter(10, &limiter.ExpirableOptions{
        DefaultExpirationTTL: time.Second * 10,
    })

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            
            // Prefer User ID, fallback to IP
            identifier := extractUserID(r.Context())
            if identifier == "" {
                identifier = r.RemoteAddr
            }

            // Sync with Redis via Lua Scripting
            allowed, headers := checkRedisQuota(identifier, 100, 10)
            
            // Inject informational HTTP Headers
            for k, v := range headers {
                w.Header().Set(k, v)
            }

            if !allowed {
                util.RespondError(w, 429, "Rate limit exceeded.")
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

### Response Headers

The limiter natively intercepts the request and injects standards-compliant tracking headers:
- `X-RateLimit-Limit`: Maximum requests permitted per window.
- `X-RateLimit-Remaining`: How many you have left.
- `X-RateLimit-Reset`: Unix Epoch timestamp of when your quota refreshes.

If `Remaining == 0`, the mobile app uses the `Reset` value to safely pause background fetching.

---

## 3. Dedicated WebSocket Limiting

The `ws-gateway` does not share the HTTP rate limits. Instead, it enforces token bucket limits directly per-connection to prevent packet floods.

If a single WebRTC socket sends >10 payloads (like `OpTyping` or heartbeat spam) within 1 second, the Hub disconnects the socket with a `1008 Policy Violation` close code.

---

## Related Documentation

- [Backend: Middleware](middleware.md) — Where the limiter sits in the pipeline
- [API: Error Codes](../api/error-codes.md) — What the 429 payloads look like
