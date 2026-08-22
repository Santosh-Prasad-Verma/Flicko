package config

import (
	"testing"
	"time"
)

// --- helpers ---

func setGatewayEnv(t *testing.T) {
	t.Helper()
	t.Setenv("REDIS_URL", "redis://localhost:6379/0")
	t.Setenv("JWT_PUBLIC_KEY_PATH", "/run/secrets/jwt_public_key")
}

func setMsgServiceEnv(t *testing.T) {
	t.Helper()
	t.Setenv("REDIS_URL", "redis://localhost:6379/0")
	t.Setenv("JWT_PUBLIC_KEY_PATH", "/run/secrets/jwt_public_key")
	t.Setenv("DATABASE_URL", "postgresql://localhost:5432/flicko")
	t.Setenv("CLOUDINARY_CLOUD_NAME", "test-cloud")
	t.Setenv("CLOUDINARY_API_KEY", "test-key")
	t.Setenv("CLOUDINARY_API_SECRET", "test-secret")
}

// --- GatewayConfig tests ---

func TestLoadGatewayConfig_Defaults(t *testing.T) {
	setGatewayEnv(t)

	cfg, err := LoadGatewayConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertEqual(t, "ServiceName", cfg.ServiceName, "ws-gateway")
	assertEqual(t, "Environment", cfg.Environment, "development")
	assertEqual(t, "LogLevel", cfg.LogLevel, "info")
	assertEqualInt(t, "WSPort", cfg.WSPort, 8080)
	assertEqualInt(t, "MetricsPort", cfg.MetricsPort, 9100)
	assertEqualInt(t, "MaxConnections", cfg.MaxConnections, 6000)
	assertEqualInt(t, "ReadBufferSize", cfg.ReadBufferSize, 1024)
	assertEqualInt(t, "WriteBufferSize", cfg.WriteBufferSize, 1024)
	assertEqualDur(t, "WriteWait", cfg.WriteWait, 10*time.Second)
	assertEqualDur(t, "PongWait", cfg.PongWait, 60*time.Second)
	assertEqualDur(t, "PingPeriod", cfg.PingPeriod, 54*time.Second)
	assertEqualInt64(t, "MaxMessageSize", cfg.MaxMessageSize, 4096)
	assertEqualDur(t, "SlowConsumerTimeout", cfg.SlowConsumerTimeout, 5*time.Second)
	assertEqualInt(t, "RateLimitMsgPerSec", cfg.RateLimitMsgPerSec, 10)
	assertEqualInt(t, "RateLimitBurst", cfg.RateLimitBurst, 20)
}

func TestLoadGatewayConfig_CustomValues(t *testing.T) {
	setGatewayEnv(t)
	t.Setenv("SERVICE_NAME", "custom-gw")
	t.Setenv("ENVIRONMENT", "production")
	// Required in production; see TestLoadGatewayConfig_ProdRequiresCORSOrigins.
	t.Setenv("CORS_ORIGINS", "https://flicko.dev")
	t.Setenv("WS_PORT", "9090")
	t.Setenv("MAX_CONNECTIONS", "10000")
	t.Setenv("RATE_LIMIT_MSG_PER_SEC", "20")
	t.Setenv("RATE_LIMIT_BURST", "40")
	t.Setenv("PONG_WAIT", "120s")
	t.Setenv("PING_PERIOD", "100s")

	cfg, err := LoadGatewayConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertEqual(t, "ServiceName", cfg.ServiceName, "custom-gw")
	if !cfg.IsProd() {
		t.Error("IsProd() = false, want true")
	}
	assertEqualInt(t, "WSPort", cfg.WSPort, 9090)
	assertEqualInt(t, "MaxConnections", cfg.MaxConnections, 10000)
	assertEqualDur(t, "PongWait", cfg.PongWait, 120*time.Second)
	assertEqualDur(t, "PingPeriod", cfg.PingPeriod, 100*time.Second)
}

func TestLoadGatewayConfig_MissingRedisURL(t *testing.T) {
	t.Setenv("JWT_PUBLIC_KEY_PATH", "/run/secrets/jwt_public_key")
	// REDIS_URL not set
	_, err := LoadGatewayConfig()
	if err == nil {
		t.Fatal("expected error for missing REDIS_URL")
	}
}

func TestLoadGatewayConfig_MissingJWTKeyPath(t *testing.T) {
	t.Setenv("REDIS_URL", "redis://localhost:6379")
	// JWT_PUBLIC_KEY_PATH not set
	_, err := LoadGatewayConfig()
	if err == nil {
		t.Fatal("expected error for missing JWT_PUBLIC_KEY_PATH")
	}
}

func TestLoadGatewayConfig_PingPeriodMustBeLessThanPongWait(t *testing.T) {
	setGatewayEnv(t)
	t.Setenv("PING_PERIOD", "60s")
	t.Setenv("PONG_WAIT", "60s")

	_, err := LoadGatewayConfig()
	if err == nil {
		t.Fatal("expected error when PING_PERIOD >= PONG_WAIT")
	}
}

func TestLoadGatewayConfig_InvalidPort(t *testing.T) {
	setGatewayEnv(t)
	t.Setenv("WS_PORT", "99999")

	_, err := LoadGatewayConfig()
	if err == nil {
		t.Fatal("expected error for invalid port")
	}
}

func TestLoadGatewayConfig_InvalidMaxConnections(t *testing.T) {
	setGatewayEnv(t)
	t.Setenv("MAX_CONNECTIONS", "0")

	_, err := LoadGatewayConfig()
	if err == nil {
		t.Fatal("expected error for MAX_CONNECTIONS=0")
	}
}

// An empty CORS_ORIGINS puts the WebSocket origin check into permissive dev
// mode, so production must refuse to start rather than accept upgrades from
// any origin.
func TestLoadGatewayConfig_ProdRequiresCORSOrigins(t *testing.T) {
	setGatewayEnv(t)
	t.Setenv("ENVIRONMENT", "production")
	// CORS_ORIGINS deliberately unset.

	if _, err := LoadGatewayConfig(); err == nil {
		t.Fatal("expected error for missing CORS_ORIGINS in production")
	}
}

func TestLoadGatewayConfig_DevAllowsEmptyCORSOrigins(t *testing.T) {
	setGatewayEnv(t)
	// ENVIRONMENT defaults to development; CORS_ORIGINS unset.

	cfg, err := LoadGatewayConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertEqual(t, "CORSOrigins", cfg.CORSOrigins, "")
}

// --- MsgServiceConfig tests ---

func TestLoadMsgServiceConfig_Defaults(t *testing.T) {
	setMsgServiceEnv(t)

	cfg, err := LoadMsgServiceConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertEqual(t, "ServiceName", cfg.ServiceName, "msg-service")
	assertEqualInt(t, "HTTPPort", cfg.HTTPPort, 8081)
	assertEqualInt(t, "GRPCPort", cfg.GRPCPort, 9081)
	assertEqualInt(t, "DatabasePoolMax", cfg.DatabasePoolMax, 20)
	assertEqualInt(t, "DatabasePoolMin", cfg.DatabasePoolMin, 5)
	assertEqualInt(t, "BatchInsertSize", cfg.BatchInsertSize, 50)
	assertEqualDur(t, "BatchInsertWindow", cfg.BatchInsertWindow, 50*time.Millisecond)
	assertEqualDur(t, "IdempotencyTTL", cfg.IdempotencyTTL, 300*time.Second)
	assertEqualInt(t, "MetricsPort", cfg.MetricsPort, 9101)
}

func TestLoadMsgServiceConfig_MissingDatabaseURL(t *testing.T) {
	t.Setenv("REDIS_URL", "redis://localhost:6379")
	t.Setenv("JWT_PUBLIC_KEY_PATH", "/run/secrets/jwt_public_key")

	_, err := LoadMsgServiceConfig()
	if err == nil {
		t.Fatal("expected error for missing DATABASE_URL")
	}
}

func TestLoadMsgServiceConfig_PoolMinExceedsMax(t *testing.T) {
	setMsgServiceEnv(t)
	t.Setenv("DATABASE_POOL_MIN", "30")
	t.Setenv("DATABASE_POOL_MAX", "20")

	_, err := LoadMsgServiceConfig()
	if err == nil {
		t.Fatal("expected error when pool min > max")
	}
}

// Production must declare its browser origin allowlist rather than falling back
// to a "*" wildcard.
func TestLoadMsgServiceConfig_ProdRequiresCORSOrigins(t *testing.T) {
	setMsgServiceEnv(t)
	t.Setenv("ENVIRONMENT", "production")
	// CORS_ORIGINS deliberately unset.

	if _, err := LoadMsgServiceConfig(); err == nil {
		t.Fatal("expected error for missing CORS_ORIGINS in production")
	}
}

func TestLoadMsgServiceConfig_ProdWithCORSOrigins(t *testing.T) {
	setMsgServiceEnv(t)
	t.Setenv("ENVIRONMENT", "production")
	t.Setenv("CORS_ORIGINS", "https://flicko.dev,https://app.flicko.dev")

	cfg, err := LoadMsgServiceConfig()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertEqual(t, "CORSOrigins", cfg.CORSOrigins, "https://flicko.dev,https://app.flicko.dev")
}

func TestLoadMsgServiceConfig_InvalidPort(t *testing.T) {
	setMsgServiceEnv(t)
	t.Setenv("HTTP_PORT", "0")

	_, err := LoadMsgServiceConfig()
	if err == nil {
		t.Fatal("expected error for port=0")
	}
}

// --- IsProd ---

func TestIsProd(t *testing.T) {
	tests := []struct {
		env  string
		want bool
	}{
		{"production", true},
		{"Production", true},
		{"PRODUCTION", true},
		{"development", false},
		{"staging", false},
		{"", false},
	}
	for _, tc := range tests {
		b := &BaseConfig{Environment: tc.env}
		if got := b.IsProd(); got != tc.want {
			t.Errorf("IsProd(%q) = %v, want %v", tc.env, got, tc.want)
		}
	}
}

// --- assertion helpers ---

func assertEqual(t *testing.T, name, got, want string) {
	t.Helper()
	if got != want {
		t.Errorf("%s = %q, want %q", name, got, want)
	}
}

func assertEqualInt(t *testing.T, name string, got, want int) {
	t.Helper()
	if got != want {
		t.Errorf("%s = %d, want %d", name, got, want)
	}
}

func assertEqualInt64(t *testing.T, name string, got, want int64) {
	t.Helper()
	if got != want {
		t.Errorf("%s = %d, want %d", name, got, want)
	}
}

func assertEqualDur(t *testing.T, name string, got, want time.Duration) {
	t.Helper()
	if got != want {
		t.Errorf("%s = %v, want %v", name, got, want)
	}
}
