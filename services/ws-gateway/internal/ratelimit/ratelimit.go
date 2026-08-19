package ratelimit

import (
	"sync"
	"time"
)

type RateLimiter interface {
	Allow(key string) bool
}

type slidingWindowLimiter struct {
	mu          sync.Mutex
	limits      map[string][]time.Time
	maxRequests int
	window      time.Duration
}

func NewSlidingWindowLimiter(maxRequests int, window time.Duration) RateLimiter {
	return &slidingWindowLimiter{
		limits:      make(map[string][]time.Time),
		maxRequests: maxRequests,
		window:      window,
	}
}

func (l *slidingWindowLimiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-l.window)

	timestamps := l.limits[key]
	var valid []time.Time
	for _, t := range timestamps {
		if t.After(cutoff) {
			valid = append(valid, t)
		}
	}

	if len(valid) >= l.maxRequests {
		l.limits[key] = valid
		return false
	}

	valid = append(valid, now)
	l.limits[key] = valid
	return true
}
