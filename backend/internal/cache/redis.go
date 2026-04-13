package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type CacheLayer interface {
	Get(ctx context.Context, key string) (string, error)
	Set(ctx context.Context, key string, value string, expiration time.Duration) error
	Delete(ctx context.Context, key string) error
	DeletePattern(ctx context.Context, pattern string) error
	GetJSON(ctx context.Context, key string, dest interface{}) error
	SetJSON(ctx context.Context, key string, value interface{}, expiration time.Duration) error
	Exists(ctx context.Context, key string) (bool, error)
	Publish(ctx context.Context, channel string, message interface{}) error
	Subscribe(ctx context.Context, channel string) *redis.PubSub
	Close() error

	// Sorted set operations (for sliding window rate limiting)
	ZAdd(ctx context.Context, key string, score float64, member string) error
	ZCard(ctx context.Context, key string) (int64, error)
	ZRemRangeByScore(ctx context.Context, key, min, max string) error
	ZRangeFirst(ctx context.Context, key string) (int64, error)
	Expire(ctx context.Context, key string, expiration time.Duration) error
	Ping(ctx context.Context) error

	// GetRedisClient returns the underlying Redis client for advanced operations
	GetRedisClient() redis.Cmdable
}

type redisCache struct {
	client *redis.Client
}

func NewRedisCache(redisURL string) (CacheLayer, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse redis url: %w", err)
	}

	opts.PoolSize = 100 // connection pooling

	client := redis.NewClient(opts)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to redis: %w", err)
	}

	return &redisCache{client: client}, nil
}

func (c *redisCache) Get(ctx context.Context, key string) (string, error) {
	val, err := c.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", nil // Return empty string if not found
	}
	return val, err
}

func (c *redisCache) Set(ctx context.Context, key string, value string, expiration time.Duration) error {
	return c.client.Set(ctx, key, value, expiration).Err()
}

func (c *redisCache) Delete(ctx context.Context, key string) error {
	return c.client.Del(ctx, key).Err()
}

func (c *redisCache) DeletePattern(ctx context.Context, pattern string) error {
	iter := c.client.Scan(ctx, 0, pattern, 0).Iterator()
	for iter.Next(ctx) {
		err := c.client.Del(ctx, iter.Val()).Err()
		if err != nil {
			return err
		}
	}
	return iter.Err()
}

func (c *redisCache) GetJSON(ctx context.Context, key string, dest interface{}) error {
	val, err := c.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return fmt.Errorf("key not found")
	}
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(val), dest)
}

func (c *redisCache) SetJSON(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	b, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return c.client.Set(ctx, key, string(b), expiration).Err()
}

func (c *redisCache) Exists(ctx context.Context, key string) (bool, error) {
	val, err := c.client.Exists(ctx, key).Result()
	return val > 0, err
}

func (c *redisCache) Publish(ctx context.Context, channel string, message interface{}) error {
	return c.client.Publish(ctx, channel, message).Err()
}

func (c *redisCache) Subscribe(ctx context.Context, channel string) *redis.PubSub {
	return c.client.Subscribe(ctx, channel)
}

func (c *redisCache) Close() error {
	return c.client.Close()
}

func (c *redisCache) ZAdd(ctx context.Context, key string, score float64, member string) error {
	return c.client.ZAdd(ctx, key, redis.Z{Score: score, Member: member}).Err()
}

func (c *redisCache) ZCard(ctx context.Context, key string) (int64, error) {
	return c.client.ZCard(ctx, key).Result()
}

func (c *redisCache) ZRemRangeByScore(ctx context.Context, key, min, max string) error {
	return c.client.ZRemRangeByScore(ctx, key, min, max).Err()
}

func (c *redisCache) ZRangeFirst(ctx context.Context, key string) (int64, error) {
	res, err := c.client.ZRangeWithScores(ctx, key, 0, 0).Result()
	if err != nil || len(res) == 0 {
		return 0, fmt.Errorf("no entries")
	}
	return int64(res[0].Score), nil
}

func (c *redisCache) Expire(ctx context.Context, key string, expiration time.Duration) error {
	return c.client.Expire(ctx, key, expiration).Err()
}

func (c *redisCache) Ping(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}

// GetRedisClient returns the underlying Redis client for advanced operations
func (c *redisCache) GetRedisClient() redis.Cmdable {
	return c.client
}
