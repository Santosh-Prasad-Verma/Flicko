package redis

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

// IdempotencyTTL is the default TTL for idempotency keys (5 min client retry window).
const IdempotencyTTL = 300 * time.Second

// IdempotencyStore provides nonce-based request deduplication via Redis.
// Key format: flicko:idempotency:{nonce}
type IdempotencyStore struct {
	rdb *goredis.Client
}

// NewIdempotencyStore creates an IdempotencyStore.
func NewIdempotencyStore(rdb *goredis.Client) *IdempotencyStore {
	return &IdempotencyStore{rdb: rdb}
}

// Client returns the underlying Redis client.
// Useful for passing to middleware that needs direct redis.Cmdable access.
func (s *IdempotencyStore) Client() *goredis.Client {
	return s.rdb
}

// Store saves a response payload for a nonce with the given TTL.
// If ttl is 0, IdempotencyTTL (300s) is used.
func (s *IdempotencyStore) Store(ctx context.Context, nonce string, response []byte, ttl time.Duration) error {
	if ttl <= 0 {
		ttl = IdempotencyTTL
	}
	key := "flicko:idempotency:" + nonce
	return s.rdb.Set(ctx, key, response, ttl).Err()
}

// Get retrieves a cached response for a nonce.
// Returns (response, true, nil) on hit, (nil, false, nil) on miss.
func (s *IdempotencyStore) Get(ctx context.Context, nonce string) ([]byte, bool, error) {
	key := "flicko:idempotency:" + nonce
	val, err := s.rdb.Get(ctx, key).Bytes()
	if err == goredis.Nil {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("idempotency: get %s: %w", nonce, err)
	}
	return val, true, nil
}

// Delete removes an idempotency key (useful in tests or manual cleanup).
func (s *IdempotencyStore) Delete(ctx context.Context, nonce string) error {
	key := "flicko:idempotency:" + nonce
	return s.rdb.Del(ctx, key).Err()
}
