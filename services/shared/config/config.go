// Package config provides environment-based configuration loading
// for all Flicko microservices (ws-gateway, msg-service).
//
// Design decisions:
//   - Env vars only (12-factor). No config files.
//   - Uses github.com/caarlos0/env/v10 for struct-tag parsing.
//   - Each service calls LoadGatewayConfig / LoadMsgServiceConfig.
//   - Validation: fail-fast on missing required values, port range,
//     PingPeriod < PongWait invariant.
//   - Defaults match Production-Architecture.md exactly.
package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/caarlos0/env/v10"
)

// ---------- Base (shared by every service) ----------

// BaseConfig contains fields common to all Flicko services.
type BaseConfig struct {
	ServiceName string `env:"SERVICE_NAME"`
	Environment string `env:"ENVIRONMENT"  envDefault:"development"`
	LogLevel    string `env:"LOG_LEVEL"    envDefault:"info"`

	// Redis (Upstash cloud — connection via URL which includes auth + TLS)
	RedisURL string `env:"REDIS_URL,required"`
	// RedisPassword and RedisDB are legacy — auth is embedded in REDIS_URL.
	// Kept for backward compatibility but unused by redis client code.
	RedisPassword string `env:"REDIS_PASSWORD"`
	RedisDB       int    `env:"REDIS_DB" envDefault:"0"`

	// JWT (Ed25519 public key for verification)
	JWTPublicKeyPath string `env:"JWT_PUBLIC_KEY_PATH,required"`
}

// IsProd returns true when the environment is "production".
func (b *BaseConfig) IsProd() bool {
	return strings.EqualFold(b.Environment, "production")
}

// ---------- WS-Gateway ----------

// GatewayConfig is the configuration for the ws-gateway service.
type GatewayConfig struct {
	BaseConfig

	// Server
	WSPort      int `env:"WS_PORT" envDefault:"8080"`
	MetricsPort int `env:"WS_METRICS_PORT" envDefault:"9100"`

	// Connection limits
	MaxConnections  int `env:"MAX_CONNECTIONS"  envDefault:"6000"`
	ReadBufferSize  int `env:"READ_BUFFER_SIZE" envDefault:"1024"`
	WriteBufferSize int `env:"WRITE_BUFFER_SIZE" envDefault:"1024"`

	// Timeouts
	WriteWait  time.Duration `env:"WRITE_WAIT"  envDefault:"10s"`
	PongWait   time.Duration `env:"PONG_WAIT"   envDefault:"60s"`
	PingPeriod time.Duration `env:"PING_PERIOD"  envDefault:"54s"`

	// Message limits
	MaxMessageSize int64 `env:"MAX_MESSAGE_SIZE" envDefault:"4096"`

	// Slow consumer
	SlowConsumerTimeout time.Duration `env:"SLOW_CONSUMER_TIMEOUT" envDefault:"5s"`

	// Send channel
	SendChannelSize int `env:"SEND_CHANNEL_SIZE" envDefault:"256"`

	// Rate limiting
	RateLimitMsgPerSec int `env:"RATE_LIMIT_MSG_PER_SEC" envDefault:"10"`
	RateLimitBurst     int `env:"RATE_LIMIT_BURST"       envDefault:"20"`

	// Internal service URLs
	MsgServiceURL string `env:"MSG_SERVICE_URL" envDefault:"http://msg-service:8081"`

	// CORS allowed origins (comma-separated). Empty = allow all in dev.
	CORSOrigins string `env:"CORS_ORIGINS"`

	// Instance ID (unique per gateway; auto-generated if empty).
	InstanceID string `env:"INSTANCE_ID"`
}

// LoadGatewayConfig parses environment variables into a GatewayConfig
// and validates the result.
func LoadGatewayConfig() (*GatewayConfig, error) {
	cfg := &GatewayConfig{}
	cfg.ServiceName = "ws-gateway" // default before parse
	if err := env.Parse(cfg); err != nil {
		return nil, fmt.Errorf("config: %w", err)
	}
	if cfg.ServiceName == "" {
		cfg.ServiceName = "ws-gateway"
	}
	if err := validateGateway(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func validateGateway(c *GatewayConfig) error {
	if err := validatePort(c.WSPort, "WS_PORT"); err != nil {
		return err
	}
	if err := validatePort(c.MetricsPort, "WS_METRICS_PORT"); err != nil {
		return err
	}
	if c.PingPeriod >= c.PongWait {
		return fmt.Errorf("config: PING_PERIOD (%s) must be less than PONG_WAIT (%s)",
			c.PingPeriod, c.PongWait)
	}
	if c.MaxConnections <= 0 {
		return fmt.Errorf("config: MAX_CONNECTIONS must be > 0, got %d", c.MaxConnections)
	}
	if c.MaxMessageSize <= 0 {
		return fmt.Errorf("config: MAX_MESSAGE_SIZE must be > 0, got %d", c.MaxMessageSize)
	}
	if c.RateLimitMsgPerSec <= 0 {
		return fmt.Errorf("config: RATE_LIMIT_MSG_PER_SEC must be > 0, got %d", c.RateLimitMsgPerSec)
	}
	if c.RateLimitBurst <= 0 {
		return fmt.Errorf("config: RATE_LIMIT_BURST must be > 0, got %d", c.RateLimitBurst)
	}
	return nil
}

// ---------- Message Service ----------

// MsgServiceConfig is the configuration for the msg-service.
type MsgServiceConfig struct {
	BaseConfig

	// Server
	HTTPPort    int `env:"HTTP_PORT" envDefault:"8081"`
	GRPCPort    int `env:"GRPC_PORT" envDefault:"9081"`
	MetricsPort int `env:"MSG_METRICS_PORT" envDefault:"9101"`

	// Database (Supabase PostgreSQL via pooler)
	DatabaseURL     string `env:"DATABASE_URL,required"`
	DatabasePoolMax int    `env:"DATABASE_POOL_MAX" envDefault:"20"`
	DatabasePoolMin int    `env:"DATABASE_POOL_MIN" envDefault:"5"`

	// Idempotency
	IdempotencyTTL time.Duration `env:"IDEMPOTENCY_TTL" envDefault:"300s"`

	// Batch inserts
	BatchInsertSize   int           `env:"BATCH_INSERT_SIZE"   envDefault:"50"`
	BatchInsertWindow time.Duration `env:"BATCH_INSERT_WINDOW" envDefault:"50ms"`
}

// LoadMsgServiceConfig parses environment variables into a
// MsgServiceConfig and validates the result.
func LoadMsgServiceConfig() (*MsgServiceConfig, error) {
	cfg := &MsgServiceConfig{}
	cfg.ServiceName = "msg-service" // default before parse
	if err := env.Parse(cfg); err != nil {
		return nil, fmt.Errorf("config: %w", err)
	}
	if cfg.ServiceName == "" {
		cfg.ServiceName = "msg-service"
	}
	if err := validateMsgService(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func validateMsgService(c *MsgServiceConfig) error {
	if err := validatePort(c.HTTPPort, "HTTP_PORT"); err != nil {
		return err
	}
	if err := validatePort(c.GRPCPort, "GRPC_PORT"); err != nil {
		return err
	}
	if err := validatePort(c.MetricsPort, "MSG_METRICS_PORT"); err != nil {
		return err
	}
	if c.DatabasePoolMax <= 0 {
		return fmt.Errorf("config: DATABASE_POOL_MAX must be > 0, got %d", c.DatabasePoolMax)
	}
	if c.DatabasePoolMin < 0 {
		return fmt.Errorf("config: DATABASE_POOL_MIN must be >= 0, got %d", c.DatabasePoolMin)
	}
	if c.DatabasePoolMin > c.DatabasePoolMax {
		return fmt.Errorf("config: DATABASE_POOL_MIN (%d) must be <= DATABASE_POOL_MAX (%d)",
			c.DatabasePoolMin, c.DatabasePoolMax)
	}
	if c.BatchInsertSize <= 0 {
		return fmt.Errorf("config: BATCH_INSERT_SIZE must be > 0, got %d", c.BatchInsertSize)
	}
	if c.BatchInsertWindow <= 0 {
		return fmt.Errorf("config: BATCH_INSERT_WINDOW must be > 0, got %s", c.BatchInsertWindow)
	}
	return nil
}

// ---------- Helpers ----------

func validatePort(port int, name string) error {
	if port < 1 || port > 65535 {
		return fmt.Errorf("config: %s must be 1-65535, got %d", name, port)
	}
	return nil
}
