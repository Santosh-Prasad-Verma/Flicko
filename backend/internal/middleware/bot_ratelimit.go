package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

type BotRateLimiter struct {
	rdb    redis.Cmdable
	logger *zap.Logger
}

type RouteBucketConfig struct {
	Limit  int64
	Window time.Duration
}

var defaultRouteConfigs = map[string]RouteBucketConfig{
	"messages_create": {Limit: 5, Window: 5 * time.Second},    // 5 msgs per 5s
	"messages_delete": {Limit: 10, Window: 10 * time.Second},  // 10 deletes per 10s
	"reactions":       {Limit: 1, Window: 250 * time.Millisecond}, // 1 reaction per 250ms
	"guild_members":   {Limit: 10, Window: 10 * time.Second},
	"default":         {Limit: 50, Window: 1 * time.Minute},
}

func NewBotRateLimiter(rdb redis.Cmdable, logger *zap.Logger) *BotRateLimiter {
	return &BotRateLimiter{
		rdb:    rdb,
		logger: logger.Named("bot_ratelimit"),
	}
}

// ExtractBucketKey builds a major parameter rate-limiting bucket key:
// Bucket = route_name + ":" + major_parameter (e.g. channel_id, guild_id)
func ExtractBucketKey(r *http.Request) (string, string, int64, time.Duration) {
	vars := mux.Vars(r)
	path := r.URL.Path
	method := r.Method

	var majorParam string
	if channelID, ok := vars["channel_id"]; ok {
		majorParam = "chan:" + channelID
	} else if serverID, ok := vars["server_id"]; ok {
		majorParam = "srv:" + serverID
	} else if guildID, ok := vars["guild_id"]; ok {
		majorParam = "srv:" + guildID
	} else if id, ok := vars["id"]; ok {
		majorParam = "id:" + id
	} else {
		majorParam = "global"
	}

	routeType := "default"
	if strings.Contains(path, "/messages") {
		if method == http.MethodPost {
			routeType = "messages_create"
		} else if method == http.MethodDelete {
			routeType = "messages_delete"
		}
	} else if strings.Contains(path, "/reactions") {
		routeType = "reactions"
	} else if strings.Contains(path, "/members") {
		routeType = "guild_members"
	}

	config := defaultRouteConfigs[routeType]

	// Create deterministic hash for X-RateLimit-Bucket header
	hash := sha256.Sum256([]byte(fmt.Sprintf("%s:%s", routeType, majorParam)))
	bucketHash := hex.EncodeToString(hash[:8])

	return bucketHash, fmt.Sprintf("bot_bucket:%s:%s", routeType, majorParam), config.Limit, config.Window
}

func (brl *BotRateLimiter) Limit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		botID := GetUserIDFromContext(r)
		if botID == "" {
			// Not a bot request or not authenticated via BotAuthMiddleware; delegate to standard rate limiter
			next.ServeHTTP(w, r)
			return
		}

		bucketHash, bucketKey, limit, window := ExtractBucketKey(r)
		userBucketKey := fmt.Sprintf("%s:%s", bucketKey, botID)

		ctx, cancel := context.WithTimeout(r.Context(), 200*time.Millisecond)
		defer cancel()

		now := time.Now()
		nowUnix := now.Unix()
		windowStart := now.Add(-window).Unix()

		var count int64 = 0
		if brl.rdb != nil {
			// Sliding window counter in Redis
			pipe := brl.rdb.Pipeline()
			pipe.ZRemRangeByScore(ctx, userBucketKey, "-inf", strconv.FormatInt(windowStart, 10))
			pipe.ZCard(ctx, userBucketKey)
			pipe.ZAdd(ctx, userBucketKey, redis.Z{Score: float64(nowUnix), Member: fmt.Sprintf("%d-%d", now.UnixNano(), now.Nanosecond())})
			pipe.Expire(ctx, userBucketKey, window+5*time.Second)

			results, err := pipe.Exec(ctx)
			if err == nil && len(results) >= 2 {
				if countCmd, ok := results[1].(*redis.IntCmd); ok {
					count, _ = countCmd.Result()
				}
			}
		}

		remaining := limit - count
		if remaining < 0 {
			remaining = 0
		}

		resetTime := now.Add(window)
		resetUnixFloat := float64(resetTime.UnixNano()) / 1e9
		resetAfterFloat := window.Seconds()

		// Set standard Discord-style rate limit headers
		w.Header().Set("X-RateLimit-Bucket", bucketHash)
		w.Header().Set("X-RateLimit-Limit", strconv.FormatInt(limit, 10))
		w.Header().Set("X-RateLimit-Remaining", strconv.FormatInt(remaining, 10))
		w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%.3f", resetUnixFloat))
		w.Header().Set("X-RateLimit-Reset-After", fmt.Sprintf("%.3f", resetAfterFloat))

		if count > limit {
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(window.Seconds())))
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"message":     "You are being rate limited.",
				"retry_after": resetAfterFloat,
				"global":      false,
			})
			return
		}

		next.ServeHTTP(w, r)
	})
}

// GetAuditLogReason extracts the X-Audit-Log-Reason header from the request
func GetAuditLogReason(r *http.Request) *string {
	reason := r.Header.Get("X-Audit-Log-Reason")
	if reason == "" {
		return nil
	}
	trimmed := strings.TrimSpace(reason)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}
