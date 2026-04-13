package middleware

import (
"encoding/json"
"fmt"
"math"
"net/http"
"time"

"go.uber.org/zap"

"github.com/flicko-org/flicko/services/shared/auth"
fkerr "github.com/flicko-org/flicko/services/shared/errors"
"github.com/flicko-org/flicko/services/shared/ratelimit"
)

// RateLimitConfig holds the per-route rate limit settings.
type RateLimitConfig struct {
Tier ratelimit.Tier
}

// DefaultRateLimitConfig returns the general API tier (50 req/sec).
func DefaultRateLimitConfig() RateLimitConfig {
return RateLimitConfig{Tier: ratelimit.TierAPIGeneral}
}

// MessageCreateRateLimitConfig returns the message create tier (10 msg/sec).
func MessageCreateRateLimitConfig() RateLimitConfig {
return RateLimitConfig{Tier: ratelimit.TierMessageCreate}
}

// UploadRateLimitConfig returns the upload presign tier (2 req/sec).
func UploadRateLimitConfig() RateLimitConfig {
return RateLimitConfig{Tier: ratelimit.TierUpload}
}

// GuildJoinRateLimitConfig returns the guild join tier (10/hour).
func GuildJoinRateLimitConfig() RateLimitConfig {
return RateLimitConfig{Tier: ratelimit.TierGuildJoin}
}

// RateLimit returns HTTP middleware that enforces the configured tier
// using the composite (Redis + local fallback) rate limiter.
//
// Key format: "flicko:rate:api:{user_id}" for authenticated users,
// falling back to remote IP for unauthenticated requests.
//
// On denial: 429 with Retry-After header and structured JSON error.
func RateLimit(comp *ratelimit.Composite, cfg RateLimitConfig, log *zap.Logger) func(http.Handler) http.Handler {
return func(next http.Handler) http.Handler {
return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
// Build rate-limit key.
identity := r.RemoteAddr
if uid := auth.UserIDFromContext(r.Context()); uid != "" {
identity = uid
}
key := cfg.Tier.Key(identity)

res, err := comp.AllowDetailed(r.Context(), key, cfg.Tier.Limit, cfg.Tier.Window)
if err != nil {
// Both Redis and local failed — be lenient.
log.Error("rate limiter completely failed, allowing request",
zap.Error(err),
zap.String("key", key),
)
next.ServeHTTP(w, r)
return
}

// Set rate-limit response headers.
w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", cfg.Tier.Limit))
if res.Remaining >= 0 {
w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", res.Remaining))
}
w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", res.ResetAt.Unix()))

if res.Allowed {
next.ServeHTTP(w, r)
return
}

// Denied — compute Retry-After in seconds (fractional).
retryAfter := time.Until(res.ResetAt).Seconds()
if retryAfter < 0.1 {
retryAfter = 1.0
}
retryAfter = math.Ceil(retryAfter*10) / 10 // round to 1 decimal

w.Header().Set("Content-Type", "application/json")
w.Header().Set("Retry-After", fmt.Sprintf("%.0f", math.Ceil(retryAfter)))
w.WriteHeader(http.StatusTooManyRequests)

_ = json.NewEncoder(w).Encode(map[string]interface{}{
"error": map[string]interface{}{
"code":        fkerr.CodeRateLimited,
"message":     fmt.Sprintf("rate limited, retry after %.1fs", retryAfter),
"retry_after": retryAfter,
},
})
})
}
}
