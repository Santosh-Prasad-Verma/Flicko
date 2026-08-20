// Package shared provides common dependencies for all Flicko jobs.
package shared

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// Deps holds shared resources (database, Redis, config) used by all jobs.
type Deps struct {
	DB  *pgxpool.Pool
	RDB *goredis.Client
	Log *zap.Logger

	// Config values from env.
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string
	AppURL       string
}

// NewDeps initialises shared dependencies from environment variables.
func NewDeps(ctx context.Context, log *zap.Logger) (*Deps, error) {
	// ── PostgreSQL ───────────────────────────────────────────
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	poolCfg, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	poolCfg.MaxConns = 5 // Jobs don't need many connections.
	poolCfg.MinConns = 1

	db, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("connect postgres: %w", err)
	}

	if err := db.Ping(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	log.Info("postgres: connected", zap.String("host", poolCfg.ConnConfig.Host))

	// ── Redis ────────────────────────────────────────────────
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		return nil, fmt.Errorf("REDIS_URL is required")
	}

	opts, err := goredis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse REDIS_URL: %w", err)
	}
	opts.MaxIdleConns = 2
	opts.PoolSize = 5

	rdb := goredis.NewClient(opts)
	if err := rdb.Ping(ctx).Err(); err != nil {
		rdb.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}
	log.Info("redis: connected", zap.String("addr", opts.Addr))

	return &Deps{
		DB:           db,
		RDB:          rdb,
		Log:          log,
		SMTPHost:     getEnv("SMTP_HOST", "smtp-relay.brevo.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USERNAME"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getEnv("SMTP_FROM", "noreply@flicko.dev"),
		AppURL:       getEnv("APP_URL", "https://flicko.dev"),
	}, nil
}

// Close releases all shared resources.
func (d *Deps) Close() {
	if d.DB != nil {
		d.DB.Close()
	}
	if d.RDB != nil {
		d.RDB.Close()
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
