package message_summary

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/models"
)

// CachedSummary is the JSON value persisted in Redis under the answer key.
type CachedSummary struct {
	Bullets      []models.SummaryBullet `json:"bullets"`
	Participants []string               `json:"participants"`
	Sentiment    string                 `json:"sentiment"`
	Model        string                 `json:"model"`
	TokensIn     int                    `json:"tokens_in"`
	TokensOut    int                    `json:"tokens_out"`
	GeneratedAt  time.Time              `json:"generated_at"`
}

// CacheTTL controls how long a summary is reused. Short enough that the
// experience is "live", long enough to amortise expensive generations across
// users opening the same channel.
const CacheTTL = time.Hour

// CacheStore is a thin wrapper around the shared CacheLayer scoped to summary
// keys.
type CacheStore struct {
	c cache.CacheLayer
}

// NewCacheStore constructs a CacheStore backed by the global cache.
func NewCacheStore(c cache.CacheLayer) *CacheStore {
	return &CacheStore{c: c}
}

// Get returns a cached summary if one exists for the given key.
// errCacheMiss is returned when the key is absent.
func (s *CacheStore) Get(ctx context.Context, key string) (*CachedSummary, error) {
	if s == nil || s.c == nil {
		return nil, errCacheMiss
	}
	raw, err := s.c.Get(ctx, key)
	if err != nil {
		return nil, errCacheMiss
	}
	if raw == "" {
		return nil, errCacheMiss
	}
	var cs CachedSummary
	if err := json.Unmarshal([]byte(raw), &cs); err != nil {
		return nil, errCacheMiss
	}
	return &cs, nil
}

// Set writes the summary at key with a fixed TTL. Errors are swallowed and
// logged by the caller; a cache write failure should not break the request.
func (s *CacheStore) Set(ctx context.Context, key string, cs CachedSummary) error {
	if s == nil || s.c == nil {
		return nil
	}
	cs.GeneratedAt = time.Now().UTC()
	buf, err := json.Marshal(cs)
	if err != nil {
		return err
	}
	return s.c.Set(ctx, key, string(buf), CacheTTL)
}

// errCacheMiss is sentinel for "no cache hit, proceed".
var errCacheMiss = errors.New("cache miss")

// IsCacheMiss reports whether err is the sentinel cache-miss value.
func IsCacheMiss(err error) bool {
	return errors.Is(err, errCacheMiss)
}
