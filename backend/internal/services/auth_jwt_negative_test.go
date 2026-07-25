package services_test

import (
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The secret contains '!' and '@', which are not valid base64 alphabet
// characters, so NewAuthService's base64 decode fails and it uses the raw
// bytes. That lets these tests sign crafted tokens with []byte(secret) and
// have them match the service's signing key exactly.
const jwtTestSecret = "supersecretkeylength32byteshere123!@"

// signHS256 crafts an HS256 token with arbitrary claims signed by the given key.
func signHS256(t *testing.T, claims jwt.MapClaims, key []byte) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	s, err := tok.SignedString(key)
	require.NoError(t, err)
	return s
}

// TestValidateToken_ExpiredToken asserts an HS256 token whose exp is in the past
// is rejected. The happy-path test only ever validates a fresh token, so nothing
// currently guards expiry on the live monolith validator.
func TestValidateToken_ExpiredToken(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	expired := signHS256(t, jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko-backend",
		"exp": time.Now().Add(-1 * time.Hour).Unix(),
		"iat": time.Now().Add(-2 * time.Hour).Unix(),
	}, []byte(jwtTestSecret))

	_, err := svc.ValidateToken(expired)
	assert.Error(t, err, "expired token must be rejected")
}

// TestValidateToken_BadSignature asserts a token signed with a DIFFERENT secret
// is rejected. Guards against accepting forged tokens.
func TestValidateToken_BadSignature(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	forged := signHS256(t, jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko-backend",
		"exp": time.Now().Add(time.Hour).Unix(),
	}, []byte("a-totally-different-attacker-secret!@"))

	_, err := svc.ValidateToken(forged)
	assert.Error(t, err, "token signed with the wrong secret must be rejected")
}

// TestValidateToken_AlgNone asserts an unsigned "alg: none" token is rejected.
// This is the classic JWT downgrade attack; the SigningMethodHMAC guard in
// ValidateToken is what stops it, and this test pins that behavior.
func TestValidateToken_AlgNone(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	claims := jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko-backend",
		"exp": time.Now().Add(time.Hour).Unix(),
	}
	// jwt.UnsafeAllowNoneSignatureType is required to produce a none-signed token.
	tok := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	noneToken, err := tok.SignedString(jwt.UnsafeAllowNoneSignatureType)
	require.NoError(t, err)

	_, err = svc.ValidateToken(noneToken)
	assert.Error(t, err, "alg:none token must be rejected (JWT downgrade attack)")
}

// TestValidateToken_TamperedClaims asserts that flipping a byte in the payload
// (without re-signing) invalidates the token.
func TestValidateToken_TamperedClaims(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	valid := signHS256(t, jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko-backend",
		"exp": time.Now().Add(time.Hour).Unix(),
	}, []byte(jwtTestSecret))

	// Corrupt a character in the middle (payload segment) — signature no longer matches.
	tampered := valid[:len(valid)/2] + "X" + valid[len(valid)/2+1:]

	_, err := svc.ValidateToken(tampered)
	assert.Error(t, err, "tampered token must be rejected")
}

// TestValidateToken_EmptyAndMalformed asserts empty and garbage strings are rejected.
func TestValidateToken_EmptyAndMalformed(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	for _, tok := range []string{"", "not.a.jwt", "garbage"} {
		_, err := svc.ValidateToken(tok)
		assert.Error(t, err, "malformed token %q must be rejected", tok)
	}
}

// TestValidateToken_ValidTokenAccepted is the positive control: a properly signed,
// unexpired token is accepted and the subject round-trips.
func TestValidateToken_ValidTokenAccepted(t *testing.T) {
	svc := services.NewAuthService(nil, jwtTestSecret)

	token, err := svc.GenerateToken("user-456", "u@flicko.test")
	require.NoError(t, err)

	claims, err := svc.ValidateToken(token)
	require.NoError(t, err)
	assert.Equal(t, "user-456", claims.Subject)
}
