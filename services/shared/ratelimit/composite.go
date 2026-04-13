package ratelimit

import (
"context"
"time"

"go.uber.org/zap"
)

// Composite tries the Redis SlidingWindow first. If Redis returns an
// error it falls back to the local BucketStore so that the service
// never hard-fails on a Redis blip.
//
// Thread-safe: both underlying limiters are safe for concurrent use.
type Composite struct {
sw    *SlidingWindow
local *BucketStore
log   *zap.Logger
}

// NewComposite wires the Redis and local limiters together.
func NewComposite(sw *SlidingWindow, local *BucketStore, log *zap.Logger) *Composite {
return &Composite{
sw:    sw,
local: local,
log:   log.Named("ratelimit.composite"),
}
}

// Allow performs a rate-limit check.
//
//  1. Asks the Redis sliding window for the authoritative answer.
//  2. On Redis failure, falls back to the local token bucket.
//
// The local fallback converts the (limit, window) pair into a
// per-second rate: ratePerSec = limit / window.Seconds(), burst = limit.
func (c *Composite) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error) {
res, err := c.sw.Allow(ctx, key, limit, window)
if err == nil {
return res.Allowed, nil
}

// Redis unavailable — degrade to local token bucket.
c.log.Warn("redis rate-limit failed, falling back to local bucket",
zap.String("key", key),
zap.Error(err),
)

ratePerSec := float64(limit) / window.Seconds()
return c.local.Allow(key, ratePerSec, limit), nil
}

// AllowDetailed is like Allow but returns the full Result on success.
// If the Redis call fails it returns a synthetic Result from the local
// bucket (with an approximate ResetAt).
func (c *Composite) AllowDetailed(ctx context.Context, key string, limit int, window time.Duration) (Result, error) {
res, err := c.sw.Allow(ctx, key, limit, window)
if err == nil {
return res, nil
}

c.log.Warn("redis rate-limit failed, falling back to local bucket",
zap.String("key", key),
zap.Error(err),
)

ratePerSec := float64(limit) / window.Seconds()
allowed := c.local.Allow(key, ratePerSec, limit)
return Result{
Allowed:   allowed,
Remaining: -1, // unknown in local mode
ResetAt:   time.Now().Add(window),
}, nil
}

// Stop releases the BucketStore janitor goroutine.
func (c *Composite) Stop() {
c.local.Stop()
}
