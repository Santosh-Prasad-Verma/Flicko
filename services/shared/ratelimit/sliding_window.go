// Package ratelimit provides a layered rate-limiting system.
//
// Three implementations work together:
//
//   - SlidingWindow: Redis-backed sliding window (distributed, authoritative)
//   - BucketStore:   In-memory token bucket (fast local fallback)
//   - Composite:     Tries Redis first, falls back to local bucket
//
// The Lua script guarantees atomicity via EVALSHA. ScriptLoad runs once
// at creation; every subsequent call uses the cached SHA.
package ratelimit

import (
"context"
"crypto/rand"
"fmt"
"time"

goredis "github.com/redis/go-redis/v9"
"go.uber.org/zap"
)

// slidingWindowLua atomically implements a sliding window counter using a
// Redis sorted set.
//
//KEYS[1] = rate limit key
//ARGV[1] = current time (ms)
//ARGV[2] = window size (ms)
//ARGV[3] = max requests
//
// Returns {allowed(0|1), remaining, resetTimestamp(ms)}.
const slidingWindowLua = `
local key    = KEYS[1]
local now    = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit  = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, '-inf', now - window)

local count = redis.call('ZCARD', key)

local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
local reset  = now + window
if #oldest >= 2 then
    reset = tonumber(oldest[2]) + window
end

if count < limit then
    redis.call('ZADD', key, now, now .. ':' .. math.random(1000000))
    redis.call('PEXPIRE', key, window)
    return {1, limit - count - 1, reset}
end

redis.call('PEXPIRE', key, window)
return {0, 0, reset}
`

// Result holds the outcome of a rate-limit check.
type Result struct {
// Allowed is true when the request is within the limit.
Allowed bool
// Remaining is the number of requests left in the current window.
Remaining int
// ResetAt is the earliest time the window resets.
ResetAt time.Time
}

// SlidingWindow is a Redis-backed distributed rate limiter.
// It loads the Lua script once (ScriptLoad) and uses EVALSHA for every
// subsequent call — zero parsing overhead on the Redis side.
//
// Thread-safe: no internal mutex is needed because the go-redis client
// is itself safe for concurrent use and the Lua script is pure.
type SlidingWindow struct {
rdb *goredis.Client
sha string // SHA1 of the loaded Lua script
log *zap.Logger
}

// NewSlidingWindow creates a SlidingWindow rate limiter.
// It eagerly loads the Lua script into Redis.
func NewSlidingWindow(ctx context.Context, rdb *goredis.Client, log *zap.Logger) (*SlidingWindow, error) {
sha, err := rdb.ScriptLoad(ctx, slidingWindowLua).Result()
if err != nil {
return nil, fmt.Errorf("ratelimit: script load: %w", err)
}
log.Info("ratelimit: sliding window script loaded", zap.String("sha", sha[:12]))
return &SlidingWindow{rdb: rdb, sha: sha, log: log.Named("ratelimit.sw")}, nil
}

// Allow checks whether key is below limit within window.
//
// The Redis key is automatically prefixed with "flicko:rl:" to avoid
// collisions with other subsystems.
func (sw *SlidingWindow) Allow(ctx context.Context, key string, limit int, window time.Duration) (Result, error) {
redisKey := "flicko:rl:" + key
nowMS := time.Now().UnixMilli()
windowMS := window.Milliseconds()

vals, err := sw.rdb.EvalSha(ctx, sw.sha, []string{redisKey},
nowMS,
windowMS,
limit,
).Int64Slice()
if err != nil {
return Result{}, fmt.Errorf("ratelimit: evalsha: %w", err)
}

if len(vals) != 3 {
return Result{}, fmt.Errorf("ratelimit: unexpected lua result length %d", len(vals))
}

return Result{
Allowed:   vals[0] == 1,
Remaining: int(vals[1]),
ResetAt:   time.UnixMilli(vals[2]),
}, nil
}

// uniqueMember returns a collision-resistant sorted-set member.
// Not used directly here (the Lua script generates its own), but
// exported for callers that build custom rate-limit keys.
func uniqueMember() string {
var buf [8]byte
rand.Read(buf[:])
return fmt.Sprintf("%x", buf[:])
}
