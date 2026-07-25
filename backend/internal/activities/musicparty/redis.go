package musicparty

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
)

const (
	sessionStateTTL = 12 * time.Hour
	skipVoteTTL     = 30 * time.Minute
	rateLimitTTL    = 60 * time.Second
	rotationLockTTL = 5 * time.Second
)

// RedisCache wraps the shared CacheLayer with Music Party–specific key patterns.
type RedisCache struct {
	cache cache.CacheLayer
}

// NewRedisCache creates a new Music Party Redis cache wrapper.
func NewRedisCache(c cache.CacheLayer) *RedisCache {
	return &RedisCache{cache: c}
}

// ── Session State (hot cache) ──────────────────────────────────

func (r *RedisCache) SetSessionState(ctx context.Context, session *MPSession) error {
	key := fmt.Sprintf("mp:s:%s:state", session.ID)
	return r.cache.SetJSON(ctx, key, session, sessionStateTTL)
}

func (r *RedisCache) GetSessionState(ctx context.Context, sessionID string) (*MPSession, error) {
	key := fmt.Sprintf("mp:s:%s:state", sessionID)
	var session MPSession
	err := r.cache.GetJSON(ctx, key, &session)
	if err != nil {
		return nil, err
	}
	return &session, nil
}

func (r *RedisCache) DeleteSessionState(ctx context.Context, sessionID string) error {
	key := fmt.Sprintf("mp:s:%s:state", sessionID)
	return r.cache.Delete(ctx, key)
}

// ── DJ Tracking ────────────────────────────────────────────────

func (r *RedisCache) SetCurrentDJ(ctx context.Context, sessionID string, djUserID string) error {
	key := fmt.Sprintf("mp:s:%s:dj", sessionID)
	return r.cache.Set(ctx, key, djUserID, sessionStateTTL)
}

func (r *RedisCache) GetCurrentDJ(ctx context.Context, sessionID string) (string, error) {
	key := fmt.Sprintf("mp:s:%s:dj", sessionID)
	val, err := r.cache.Get(ctx, key)
	if err != nil {
		return "", err
	}
	return val, nil
}

// ── Anchor State ───────────────────────────────────────────────

func (r *RedisCache) SetAnchorState(ctx context.Context, sessionID string, anchor *AnchorState) error {
	key := fmt.Sprintf("mp:s:%s:anchor", sessionID)
	return r.cache.SetJSON(ctx, key, anchor, sessionStateTTL)
}

func (r *RedisCache) GetAnchorState(ctx context.Context, sessionID string) (*AnchorState, error) {
	key := fmt.Sprintf("mp:s:%s:anchor", sessionID)
	var anchor AnchorState
	err := r.cache.GetJSON(ctx, key, &anchor)
	if err != nil {
		return nil, err
	}
	return &anchor, nil
}

// ── Skip Vote Tracking ────────────────────────────────────────

func (r *RedisCache) IncrSkipVote(ctx context.Context, sessionID string, trackURI string) (int64, error) {
	key := fmt.Sprintf("mp:s:%s:skip:%s", sessionID, trackURI)
	client := r.cache.GetRedisClient()
	result := client.Incr(ctx, key)
	if result.Err() != nil {
		return 0, result.Err()
	}
	// Set TTL on first vote
	if result.Val() == 1 {
		client.Expire(ctx, key, skipVoteTTL)
	}
	return result.Val(), nil
}

func (r *RedisCache) HasUserVotedSkip(ctx context.Context, sessionID string, trackURI string, userID string) (bool, error) {
	key := fmt.Sprintf("mp:s:%s:skip:%s:voters", sessionID, trackURI)
	client := r.cache.GetRedisClient()
	return client.SIsMember(ctx, key, userID).Result()
}

func (r *RedisCache) AddSkipVoter(ctx context.Context, sessionID string, trackURI string, userID string) error {
	key := fmt.Sprintf("mp:s:%s:skip:%s:voters", sessionID, trackURI)
	client := r.cache.GetRedisClient()
	client.SAdd(ctx, key, userID)
	client.Expire(ctx, key, skipVoteTTL)
	return nil
}

// ── Rotation Lock ──────────────────────────────────────────────

func (r *RedisCache) AcquireRotationLock(ctx context.Context, sessionID string) (bool, error) {
	key := fmt.Sprintf("mp:s:%s:rotation_lock", sessionID)
	client := r.cache.GetRedisClient()
	return client.SetNX(ctx, key, "locked", rotationLockTTL).Result()
}

// ── Rate Limiting ──────────────────────────────────────────────

func (r *RedisCache) CheckQueueAddRateLimit(ctx context.Context, userID string) (bool, error) {
	key := fmt.Sprintf("mp:rate:user:%s:queue_adds", userID)
	client := r.cache.GetRedisClient()

	count, err := client.Incr(ctx, key).Result()
	if err != nil {
		return false, err
	}
	if count == 1 {
		client.Expire(ctx, key, rateLimitTTL)
	}

	// 30 adds per minute
	return count <= 30, nil
}

// ── Room Session Tracking ──────────────────────────────────────

func (r *RedisCache) AddRoomSession(ctx context.Context, roomID string, sessionID string) error {
	key := fmt.Sprintf("mp:room:%s:sessions", roomID)
	client := r.cache.GetRedisClient()
	client.SAdd(ctx, key, sessionID)
	client.Expire(ctx, key, sessionStateTTL)
	return nil
}

func (r *RedisCache) RemoveRoomSession(ctx context.Context, roomID string, sessionID string) error {
	key := fmt.Sprintf("mp:room:%s:sessions", roomID)
	client := r.cache.GetRedisClient()
	return client.SRem(ctx, key, sessionID).Err()
}

// ── Cleanup ────────────────────────────────────────────────────

func (r *RedisCache) CleanupSession(ctx context.Context, sessionID string) error {
	pattern := fmt.Sprintf("mp:s:%s:*", sessionID)
	return r.cache.DeletePattern(ctx, pattern)
}
