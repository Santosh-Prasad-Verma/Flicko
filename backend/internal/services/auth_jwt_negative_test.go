package services_test

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// signEdDSA crafts an EdDSA token with arbitrary claims signed by the given key.
func signEdDSA(t *testing.T, claims jwt.MapClaims, priv ed25519.PrivateKey, kid string) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	tok.Header["kid"] = kid
	s, err := tok.SignedString(priv)
	require.NoError(t, err)
	return s
}

// TestValidateToken_ExpiredToken asserts an EdDSA token whose exp is in the past
// is rejected.
func TestValidateToken_ExpiredToken(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	// Generate a valid token, then validate an expired one crafted manually.
	kid := services.TestKeyIDFromPublic(pub)
	expired := signEdDSA(t, jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko",
		"exp": 1000000000, // year 2001 — expired
		"iat": 999999000,
	}, priv, kid)

	_, err := svc.ValidateToken(expired)
	assert.Error(t, err, "expired token must be rejected")
}

// TestValidateToken_BadSignature asserts a token signed with a DIFFERENT key
// is rejected. Guards against accepting forged tokens.
func TestValidateToken_BadSignature(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	// Generate a token signed with a completely different keypair.
	_, attackerPriv, _ := ed25519.GenerateKey(rand.Reader)
	kid := services.TestKeyIDFromPublic(pub)
	forged := signEdDSA(t, jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko",
		"exp": 9999999999,
		"iat": 1000000000,
	}, attackerPriv, kid)

	_, err := svc.ValidateToken(forged)
	assert.Error(t, err, "token signed with the wrong key must be rejected")
}

// TestValidateToken_AlgNone asserts an unsigned "alg: none" token is rejected.
func TestValidateToken_AlgNone(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	claims := jwt.MapClaims{
		"sub": "user-123",
		"iss": "flicko",
		"exp": 9999999999,
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	noneToken, err := tok.SignedString(jwt.UnsafeAllowNoneSignatureType)
	require.NoError(t, err)

	_, err = svc.ValidateToken(noneToken)
	assert.Error(t, err, "alg:none token must be rejected (JWT downgrade attack)")
}

// TestValidateToken_TamperedClaims asserts that flipping a byte in the payload
// (without re-signing) invalidates the token.
func TestValidateToken_TamperedClaims(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	valid, err := svc.GenerateToken("user-123", "u@flicko.test")
	require.NoError(t, err)

	// Corrupt a character in the middle (payload segment) — signature no longer matches.
	tampered := valid[:len(valid)/2] + "X" + valid[len(valid)/2+1:]

	_, err = svc.ValidateToken(tampered)
	assert.Error(t, err, "tampered token must be rejected")
}

// TestValidateToken_EmptyAndMalformed asserts empty and garbage strings are rejected.
func TestValidateToken_EmptyAndMalformed(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	for _, tok := range []string{"", "not.a.jwt", "garbage"} {
		_, err := svc.ValidateToken(tok)
		assert.Error(t, err, "malformed token %q must be rejected", tok)
	}
}

// TestValidateToken_ValidTokenAccepted is the positive control: a properly signed,
// unexpired token is accepted and the subject round-trips.
func TestValidateToken_ValidTokenAccepted(t *testing.T) {
	pub, priv := testKeypair(t)
	svc := services.NewAuthService(nil, priv, pub)

	token, err := svc.GenerateToken("user-456", "u@flicko.test")
	require.NoError(t, err)

	claims, err := svc.ValidateToken(token)
	require.NoError(t, err)
	assert.Equal(t, "user-456", claims.Subject)
	assert.Equal(t, "flicko", claims.Issuer)
}
