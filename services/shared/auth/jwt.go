package auth

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/flicko-org/flicko/services/shared/id"
)

// Token lifetimes. Access tokens are short-lived; refresh tokens are
// long-lived and stored server-side (Redis) for revocation.
const (
	AccessTokenTTL  = 15 * time.Minute
	RefreshTokenTTL = 30 * 24 * time.Hour // 30 days
	Issuer          = "flicko"
)

// Signing method — Ed25519 (EdDSA). Constant reference avoids typos.
var signingMethod = jwt.SigningMethodEdDSA

// Standard sentinel errors.
var (
	ErrMissingToken    = errors.New("auth: missing token")
	ErrMalformedToken  = errors.New("auth: malformed token")
	ErrExpiredToken    = errors.New("auth: token expired")
	ErrInvalidToken    = errors.New("auth: invalid token")
	ErrUnknownKeyID    = errors.New("auth: unknown key ID (kid)")
	ErrInvalidClaims   = errors.New("auth: invalid claims")
	ErrWrongSignMethod = errors.New("auth: unexpected signing method")
)

// ---------- Claims ----------

// Claims represents the JWT payload for Flicko access tokens.
type Claims struct {
	jwt.RegisteredClaims

	// Roles holds the user's role slugs (e.g. ["admin", "moderator"]).
	Roles []string `json:"roles,omitempty"`

	// DeviceID identifies the client device (used for presence tracking
	// and per-device session management).
	DeviceID string `json:"did,omitempty"`
}

// ---------- Key ID ----------

// KeyIDFromPublic derives a deterministic Key ID (kid) from an Ed25519
// public key. The kid is the first 16 hex chars of SHA-256(raw public key).
//
// This allows the same kid to be computed independently by anyone who
// has the public key, enabling key rotation without shared state.
func KeyIDFromPublic(pub ed25519.PublicKey) string {
	h := sha256.Sum256(pub)
	return hex.EncodeToString(h[:8]) // 16 hex chars
}

// ---------- KeySet (key rotation) ----------

// KeySet holds multiple public keys indexed by Key ID (kid).
// During key rotation, both old and new keys are present so tokens
// signed with the old key remain valid until they expire.
//
// KeySet is safe for concurrent reads after construction.
// Use NewKeySet or NewKeySetBuilder for construction.
type KeySet struct {
	mu   sync.RWMutex
	keys map[string]ed25519.PublicKey
}

// NewKeySet creates a KeySet from one or more public keys.
// Key IDs are derived automatically via KeyIDFromPublic.
func NewKeySet(pubs ...ed25519.PublicKey) *KeySet {
	ks := &KeySet{keys: make(map[string]ed25519.PublicKey, len(pubs))}
	for _, pub := range pubs {
		kid := KeyIDFromPublic(pub)
		ks.keys[kid] = pub
	}
	return ks
}

// Add registers a public key in the keyset. Safe for concurrent use.
func (ks *KeySet) Add(pub ed25519.PublicKey) string {
	kid := KeyIDFromPublic(pub)
	ks.mu.Lock()
	ks.keys[kid] = pub
	ks.mu.Unlock()
	return kid
}

// Remove deletes a key by kid. Returns true if the key existed.
func (ks *KeySet) Remove(kid string) bool {
	ks.mu.Lock()
	_, existed := ks.keys[kid]
	delete(ks.keys, kid)
	ks.mu.Unlock()
	return existed
}

// Get returns the public key for a kid, or nil if not found.
func (ks *KeySet) Get(kid string) ed25519.PublicKey {
	ks.mu.RLock()
	pub := ks.keys[kid]
	ks.mu.RUnlock()
	return pub
}

// Len returns the number of keys in the set.
func (ks *KeySet) Len() int {
	ks.mu.RLock()
	n := len(ks.keys)
	ks.mu.RUnlock()
	return n
}

// ---------- Token generation ----------

// GenerateAccessToken creates a signed JWT access token with 15-minute TTL.
//
// The kid (Key ID) is embedded in the token header so validators can
// select the correct public key from a KeySet.
func GenerateAccessToken(priv ed25519.PrivateKey, claims *Claims) (string, error) {
	now := time.Now().UTC()
	kid := KeyIDFromPublic(priv.Public().(ed25519.PublicKey))

	// Ensure Jti is set (use ULID for uniqueness + time-ordering).
	if claims.ID == "" {
		claims.ID = id.New()
	}

	claims.IssuedAt = jwt.NewNumericDate(now)
	claims.ExpiresAt = jwt.NewNumericDate(now.Add(AccessTokenTTL))
	claims.Issuer = Issuer

	token := jwt.NewWithClaims(signingMethod, claims)
	token.Header["kid"] = kid

	signed, err := token.SignedString(priv)
	if err != nil {
		return "", fmt.Errorf("auth: sign access token: %w", err)
	}
	return signed, nil
}

// GenerateRefreshToken creates a signed JWT refresh token with 30-day TTL.
//
// Refresh tokens carry minimal claims (sub + device_id only) and are
// validated + revoked server-side in Redis.
func GenerateRefreshToken(priv ed25519.PrivateKey, userID, deviceID string) (string, error) {
	now := time.Now().UTC()
	kid := KeyIDFromPublic(priv.Public().(ed25519.PublicKey))

	claims := &Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ID:        id.New(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(RefreshTokenTTL)),
			Issuer:    Issuer,
		},
		DeviceID: deviceID,
	}

	token := jwt.NewWithClaims(signingMethod, claims)
	token.Header["kid"] = kid

	signed, err := token.SignedString(priv)
	if err != nil {
		return "", fmt.Errorf("auth: sign refresh token: %w", err)
	}
	return signed, nil
}

// ---------- Token validation ----------

// ValidateToken parses and validates a JWT string against the provided
// KeySet. It enforces:
//   - EdDSA signing method
//   - kid header present and matching a key in the set
//   - Standard claims: exp, iat, iss=flicko
//
// Returns the parsed Claims on success.
func ValidateToken(keySet *KeySet, tokenString string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		// Verify signing method.
		if t.Method.Alg() != signingMethod.Alg() {
			return nil, fmt.Errorf("%w: got %s", ErrWrongSignMethod, t.Method.Alg())
		}

		// Extract kid from header.
		kidRaw, ok := t.Header["kid"]
		if !ok {
			return nil, ErrUnknownKeyID
		}
		kid, ok := kidRaw.(string)
		if !ok || kid == "" {
			return nil, ErrUnknownKeyID
		}

		// Look up key.
		pub := keySet.Get(kid)
		if pub == nil {
			return nil, fmt.Errorf("%w: %s", ErrUnknownKeyID, kid)
		}

		return pub, nil
	},
		jwt.WithValidMethods([]string{signingMethod.Alg()}),
		jwt.WithIssuer(Issuer),
		jwt.WithIssuedAt(),
		jwt.WithExpirationRequired(),
	)

	if err != nil {
		// Map specific jwt/v5 errors to our sentinel errors.
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrExpiredToken
		}
		if errors.Is(err, jwt.ErrTokenMalformed) {
			return nil, ErrMalformedToken
		}
		if errors.Is(err, jwt.ErrSignatureInvalid) {
			return nil, ErrInvalidToken
		}
		return nil, fmt.Errorf("%w: %s", ErrInvalidToken, err)
	}

	if !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

// ValidateTokenSingleKey is a convenience for services that use a single
// public key (no rotation). It builds a temporary KeySet internally.
func ValidateTokenSingleKey(pub ed25519.PublicKey, tokenString string) (*Claims, error) {
	return ValidateToken(NewKeySet(pub), tokenString)
}
