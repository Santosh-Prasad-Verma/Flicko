package redis

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

// CacheTTL is the default cache TTL (5 min).
const CacheTTL = 300 * time.Second

// Cache provides generic JSON-based caching with per-key TTL.
//
// Key formats:
//
//	flicko:cache:user:{id}
//	flicko:cache:channel:{id}
//	flicko:channel:members:{id}  (Set type — use MembersSet helpers)
type Cache struct {
	rdb *goredis.Client
}

// NewCache creates a Cache.
func NewCache(rdb *goredis.Client) *Cache {
	return &Cache{rdb: rdb}
}

// ---------- Generic Get / Set / Delete ----------

// Get retrieves a cached value and JSON-unmarshals it into dest.
// Returns false if the key does not exist.
func Get[T any](ctx context.Context, c *Cache, key string, dest *T) (bool, error) {
	val, err := c.rdb.Get(ctx, key).Bytes()
	if err == goredis.Nil {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("cache: get %s: %w", key, err)
	}
	if err := json.Unmarshal(val, dest); err != nil {
		return false, fmt.Errorf("cache: unmarshal %s: %w", key, err)
	}
	return true, nil
}

// Set JSON-marshals value and stores it with the given TTL.
// If ttl is 0, CacheTTL (300s) is used.
func Set[T any](ctx context.Context, c *Cache, key string, value T, ttl time.Duration) error {
	if ttl <= 0 {
		ttl = CacheTTL
	}
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("cache: marshal %s: %w", key, err)
	}
	return c.rdb.Set(ctx, key, data, ttl).Err()
}

// Delete removes a cached key.
func (c *Cache) Delete(ctx context.Context, key string) error {
	return c.rdb.Del(ctx, key).Err()
}

// ---------- Convenience key builders ----------

// UserKey returns the cache key for a user profile.
func UserKey(userID string) string {
	return "flicko:cache:user:" + userID
}

// ChannelKey returns the cache key for channel metadata.
func ChannelKey(channelID string) string {
	return "flicko:cache:channel:" + channelID
}

// ChannelMembersKey returns the key for a channel's member set.
func ChannelMembersKey(channelID string) string {
	return "flicko:channel:members:" + channelID
}

// ---------- Channel Members Set ----------

// SetChannelMembers stores the member set for a channel.
func (c *Cache) SetChannelMembers(ctx context.Context, channelID string, userIDs []string, ttl time.Duration) error {
	if ttl <= 0 {
		ttl = CacheTTL
	}
	key := ChannelMembersKey(channelID)

	pipe := c.rdb.Pipeline()
	pipe.Del(ctx, key) // replace existing set

	if len(userIDs) > 0 {
		members := make([]interface{}, len(userIDs))
		for i, id := range userIDs {
			members[i] = id
		}
		pipe.SAdd(ctx, key, members...)
	}
	pipe.Expire(ctx, key, ttl)

	_, err := pipe.Exec(ctx)
	return err
}

// GetChannelMembers returns the cached member set for a channel.
// Returns nil, nil if the key does not exist.
func (c *Cache) GetChannelMembers(ctx context.Context, channelID string) ([]string, error) {
	key := ChannelMembersKey(channelID)
	exists, err := c.rdb.Exists(ctx, key).Result()
	if err != nil {
		return nil, fmt.Errorf("cache: exists %s: %w", key, err)
	}
	if exists == 0 {
		return nil, nil
	}
	return c.rdb.SMembers(ctx, key).Result()
}

// IsChannelMember checks if a user is in the cached member set.
func (c *Cache) IsChannelMember(ctx context.Context, channelID, userID string) (bool, error) {
	key := ChannelMembersKey(channelID)
	return c.rdb.SIsMember(ctx, key, userID).Result()
}

// AddChannelMember adds a user to the cached member set.
func (c *Cache) AddChannelMember(ctx context.Context, channelID, userID string) error {
	key := ChannelMembersKey(channelID)
	return c.rdb.SAdd(ctx, key, userID).Err()
}

// RemoveChannelMember removes a user from the cached member set.
func (c *Cache) RemoveChannelMember(ctx context.Context, channelID, userID string) error {
	key := ChannelMembersKey(channelID)
	return c.rdb.SRem(ctx, key, userID).Err()
}
