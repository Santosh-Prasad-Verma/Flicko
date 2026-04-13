package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// PoolConfig holds tunables for the pgx connection pool.
// Defaults match Production-Architecture.md.
type PoolConfig struct {
	MaxConns          int32         `env:"DATABASE_POOL_MAX"           envDefault:"20"`
	MinConns          int32         `env:"DATABASE_POOL_MIN"           envDefault:"5"`
	MaxConnLifetime   time.Duration `env:"DATABASE_POOL_MAX_LIFETIME"  envDefault:"1h"`
	MaxConnIdleTime   time.Duration `env:"DATABASE_POOL_MAX_IDLE"      envDefault:"30m"`
	HealthCheckPeriod time.Duration `env:"DATABASE_POOL_HEALTHCHECK"   envDefault:"1m"`
}

// NewPool creates a *pgxpool.Pool configured for Supabase's PgBouncer pooler.
//
// Key settings:
//   - PreferSimpleProtocol=true — required for PgBouncer transaction mode.
//   - Pool size, lifetime, idle, health-check from PoolConfig.
//
// The pool verifies connectivity with a Ping before returning.
func NewPool(ctx context.Context, databaseURL string, cfg PoolConfig, log *zap.Logger) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("repository: parse database URL: %w", err)
	}

	// PgBouncer requires simple protocol (no prepared statements).
	poolCfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	poolCfg.MaxConns = cfg.MaxConns
	poolCfg.MinConns = cfg.MinConns
	poolCfg.MaxConnLifetime = cfg.MaxConnLifetime
	poolCfg.MaxConnIdleTime = cfg.MaxConnIdleTime
	poolCfg.HealthCheckPeriod = cfg.HealthCheckPeriod

	log.Info("connecting to database",
		zap.Int32("max_conns", cfg.MaxConns),
		zap.Int32("min_conns", cfg.MinConns),
		zap.Duration("max_lifetime", cfg.MaxConnLifetime),
		zap.Duration("health_check", cfg.HealthCheckPeriod),
	)

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("repository: create pool: %w", err)
	}

	// Verify connectivity.
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("repository: ping database: %w", err)
	}

	log.Info("database pool ready")
	return pool, nil
}

// DefaultPoolConfig returns production-matching defaults.
func DefaultPoolConfig() PoolConfig {
	return PoolConfig{
		MaxConns:          20,
		MinConns:          5,
		MaxConnLifetime:   time.Hour,
		MaxConnIdleTime:   30 * time.Minute,
		HealthCheckPeriod: time.Minute,
	}
}
