// Package redis provides Redis connectivity, utilities, and domain-specific
// helpers for all Flicko microservices.
package redis

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// NewClient creates a configured go-redis client from a Redis URL.
//
// URL format: redis://:password@host:port/db  (or rediss:// for TLS)
//
// The client is validated with a PING before being returned.
func NewClient(redisURL string, log *zap.Logger) (*goredis.Client, error) {
	opts, err := goredis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("redis: parse URL: %w", err)
	}

	// Pool tuning.
	opts.MaxIdleConns = 5
	opts.PoolSize = 20
	opts.MaxRetries = 3
	opts.DialTimeout = 5 * time.Second
	opts.ReadTimeout = 3 * time.Second
	opts.WriteTimeout = 3 * time.Second

	// OnConnect callback for observability.
	opts.OnConnect = func(ctx context.Context, cn *goredis.Conn) error {
		log.Debug("redis: new connection established")
		return nil
	}

	rdb := goredis.NewClient(opts)

	// Validate connectivity.
	ctx, cancel := context.WithTimeout(context.Background(), opts.DialTimeout)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		rdb.Close()
		return nil, fmt.Errorf("redis: ping failed: %w", err)
	}

	log.Info("redis: connected",
		zap.String("addr", opts.Addr),
		zap.Int("pool_size", opts.PoolSize),
	)
	return rdb, nil
}

// HealthCheck pings the Redis server and returns an error if unreachable.
func HealthCheck(ctx context.Context, rdb *goredis.Client) error {
	return rdb.Ping(ctx).Err()
}

// Close shuts down the Redis client, releasing all connections.
func Close(rdb *goredis.Client) error {
	return rdb.Close()
}
