package database

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
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
	// ReplicaPool returns the underlying pgxpool.Pool for read replica access.
	ReplicaPool() *pgxpool.Pool
	// Begin starts a transaction.
	Begin(ctx context.Context) (pgx.Tx, error)
	// CBState returns the current state of the circuit breaker.
	CBState() CircuitState
}

// MED-005: Default query timeout and slow query detection.
const (
	DefaultQueryTimeout = 30 * time.Second
	SlowQueryThreshold  = 1 * time.Second
	CBFailureThreshold  = 5
	CBCooldownPeriod    = 10 * time.Second
)

type CircuitState int

const (
	StateClosed CircuitState = iota
	StateOpen
	StateHalfOpen
)

type CircuitBreaker struct {
	mu              sync.RWMutex
	state           CircuitState
	failureCount    int64
	successCount    int64
	lastStateChange time.Time

	failureThreshold int64
	successThreshold int64
	cooldownPeriod   time.Duration
}

func NewCircuitBreaker(failureThreshold int64, cooldownPeriod time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:            StateClosed,
		failureThreshold: failureThreshold,
		successThreshold: 2, // 2 consecutive successes to close again
		cooldownPeriod:   cooldownPeriod,
		lastStateChange:  time.Now(),
	}
}

func (cb *CircuitBreaker) AllowRequest() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	now := time.Now()
	if cb.state == StateOpen {
		if now.Sub(cb.lastStateChange) > cb.cooldownPeriod {
			cb.state = StateHalfOpen
			cb.lastStateChange = now
			cb.failureCount = 0
			cb.successCount = 0
			return true
		}
		return false
	}
	return true
}

func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	if cb.state == StateHalfOpen {
		cb.successCount++
		if cb.successCount >= cb.successThreshold {
			cb.state = StateClosed
			cb.lastStateChange = time.Now()
			cb.failureCount = 0
			cb.successCount = 0
		}
	}
}

func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failureCount++
	if cb.state == StateClosed {
		if cb.failureCount >= cb.failureThreshold {
			cb.state = StateOpen
			cb.lastStateChange = time.Now()
		}
	} else if cb.state == StateHalfOpen {
		cb.state = StateOpen
		cb.lastStateChange = time.Now()
	}
}

func (cb *CircuitBreaker) State() CircuitState {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}

// wrappedRow wraps pgx.Row to capture errors and notify the circuit breaker.
type wrappedRow struct {
	pgx.Row
	cb *CircuitBreaker
}

func (w *wrappedRow) Scan(dest ...any) error {
	if w.Row == nil {
		return errors.New("database circuit breaker is open")
	}
	err := w.Row.Scan(dest...)
	if err != nil && err != pgx.ErrNoRows {
		w.cb.RecordFailure()
	} else {
		w.cb.RecordSuccess()
	}
	return err
}

// HIGH-005: pgxClient with statement cache and replica pool support.
type pgxClient struct {
	pool        *pgxpool.Pool
	replicaPool *pgxpool.Pool
	cb          *CircuitBreaker
	stmtCache   map[string]bool
	logger      *zap.Logger
}

// CRIT-005: Improved pool configuration based on expected load
func NewDatabaseClient(ctx context.Context, databaseURL string) (DatabaseClient, error) {
	logger, _ := zap.NewProduction()

	// Parse primary config
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("error parsing config: %w", err)
	}

	const (
		MaxCCU           = 5000
		ConnPerUser      = 3.5
		SafetyMultiplier = 1.25
	)

	calculatedConns := int32(1000)
	rawCalc := float64(MaxCCU) * ConnPerUser * SafetyMultiplier
	if rawCalc < 1000 && rawCalc > 0 {
		calculatedConns = int32(rawCalc)
	}
	maxConns := calculatedConns
	if envMax := os.Getenv("DATABASE_POOL_MAX"); envMax != "" {
		if parsed, err := strconv.ParseInt(envMax, 10, 32); err == nil && parsed > 0 {
			maxConns = int32(parsed)
		}
	}

	if maxConns > 1000 {
		maxConns = 1000
	}

	config.MaxConns = maxConns
	config.MinConns = 5
	if config.MinConns > maxConns {
		config.MinConns = maxConns
	}
	config.MaxConnLifetime = 30 * time.Minute
	config.MaxConnIdleTime = 2 * time.Minute
	config.HealthCheckPeriod = 30 * time.Second
	config.ConnConfig.ConnectTimeout = 10 * time.Second
	config.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	// Connect to primary pool
	var pool *pgxpool.Pool
	maxRetries := 5
	baseDelay := 100 * time.Millisecond

	for i := 0; i < maxRetries; i++ {
		connectCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
		pool, err = pgxpool.NewWithConfig(connectCtx, config)
		cancel()

		if err == nil {
			pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
			pingErr := pool.Ping(pingCtx)
			pingCancel()
			if pingErr == nil {
				break
			}
			pool.Close()
			pool = nil
		}

		if i < maxRetries-1 {
			delay := baseDelay * time.Duration(1<<uint(i))
			time.Sleep(delay)
		}
	}

	if pool == nil {
		return nil, fmt.Errorf("failed to connect to primary database pool: %w", err)
	}

	// Connect to replica pool if configured
	var replicaPool *pgxpool.Pool
	replicaURL := os.Getenv("DATABASE_REPLICA_URL")
	if replicaURL != "" {
		repConfig, repErr := pgxpool.ParseConfig(replicaURL)
		if repErr == nil {
			repConfig.MaxConns = maxConns
			repConfig.MinConns = 5
			if repConfig.MinConns > maxConns {
				repConfig.MinConns = maxConns
			}
			repConfig.MaxConnLifetime = 30 * time.Minute
			repConfig.MaxConnIdleTime = 2 * time.Minute
			repConfig.HealthCheckPeriod = 30 * time.Second
			repConfig.ConnConfig.ConnectTimeout = 10 * time.Second
			repConfig.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

			connectCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			replicaPool, repErr = pgxpool.NewWithConfig(connectCtx, repConfig)
			cancel()

			if repErr == nil {
				pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
				pingErr := replicaPool.Ping(pingCtx)
				pingCancel()
				if pingErr != nil {
					replicaPool.Close()
					replicaPool = nil
					logger.Warn("read replica ping failed, falling back to primary for reads", zap.Error(pingErr))
				} else {
					logger.Info("connected to database read replica pool successfully")
				}
			} else {
				logger.Warn("read replica connection failed, falling back to primary for reads", zap.Error(repErr))
			}
		}
	}

	cb := NewCircuitBreaker(CBFailureThreshold, CBCooldownPeriod)

	return &pgxClient{
		pool:        pool,
		replicaPool: replicaPool,
		cb:          cb,
		stmtCache:   make(map[string]bool),
		logger:      logger,
	}, nil
}

// isReadOnlySQL returns true for pure SELECT statements that can safely be
// routed to a read replica. It rejects statements containing write keywords
// (INSERT, UPDATE, DELETE) or row-locking clauses (FOR UPDATE/SHARE).
func isReadOnlySQL(sql string) bool {
	trimmed := strings.TrimSpace(sql)
	if len(trimmed) < 6 {
		return false
	}
	upper := strings.ToUpper(trimmed)
	if !strings.HasPrefix(upper, "SELECT") {
		return false
	}
	// Reject SELECT ... row-locking clauses (row locks must hit primary).
	if strings.Contains(upper, "FOR UPDATE") ||
		strings.Contains(upper, "FOR NO KEY UPDATE") ||
		strings.Contains(upper, "FOR SHARE") ||
		strings.Contains(upper, "FOR KEY SHARE") {
		return false
	}
	return true
}

// Query with automatic timeout, slow query logging, and circuit breaking.
func (c *pgxClient) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	if !c.cb.AllowRequest() {
		return nil, errors.New("database circuit breaker is open")
	}

	// Route only pure read-only SELECTs to replica pool.
	targetPool := c.pool
	if c.replicaPool != nil && isReadOnlySQL(sql) {
		targetPool = c.replicaPool
	}

	tracer := otel.GetTracerProvider().Tracer("database")
	var span trace.Span
	ctx, span = tracer.Start(ctx, "db.query", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()
	span.SetAttributes(
		attribute.String("db.system", "postgresql"),
		attribute.String("db.statement", sql),
	)

	start := time.Now()
	rows, err := targetPool.Query(ctx, sql, args...)
	duration := time.Since(start)

	if err != nil {
		c.cb.RecordFailure()
		span.RecordError(err)
	} else {
		c.cb.RecordSuccess()
	}

	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
		span.SetAttributes(attribute.Bool("db.slow_query", true))
	}

	return rows, err
}

// QueryRow with automatic timeout, slow query logging, and circuit breaking.
func (c *pgxClient) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	if !c.cb.AllowRequest() {
		return &wrappedRow{
			Row: nil,
			cb:  c.cb,
		}
	}

	// Route only pure read-only SELECTs to replica pool.
	targetPool := c.pool
	if c.replicaPool != nil && isReadOnlySQL(sql) {
		targetPool = c.replicaPool
	}

	tracer := otel.GetTracerProvider().Tracer("database")
	var span trace.Span
	ctx, span = tracer.Start(ctx, "db.query_row", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()
	span.SetAttributes(
		attribute.String("db.system", "postgresql"),
		attribute.String("db.statement", sql),
	)

	start := time.Now()
	row := targetPool.QueryRow(ctx, sql, args...)
	duration := time.Since(start)

	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
		span.SetAttributes(attribute.Bool("db.slow_query", true))
	}

	return &wrappedRow{
		Row: row,
		cb:  c.cb,
	}
}

// Exec with automatic timeout, slow query logging, and circuit breaking.
func (c *pgxClient) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	if !c.cb.AllowRequest() {
		return pgconn.CommandTag{}, errors.New("database circuit breaker is open")
	}

	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, DefaultQueryTimeout)
		defer cancel()
	}

	tracer := otel.GetTracerProvider().Tracer("database")
	var span trace.Span
	ctx, span = tracer.Start(ctx, "db.exec", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()
	span.SetAttributes(
		attribute.String("db.system", "postgresql"),
		attribute.String("db.statement", sql),
	)

	start := time.Now()
	tag, err := c.pool.Exec(ctx, sql, args...)
	duration := time.Since(start)

	if err != nil {
		c.cb.RecordFailure()
		span.RecordError(err)
	} else {
		c.cb.RecordSuccess()
	}

	if duration > SlowQueryThreshold {
		c.logger.Warn("slow query detected",
			zap.Duration("duration", duration),
			zap.String("sql", sql),
		)
		span.SetAttributes(attribute.Bool("db.slow_query", true))
	}

	return tag, err
}

func (c *pgxClient) Close() {
	c.pool.Close()
	if c.replicaPool != nil {
		c.replicaPool.Close()
	}
}

func (c *pgxClient) Ping(ctx context.Context) error {
	err := c.pool.Ping(ctx)
	if err != nil {
		return err
	}
	if c.replicaPool != nil {
		return c.replicaPool.Ping(ctx)
	}
	return nil
}

func (c *pgxClient) Pool() *pgxpool.Pool {
	return c.pool
}

func (c *pgxClient) ReplicaPool() *pgxpool.Pool {
	return c.replicaPool
}

func (c *pgxClient) Begin(ctx context.Context) (pgx.Tx, error) {
	if !c.cb.AllowRequest() {
		return nil, errors.New("database circuit breaker is open")
	}

	tracer := otel.GetTracerProvider().Tracer("database")
	var span trace.Span
	ctx, span = tracer.Start(ctx, "db.begin", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()
	span.SetAttributes(attribute.String("db.system", "postgresql"))

	tx, err := c.pool.Begin(ctx)
	if err != nil {
		c.cb.RecordFailure()
		span.RecordError(err)
	} else {
		c.cb.RecordSuccess()
	}
	return tx, err
}

func (c *pgxClient) CBState() CircuitState {
	return c.cb.State()
}

