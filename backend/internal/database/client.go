package database

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// CRIT-003: DatabaseClient interface uses typed pgx results instead of `any`.
type DatabaseClient interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Close()
	Ping(ctx context.Context) error
	// Pool returns the underlying pgxpool.Pool for services that need direct pool access.
	Pool() *pgxpool.Pool
}

// MED-005: Default query timeout and slow query detection.
const (
	DefaultQueryTimeout = 30 * time.Second
	SlowQueryThreshold  = 1 * time.Second
)

// HIGH-005: pgxClient with statement cache support.
type pgxClient struct {
	pool       *pgxpool.Pool
	stmtCache  map[string]bool
	cacheMutex sync.RWMutex
	logger     *zap.Logger
}

// CRIT-005: Improved pool configuration based on expected load
// This replaces the hardcoded 20-connection limit with a calculated value
// based on expected concurrent users and their database access patterns
func NewDatabaseClient(ctx context.Context, databaseURL string) (DatabaseClient, error) {
	logger, _ := zap.NewProduction()

	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("error parsing config: %w", err)
	}

	// CRIT-005: Calculate pool size based on expected load
	// Formula: (Expected CCU × Connections Per Active User × Safety Multiplier)
	const (
		MaxCCU           = 5000 // Expected concurrent users
		ConnPerUser      = 3.5  // Average DB requests per active user
		SafetyMultiplier = 1.25 // 25% headroom for bursts
	)

	calculatedConns := int32(int(float64(MaxCCU) * ConnPerUser * SafetyMultiplier))
	logger.Info("connection pool calculation",
		zap.Int32("calculated_for_load", calculatedConns),
	)

	// Allow override via environment (for Supabase tier limits)
	maxConns := calculatedConns
	if envMax := os.Getenv("DATABASE_POOL_MAX"); envMax != "" {
		if parsed, err := strconv.Atoi(envMax); err == nil && parsed > 0 {
			maxConns = int32(parsed)
			logger.Info("pool size overridden by env",
				zap.Int32("pool_max", maxConns),
			)
		}
	}

	// Supabase tier limits
	var reason string
	if maxConns > 1000 {
		maxConns = 1000 // Pro tier max
		reason = "Supabase Pro tier limit"
	}
	logger.Info("final pool configuration",
		zap.Int32("max_conns", maxConns),
		zap.String("limit_reason", reason),
	)

	config.MaxConns = maxConns
	// Prevent connection storm / NAT table exhaustion on startup over Wi-Fi
	config.MinConns = 5
	if config.MinConns > maxConns {
		config.MinConns = maxConns
	}
	config.MaxConnLifetime = 30 * time.Minute        // Refresh every 30 min
	config.MaxConnIdleTime = 2 * time.Minute         // Aggressive idle cutoff
	config.HealthCheckPeriod = 30 * time.Second      // Detect failures early
	config.ConnConfig.ConnectTimeout = 10 * time.Second

	// pgbouncer transaction-mode pooling doesn't support prepared statements.
	// Use simple protocol to avoid "prepared statement already exists" errors.
	config.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	// Retry logic with exponential backoff
	maxRetries := 5
	baseDelay := 100 * time.Millisecond

	var pool *pgxpool.Pool
	for i := 0; i < maxRetries; i++ {
		connectCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
		pool, err = pgxpool.NewWithConfig(connectCtx, config)
		cancel()

		if err == nil {
			pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
			pingErr := pool.Ping(pingCtx)
			pingCancel()
			if pingErr == nil {
				// Log pool stats
				stats := pool.Stat()
				logger.Info("database pool created successfully",
					zap.Int32("max_conns", config.MaxConns),
					zap.Int32("min_conns", config.MinConns),
					zap.Int32("idle_conns", stats.IdleConns()),
					zap.String("pool_lifetime", "30 minutes"),
				)
				return &pgxClient{
					pool:      pool,
					stmtCache: make(map[string]bool),
					logger:    logger,
				}, nil
			}
			pool.Close()
		}

		if i < maxRetries-1 {
			delay := baseDelay * time.Duration(1<<uint(i))
			logger.Warn("database connection failed, retrying",
				zap.Int("attempt", i+1),
				zap.Duration("delay", delay),
				zap.Error(err),
			)
			time.Sleep(delay)
		}
	}

	return nil, fmt.Errorf("failed to connect to database after %d retries: %w", maxRetries, err)
}

// MED-005: Query with automatic timeout and slow query logging.
func (c *pgxClient) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	// Add timeout if not already set
	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, DefaultQueryTimeout)
		defer cancel()
	}

	start := time.Now()
	rows, err := c.pool.Query(ctx, sql, args...)
	duration := time.Since(start)

	// Log slow queries
	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
	}

	return rows, err
}

// QueryRow with automatic timeout and slow query logging.
func (c *pgxClient) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	// Add timeout if not already set
	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, DefaultQueryTimeout)
		defer cancel()
	}

	start := time.Now()
	row := c.pool.QueryRow(ctx, sql, args...)
	duration := time.Since(start)

	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
	}

	return row
}

// MED-005: Exec with automatic timeout and slow query logging.
func (c *pgxClient) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	// Add timeout if not already set
	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, DefaultQueryTimeout)
		defer cancel()
	}

	start := time.Now()
	tag, err := c.pool.Exec(ctx, sql, args...)
	duration := time.Since(start)

	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
	}

	return tag, err
}

func (c *pgxClient) Close() {
	c.pool.Close()
}

func (c *pgxClient) Ping(ctx context.Context) error {
	return c.pool.Ping(ctx)
}

func (c *pgxClient) Pool() *pgxpool.Pool {
	return c.pool
}
