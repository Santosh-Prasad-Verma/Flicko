package ratelimit

import (
	"context"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

var ErrRateLimitExceeded = errors.New("rate limit exceeded")

type RateLimiter interface {
	// Allow returns true if the request is permitted within the rate limits
	Allow(ctx context.Context, key string, capacity, refillRate int) (bool, error)
}

type tokenBucket struct {
	redisClient *redis.Client
	logger      *zap.Logger
}

func NewTokenBucket(rc *redis.Client, logger *zap.Logger) RateLimiter {
	return &tokenBucket{
		redisClient: rc,
		logger:      logger,
	}
}

// tokenBucketLua executes the Token Bucket algorithm purely inside Redis.
// KEYS[1] = target user identifier bucket
// ARGV[1] = bucket capacity (max bursts)
// ARGV[2] = refill rate (tokens generated per second)
// ARGV[3] = current time (Unix timestamp in milliseconds)
// Returns 1 if token granted, 0 if rate limited.
const tokenBucketLua = `
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local bucket = redis.call("HMGET", key, "tokens", "last_update")
local tokens = tonumber(bucket[1])
local last_update = tonumber(bucket[2])

if not tokens then
    tokens = capacity
    last_update = now
end

-- Calculate tokens to refill based on elapsed time gap
local elapsed_ms = math.max(0, now - last_update)
local tokens_to_add = math.floor((elapsed_ms * rate) / 1000)

tokens = math.min(capacity, tokens + tokens_to_add)

if tokens > 0 then
    tokens = tokens - 1
    -- Update last_update timestamp only if we generated new tokens or it's the first time
    if tokens_to_add > 0 or not bucket[1] then
        last_update = now
    end
    redis.call("HMSET", key, "tokens", tokens, "last_update", last_update)
    -- Expire bucket if user becomes inactive to save memory
    redis.call("PEXPIRE", key, 60000)
    return 1
else
    return 0
end
`

func (tb *tokenBucket) Allow(ctx context.Context, key string, capacity, refillRate int) (bool, error) {
	nowMs := time.Now().UnixMilli()

	result, err := tb.redisClient.Eval(ctx, tokenBucketLua, []string{key}, capacity, refillRate, nowMs).Result()
	if err != nil {
		tb.logger.Error("rate limit evaluation failed", zap.Error(err), zap.String("key", key))
		return false, err
	}

	allowed := result.(int64) == 1
	return allowed, nil
}
