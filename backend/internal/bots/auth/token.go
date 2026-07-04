package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

var (
	ErrInvalidTokenFormat = errors.New("invalid token format")
	ErrUnknownKeyVersion  = errors.New("unknown token key version")
	ErrInvalidTokenSignature = errors.New("invalid token signature")
)

// GenerateToken creates a 4-segment dot-separated bot token:
// Format: {key_version}.{base64(bot_user_id)}.{base64(issued_at)}.{hmac_signature}
func GenerateToken(botUserID string, keyVersion string, secret []byte) (string, error) {
	if botUserID == "" {
		return "", fmt.Errorf("bot user ID cannot be empty")
	}
	if keyVersion == "" {
		return "", fmt.Errorf("key version cannot be empty")
	}
	if len(secret) == 0 {
		return "", fmt.Errorf("signing secret cannot be empty")
	}

	// 1. Encode Bot User ID
	encodedID := base64.RawURLEncoding.EncodeToString([]byte(botUserID))

	// 2. Encode timestamp (seconds since epoch)
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	encodedTime := base64.RawURLEncoding.EncodeToString([]byte(timestamp))

	// 3. Compute HMAC-SHA256 signature
	// We sign the header + payload: key_version + "." + encodedID + "." + encodedTime
	message := fmt.Sprintf("%s.%s.%s", keyVersion, encodedID, encodedTime)
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(message))
	signature := hex.EncodeToString(mac.Sum(nil))

	// 4. Construct final token string
	return fmt.Sprintf("%s.%s.%s.%s", keyVersion, encodedID, encodedTime, signature), nil
}

// VerifyToken validates the token and returns the bot user ID if valid.
// It accepts a map of valid key versions to their corresponding secrets to support key rotation.
func VerifyToken(tokenStr string, secrets map[string][]byte) (string, error) {
	parts := strings.Split(tokenStr, ".")
	if len(parts) != 4 {
		return "", ErrInvalidTokenFormat
	}

	keyVersion := parts[0]
	encodedID := parts[1]
	encodedTime := parts[2]
	signature := parts[3]

	// 1. Retrieve signing secret for this key version
	secret, ok := secrets[keyVersion]
	if !ok {
		return "", ErrUnknownKeyVersion
	}

	// 2. Verify signature
	message := fmt.Sprintf("%s.%s.%s", keyVersion, encodedID, encodedTime)
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(message))
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(signature), []byte(expectedSignature)) {
		return "", ErrInvalidTokenSignature
	}

	// 3. Decode Bot User ID
	decodedIDBytes, err := base64.RawURLEncoding.DecodeString(encodedID)
	if err != nil {
		return "", fmt.Errorf("failed to decode user ID segment: %w", err)
	}

	return string(decodedIDBytes), nil
}
