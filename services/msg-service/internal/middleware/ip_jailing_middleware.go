package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"time"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// IPJailingMiddleware tracks requests by client IP.
// If an IP exceeds 10 requests per second, it jails the IP for 10 minutes.
// Jailed IPs are immediately rejected with 403 Forbidden.
func IPJailingMiddleware(rdb redis.Cmdable, log *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if rdb == nil {
				next.ServeHTTP(w, r)
				return
			}

			ip := extractClientIP(r)
			ctx, cancel := context.WithTimeout(r.Context(), 100*time.Millisecond)
			defer cancel()

			// 1. Check if IP is currently jailed
			jailedSetKey := "flicko:abuse:jailed_ips"
			jailedIPKey := fmt.Sprintf("flicko:abuse:jailed_ip:%s", ip)

			isJailed, err := rdb.SIsMember(ctx, jailedSetKey, ip).Result()
			if err == nil && isJailed {
				// Double check the specific TTL key to respect dynamic expiration
				exists, err := rdb.Exists(ctx, jailedIPKey).Result()
				if err == nil && exists == 0 {
					// TTL expired! Remove from the Set.
					_ = rdb.SRem(ctx, jailedSetKey, ip).Err()
					isJailed = false
				} else {
					log.Warn("request blocked: client IP is jailed due to spamming",
						zap.String("ip", ip),
						zap.String("path", r.URL.Path),
					)
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusForbidden)
					_ = json.NewEncoder(w).Encode(map[string]interface{}{
						"error": map[string]interface{}{
							"code":    fkerr.CodeForbidden,
							"message": "IP jailed due to spamming. Please try again in 10 minutes.",
						},
					})
					return
				}
			}

			// 2. Track request frequency using Redis sliding window
			freqKey := fmt.Sprintf("flicko:abuse:ip:freq:%s", ip)
			now := time.Now().UnixMilli()
			windowStart := now - 1000 // 1 second window

			pipe := rdb.Pipeline()
			// Clean up scores older than 1 second
			pipe.ZRemRangeByScore(ctx, freqKey, "-inf", fmt.Sprintf("%d", windowStart))
			// Count total requests in the last 1 second
			pipe.ZCard(ctx, freqKey)
			// Add this request's timestamp (use nanoseconds and ip as unique suffix to guarantee uniqueness)
			member := fmt.Sprintf("%d-%s-%d", now, ip, time.Now().UnixNano())
			pipe.ZAdd(ctx, freqKey, redis.Z{Score: float64(now), Member: member})
			// Set expiration to ensure no memory leak
			pipe.Expire(ctx, freqKey, 5*time.Second)

			results, err := pipe.Exec(ctx)
			if err != nil {
				// Fallback gracefully on Redis error (Availability > Enforcement)
				log.Error("IP jailing: Redis tracking pipeline failed, bypassing check",
					zap.String("ip", ip),
					zap.Error(err),
				)
				next.ServeHTTP(w, r)
				return
			}

			// Extract request count from ZCard result
			if len(results) >= 2 {
				if countCmd, ok := results[1].(*redis.IntCmd); ok {
					count, err := countCmd.Result()
					if err == nil && count >= 10 {
						// Threshold of 10 requests per second exceeded! Jail the IP for 10 minutes.
						log.Warn("IP jailing triggered: IP exceeded rate limit, jailing for 10 minutes",
							zap.String("ip", ip),
							zap.Int64("requests_last_sec", count),
						)

						pipeJail := rdb.Pipeline()
						pipeJail.SAdd(ctx, jailedSetKey, ip)
						pipeJail.Set(ctx, jailedIPKey, "1", 10*time.Minute)
						_, errJail := pipeJail.Exec(ctx)
						if errJail != nil {
							log.Error("IP jailing: failed to write jail key in Redis",
								zap.String("ip", ip),
								zap.Error(errJail),
							)
						}

						// Immediately reject this request
						w.Header().Set("Content-Type", "application/json")
						w.WriteHeader(http.StatusForbidden)
						_ = json.NewEncoder(w).Encode(map[string]interface{}{
							"error": map[string]interface{}{
								"code":    fkerr.CodeForbidden,
								"message": "IP jailed due to spamming. Please try again in 10 minutes.",
							},
						})
						return
					}
				}
			}

			next.ServeHTTP(w, r)
		})
	}
}

func extractClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if ip, _, err := net.SplitHostPort(xff + ":"); err == nil {
			return ip
		}
		return xff
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if ip == "" {
		ip = r.RemoteAddr
	}
	return ip
}
