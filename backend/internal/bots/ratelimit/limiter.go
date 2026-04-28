package ratelimit

import (
	"context"
	"fmt"
	"sync"
	"time"
)

type LimitTier struct {
	Name    string
	Bucket  *TokenBucket
	Counter *SlidingWindowCounter
}

type MultiTierLimiter struct {
	mu   sync.RWMutex
	bots map[string][]*LimitTier
}

func NewMultiTierLimiter() *MultiTierLimiter {
	return &MultiTierLimiter{
		bots: make(map[string][]*LimitTier),
	}
}

func (m *MultiTierLimiter) GetOrCreate(botID string) []*LimitTier {
	m.mu.RLock()
	if tiers, ok := m.bots[botID]; ok {
		m.mu.RUnlock()
		return tiers
	}
	m.mu.RUnlock()

	m.mu.Lock()
	defer m.mu.Unlock()

	if tiers, ok := m.bots[botID]; ok {
		return tiers
	}

	tiers := []*LimitTier{
		{
			Name:   "burst",
			Bucket: NewTokenBucket(20, 20),
		},
		{
			Name:    "sustained",
			Counter: NewSlidingWindowCounter(500, time.Minute, 60),
		},
		{
			Name:    "daily",
			Counter: NewSlidingWindowCounter(100_000, 24*time.Hour, 1440),
		},
	}
	m.bots[botID] = tiers
	return tiers
}

func (m *MultiTierLimiter) Check(ctx context.Context, botID string) error {
	tiers := m.GetOrCreate(botID)

	for _, tier := range tiers {
		if tier.Bucket != nil {
			if ok, wait := tier.Bucket.Allow(1); !ok {
				return &RateLimitError{
					Tier:       tier.Name,
					RetryAfter: wait,
				}
			}
		}
		if tier.Counter != nil {
			if ok, count := tier.Counter.Allow(); !ok {
				return &RateLimitError{
					Tier:    tier.Name,
					Current: count,
				}
			}
		}
	}
	return nil
}

type RateLimitError struct {
	Tier       string
	RetryAfter time.Duration
	Current    int64
}

func (e *RateLimitError) Error() string {
	return fmt.Sprintf("rate limit exceeded on tier %q (retry after %v)", e.Tier, e.RetryAfter)
}
