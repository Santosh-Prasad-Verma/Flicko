package config_test

import (
	"os"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/stretchr/testify/assert"
)

func TestLoadConfig_Success(t *testing.T) {
	os.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db")
	os.Setenv("REDIS_URL", "redis://localhost:6379")
	os.Setenv("JWT_SECRET", "this-is-a-super-secret-key-that-is-at-least-thirty-two-bytes")

	defer func() {
		os.Clearenv()
	}()

	cfg, err := config.Load()

	assert.NoError(t, err)
	assert.NotNil(t, cfg)
	assert.Equal(t, "postgres://user:pass@localhost:5432/db", cfg.DatabaseURL)
	assert.Equal(t, "redis://localhost:6379", cfg.RedisURL)
	assert.Equal(t, "8080", cfg.PortHTTP)
	assert.Equal(t, "8081", cfg.PortWS)
}

func TestLoadConfig_MissingDatabaseURL(t *testing.T) {
	os.Clearenv()
	os.Setenv("REDIS_URL", "redis://localhost:6379")
	os.Setenv("JWT_SECRET", "this-is-a-super-secret-key-that-is-at-least-thirty-two-bytes")

	cfg, err := config.Load()

	assert.Error(t, err)
	assert.Nil(t, cfg)
	assert.Contains(t, err.Error(), "DATABASE_URL is required")
}

func TestLoadConfig_ShortJWTSecret(t *testing.T) {
	os.Clearenv()
	os.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db")
	os.Setenv("REDIS_URL", "redis://localhost:6379")
	os.Setenv("JWT_SECRET", "short")

	cfg, err := config.Load()

	assert.Error(t, err)
	assert.Nil(t, cfg)
	assert.Contains(t, err.Error(), "JWT_SECRET must be at least 32 characters long")
}
