package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestAuthService_PasswordHashing(t *testing.T) {
	svc := services.NewAuthService(nil, "supersecretkey")

	hash, err := svc.HashPassword("validpassword123")
	assert.NoError(t, err)
	assert.NotEmpty(t, hash)

	assert.True(t, svc.CheckPassword(hash, "validpassword123"))
	assert.False(t, svc.CheckPassword(hash, "wrongpassword"))
}

func TestAuthService_PasswordHashTooShort(t *testing.T) {
	svc := services.NewAuthService(nil, "supersecretkey")

	_, err := svc.HashPassword("short")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "password must be at least 8 characters long")
}

func TestAuthService_JWTGenerationValidation(t *testing.T) {
	svc := services.NewAuthService(nil, "supersecretkeylength32byteshere123!@")

	token, err := svc.GenerateToken("user-123", "test@flicko.test")
	assert.NoError(t, err)
	assert.NotEmpty(t, token)

	claims, err := svc.ValidateToken(token)
	assert.NoError(t, err)
	assert.Equal(t, "user-123", claims.Subject)

	// Validate Expiration manually via time functions
	assert.True(t, claims.ExpiresAt.Time.After(time.Now()))
}

func TestAuthService_RegistrationValidation(t *testing.T) {
	svc := services.NewAuthService(nil, "key")
	ctx := context.Background()

	_, _, err := svc.Register(ctx, "a", "valid@email.com", "password123")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "username must be between 2 and 32")

	_, _, err = svc.Register(ctx, "validname", "invalidemail", "password123")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid email format")
}
