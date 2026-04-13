// CRIT-002: Distributed Rate Limiter using Redis
// This replaces the broken memory-based rate limiter with a Redis-backed
// sliding window implementation that works across multiple instances.
package middleware

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// DistributedRateLimiter uses Redis for distributed rate limiting across instances
type DistributedRateLimiter struct {
	rdb                 redis.Cmdable
	requestsPerSecond   int64
	window              time.Duration
	logger              *zap.Logger
	name                string // For metrics/logging
	cleanupInterval     time.Duration
	maxClientsTracked   int64
	blacklistExpiration time.Duration
}

// NewDistributedRateLimiter creates a Redis-backed rate limiter
// requestsPerSecond: limit per client per second (e.g., 50 for 50 req/s per IP)
func NewDistributedRateLimiter(
	rdb redis.Cmdable,
	requestsPerSecond int64,
	logger *zap.Logger,
	name string,
) *DistributedRateLimiter {
	if requestsPerSecond <= 0 {
		requestsPerSecond = 50 // Safe default
	}

	return &DistributedRateLimiter{
		rdb:                 rdb,
		requestsPerSecond:   requestsPerSecond,
		window:              1 * time.Minute,
		logger:              logger,
		name:                name,
		cleanupInterval:     15 * time.Minute,
		maxClientsTracked:   10000,
		blacklistExpiration: 1 * time.Hour,
	}
}

// Limit is middleware that enforces distributed rate limiting
func (drl *DistributedRateLimiter) Limit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Extract client IP (account for proxies)
		clientIP := drl.extractClientIP(r)

		// Create context with short timeout for Redis operations
		ctx, cancel := context.WithTimeout(r.Context(), 100*time.Millisecond)
		defer cancel()

		// Check current rate limit
		limited, err := drl.checkRateLimit(ctx, clientIP)
		if err != nil {
			// On Redis error: FAIL CLOSED (reject) for security
			// This prevents bypass of rate limiting if Redis is down
			drl.logger.Error("rate limiter error",
				zap.String("limiter", drl.name),
				zap.String("ip", clientIP),
				zap.Error(err),
			)
			writeJSONError(w, http.StatusServiceUnavailable, "SERVICE_ERROR", "Rate limiter unavailable")
			return
		}

		if limited {
			drl.logger.Warn("rate limit exceeded",
				zap.String("limiter", drl.name),
				zap.String("ip", clientIP),
				zap.Int64("limit", drl.requestsPerSecond),
			)
			writeJSONError(
				w,
				http.StatusTooManyRequests,
				"RATE_LIMITED",
				fmt.Sprintf("Too many requests (limit: %d/sec). Please retry after 60 seconds.", drl.requestsPerSecond),
			)
			return
		}

		// Allow request
		next.ServeHTTP(w, r)
	})
}

// checkRateLimit uses sliding window counter in Redis to track request rate
// Returns true if rate limit exceeded, false if request allowed
func (drl *DistributedRateLimiter) checkRateLimit(ctx context.Context, clientIP string) (bool, error) {
	key := fmt.Sprintf("ratelimit:%s:%s", drl.name, clientIP)
	windowStartTime := time.Now().Add(-drl.window).Unix()

	// Pipeline: ZREMRANGEBYSCORE + ZCARD + ZADD + EXPIRE
	pipe := drl.rdb.Pipeline()

	// Remove old entries outside the window
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%d", windowStartTime))

	// Count current requests in window
	pipe.ZCard(ctx, key)

	// Add current request with timestamp as score
	pipe.ZAdd(ctx, key,
		redis.Z{Score: float64(time.Now().Unix()), Member: fmt.Sprintf("%d-%d", time.Now().UnixNano(), len(clientIP))},
	)

	// Set expiration to ensure keys don't leak memory
	pipe.Expire(ctx, key, drl.window+1*time.Minute)

	// Execute pipeline
	results, err := pipe.Exec(ctx)
	if err != nil {
		return false, err
	}

	// Extract count from ZCARD result (index 1)
	if len(results) < 2 {
		return false, fmt.Errorf("unexpected pipeline results")
	}

	countCmd := results[1].(*redis.IntCmd)
	count, err := countCmd.Result()
	if err != nil {
		return false, err
	}

	// Check if limit exceeded
	limitPerWindow := drl.requestsPerSecond * int64(drl.window.Seconds())
	return count >= limitPerWindow, nil
}

// extractClientIP gets the real client IP accounting for proxies
func (drl *DistributedRateLimiter) extractClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (set by reverse proxy)
	if xForwardedFor := r.Header.Get("X-Forwarded-For"); xForwardedFor != "" {
		// X-Forwarded-For can contain multiple IPs; take the first
		if firstIP, _, err := net.SplitHostPort(xForwardedFor + ":"); err == nil {
			return firstIP
		}
		return xForwardedFor
	}

	// Check X-Real-IP header
	if xRealIP := r.Header.Get("X-Real-IP"); xRealIP != "" {
		return xRealIP
	}

	// Fall back to direct connection IP
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if ip == "" {
		ip = r.RemoteAddr
	}
	return ip
}

// GetStats returns current rate limiter statistics
func (drl *DistributedRateLimiter) GetStats(ctx context.Context) map[string]interface{} {
	// Count tracked IPs
	pattern := fmt.Sprintf("ratelimit:%s:*", drl.name)
	keys, err := drl.rdb.Keys(ctx, pattern).Result()
	if err != nil {
		drl.logger.Error("failed to get rate limit stats", zap.Error(err))
		return nil
	}

	return map[string]interface{}{
		"tracked_clients": len(keys),
		"limit_per_sec":   drl.requestsPerSecond,
		"window":          drl.window.String(),
	}
}

// ClearStats clears all rate limit data for this limiter
func (drl *DistributedRateLimiter) ClearStats(ctx context.Context) error {
	pattern := fmt.Sprintf("ratelimit:%s:*", drl.name)
	keys, err := drl.rdb.Keys(ctx, pattern).Result()
	if err != nil {
		return err
	}

	if len(keys) == 0 {
		return nil
	}

	return drl.rdb.Del(ctx, keys...).Err()
}

// AlternativeImplementation: Token Bucket (if needed in future)
// Redis INCR-based implementation with millisecond precision for more
// granular rate limiting. Current implementation uses sliding window
// which is easier to understand and tune.
