package services_test

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

// testKeypair returns a fresh Ed25519 keypair for testing.
func testKeypair(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate test keypair: %v", err)
	}
	return pub, priv
}

func TestAuthService_PasswordHashing(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	hash, err := svc.HashPassword("validpassword123")
	assert.NoError(t, err)
	assert.NotEmpty(t, hash)

	assert.True(t, svc.CheckPassword(hash, "validpassword123"))
	assert.False(t, svc.CheckPassword(hash, "wrongpassword"))
}

func TestAuthService_PasswordHashTooShort(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	_, err := svc.HashPassword("short")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "password must be at least 8 characters long")
}

func TestAuthService_JWTGenerationValidation(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	token, err := svc.GenerateToken("user-123", "test@flicko.test")
	assert.NoError(t, err)
	assert.NotEmpty(t, token)

	claims, err := svc.ValidateToken(token)
	assert.NoError(t, err)
	assert.Equal(t, "user-123", claims.Subject)
	assert.Equal(t, "flicko", claims.Issuer)

	// Validate Expiration manually via time functions
	assert.True(t, claims.ExpiresAt.Time.After(time.Now()))
}

func TestAuthService_RegistrationValidation(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)
	ctx := context.Background()

	_, _, err := svc.Register(ctx, "a", "valid@email.com", "A Name", "password123")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "username must be between 2 and 32")

	_, _, err = svc.Register(ctx, "validname", "invalidemail", "Valid Name", "password123")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid email format")
}

func TestAuthService_VerifyEmailValidation(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)
	ctx := context.Background()

	_, _, err := svc.VerifyEmail(ctx, "", "123456")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "email and verification code are required")

	_, _, err = svc.VerifyEmail(ctx, "user@example.com", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "email and verification code are required")
}

func TestAuthService_ResendVerificationValidation(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)
	ctx := context.Background()

	err := svc.ResendVerification(ctx, "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "email is required")
}
