package auth

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

const (
	PrefixLength = 14 // length of flicko_bot_xyz
	KeySecretLen = 32 // bytes of random entropy
)

// GenerateAPIKey creates a raw token and securely hashes it for storage
func GenerateAPIKey() (rawKey, prefix, hash string, err error) {
	// 1. Generate securely random bytes
	randomBytes := make([]byte, KeySecretLen)
	if _, err := rand.Read(randomBytes); err != nil {
		return "", "", "", fmt.Errorf("failed to generate random key fragments: %w", err)
	}

	// 2. Encode to base64url so it limits character constraints safely (RFC 4648)
	encodedSecret := base64.RawURLEncoding.EncodeToString(randomBytes)

	// 3. Create raw token standard
	// "flicko_bot_" is standard recognizable scheme + unique prefix piece + _ + secret
	prefix = "flicko_bot_" + encodedSecret[:8]
	rawKey = prefix + "_" + encodedSecret[8:]

	// 4. Hash the secret part (bcrypt has cost 12 is appropriate)
	hashed, err := bcrypt.GenerateFromPassword([]byte(encodedSecret[8:]), 12)
	if err != nil {
		return "", "", "", err
	}

	hash = string(hashed)
	return rawKey, prefix, hash, nil
}

// CompareAPIKey checks a raw API key from a request against the stored hash and prefix
func CompareAPIKey(rawKey, storedPrefix, storedHash string) error {
	// Parse raw key (e.g. flicko_bot_ABCDEFGH_XYZ1234...)
	parts := strings.SplitN(rawKey, "_", 3)
	if len(parts) != 3 {
		return fmt.Errorf("malformed API key")
	}

	// Validate prefix
	if parts[0]+"_"+parts[1]+"_"+parts[2][:8] != storedPrefix {
		return fmt.Errorf("API key prefix mismatch")
	}

	// Get secret part and compare
	secretPart := parts[2][8:]
	return bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(secretPart))
}
