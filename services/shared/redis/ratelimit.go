package redis

import (
	"context"
	"sync"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// slidingWindowScript is the Lua script from Production-Architecture.md §4.3.
// It implements an atomic sliding-window rate limiter using a sorted set.
//
//	KEYS[1] = rate limit key
//	ARGV[1] = window size in ms
//	ARGV[2] = max requests
//	ARGV[3] = current timestamp in ms
//
// Returns 1 (allowed) or 0 (denied).
const slidingWindowScript = `
local key = KEYS[1]
local window = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, '-inf', now - window)

local count = redis.call('ZCARD', key)

if count < limit then
    redis.call('ZADD', key, now, now .. ':' .. math.random(1000000))
    redis.call('PEXPIRE', key, window)
    return 1
else
    return 0
end
`

// SlidingWindowRateLimiter implements a Redis-backed sliding window rate limiter
// with automatic fallback to a local in-memory limiter when Redis is unreachable.
type SlidingWindowRateLimiter struct {
	rdb    *goredis.Client
	script *goredis.Script
	log    *zap.Logger

	// In-memory fallback: map[key] → sorted list of timestamps (ms).
	mu       sync.Mutex
	fallback map[string][]int64
}

// NewSlidingWindowRateLimiter creates a rate limiter and loads the Lua script
// into Redis (SCRIPT LOAD). The SHA is cached for subsequent EVALSHA calls.
func NewSlidingWindowRateLimiter(rdb *goredis.Client, log *zap.Logger) *SlidingWindowRateLimiter {
	return &SlidingWindowRateLimiter{
		rdb:      rdb,
		script:   goredis.NewScript(slidingWindowScript),
		log:      log.Named("ratelimit"),
		fallback: make(map[string][]int64),
	}
}

// Allow checks if a request identified by key is within the rate limit.
//
//   - key:    unique identifier (e.g. "msg:" + userID).
//     The "flicko:rate:" prefix is added automatically.
//   - limit:  maximum number of requests in the window.
//   - window: sliding window duration.
//
// Returns true if the request is allowed, false if rate-limited.
// Falls back to a local in-memory limiter if Redis is unreachable.
func (rl *SlidingWindowRateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error) {
	redisKey := "flicko:rate:" + key
	nowMS := time.Now().UnixMilli()
	windowMS := window.Milliseconds()

	result, err := rl.script.Run(ctx, rl.rdb, []string{redisKey},
		windowMS, limit, nowMS,
	).Int64()

	if err != nil {
		// Redis down → fall back to local in-memory limiter.
		rl.log.Warn("redis rate limit failed, using local fallback",
			zap.String("key", key),
			zap.Error(err),
		)
		return rl.allowLocal(key, limit, windowMS, nowMS), nil
	}

	return result == 1, nil
}

// allowLocal provides a best-effort local sliding window when Redis is down.
// It is NOT distributed — each gateway instance enforces independently.
func (rl *SlidingWindowRateLimiter) allowLocal(key string, limit int, windowMS, nowMS int64) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	cutoff := nowMS - windowMS

	// Remove expired entries.
	entries := rl.fallback[key]
	i := 0
	for i < len(entries) && entries[i] < cutoff {
		i++
	}
	entries = entries[i:]

	if len(entries) >= limit {
		rl.fallback[key] = entries
		return false
	}

	rl.fallback[key] = append(entries, nowMS)
	return true
}

// CleanupLocal removes expired entries from the local fallback map.
// Call periodically (e.g. every 30s) to prevent memory growth.
func (rl *SlidingWindowRateLimiter) CleanupLocal() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	nowMS := time.Now().UnixMilli()
	for key, entries := range rl.fallback {
		i := 0
		for i < len(entries) && entries[i] < nowMS-120_000 { // 2 min max
			i++
		}
		if i == len(entries) {
			delete(rl.fallback, key)
		} else {
			rl.fallback[key] = entries[i:]
		}
	}
}

// Reset clears the rate limit state for a specific key.
// Useful for admin overrides or testing.
func (rl *SlidingWindowRateLimiter) Reset(ctx context.Context, key string) error {
	return rl.rdb.Del(ctx, "flicko:rate:"+key).Err()
}
