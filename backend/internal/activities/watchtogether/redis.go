package watchtogether

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
)

const (
	sessionKeyPrefix = "wt:s:%s:state"
	sessionTTL       = 12 * time.Hour
)

type RedisCache struct {
	cache cache.CacheLayer
}

func NewRedisCache(c cache.CacheLayer) *RedisCache {
	return &RedisCache{cache: c}
}

func (r *RedisCache) SetSessionState(ctx context.Context, session *WTSession) error {
	if r == nil || r.cache == nil {
		return nil
	}
	key := fmt.Sprintf(sessionKeyPrefix, session.ID)
	return r.cache.SetJSON(ctx, key, session, sessionTTL)
}

func (r *RedisCache) GetSessionState(ctx context.Context, sessionID string) (*WTSession, error) {
	if r == nil || r.cache == nil {
		return nil, fmt.Errorf("cache not available")
	}
	key := fmt.Sprintf(sessionKeyPrefix, sessionID)
	var session WTSession
	if err := r.cache.GetJSON(ctx, key, &session); err != nil {
		return nil, err
	}
	return &session, nil
}

func (r *RedisCache) DeleteSessionState(ctx context.Context, sessionID string) error {
	if r == nil || r.cache == nil {
		return nil
	}
	key := fmt.Sprintf(sessionKeyPrefix, sessionID)
	return r.cache.Delete(ctx, key)
}

func (r *RedisCache) CheckRateLimit(ctx context.Context, limitKey string, limit int64, window time.Duration) (bool, error) {
	if r == nil || r.cache == nil {
		return false, nil // Cache not available, skip limit check (e.g. in unit tests)
	}

	now := time.Now()
	windowStartTime := now.Add(-window).Unix()

	// 1. Remove old entries outside the sliding window
	if err := r.cache.ZRemRangeByScore(ctx, limitKey, "-inf", fmt.Sprintf("%d", windowStartTime)); err != nil {
		return false, err
	}

	// 2. Count requests in the window
	count, err := r.cache.ZCard(ctx, limitKey)
	if err != nil {
		return false, err
	}

	if count >= limit {
		return true, nil // Limit exceeded
	}

	// 3. Add current request timestamp
	member := fmt.Sprintf("%d-%d", now.UnixNano(), now.Unix())
	if err := r.cache.ZAdd(ctx, limitKey, float64(now.Unix()), member); err != nil {
		return false, err
	}

	// 4. Set expire to prevent key leaks
	_ = r.cache.Expire(ctx, limitKey, window+1*time.Minute)

	return false, nil
}

