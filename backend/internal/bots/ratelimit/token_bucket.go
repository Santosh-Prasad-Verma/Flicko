package ratelimit

import (
	"math"
	"sync"
	"time"
)

type TokenBucket struct {
	mu       sync.Mutex
	tokens   float64
	capacity float64
	rate     float64
	lastTime time.Time
}

func NewTokenBucket(capacity float64, ratePerSec float64) *TokenBucket {
	return &TokenBucket{
		tokens:   capacity,
		capacity: capacity,
		rate:     ratePerSec / float64(time.Second),
		lastTime: time.Now(),
	}
}

func (tb *TokenBucket) Allow(n float64) (bool, time.Duration) {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(tb.lastTime)
	tb.lastTime = now

	tb.tokens = math.Min(tb.capacity, tb.tokens+float64(elapsed)*tb.rate)

	if tb.tokens >= n {
		tb.tokens -= n
		return true, 0
	}

	deficit := n - tb.tokens
	waitNs := time.Duration(deficit / tb.rate)
	return false, waitNs
}
