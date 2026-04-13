package auth

import (
	"context"
	"fmt"
	"time"
)

// IdentifyTimeout is the maximum time the gateway waits for the client
// to send OpIdentify after WebSocket upgrade. Per Flicko protocol spec,
// the gateway closes with 4009 (Session Timeout) if this expires.
const IdentifyTimeout = 5 * time.Second

// IdentifyPayload mirrors protocol.IdentifyPayload but is defined here
// to avoid a circular import between auth and protocol packages.
// The ws-gateway converts protocol.IdentifyPayload → auth.IdentifyPayload.
type IdentifyPayload struct {
	Token     string `json:"token"`
	SessionID string `json:"session_id,omitempty"`
	DeviceID  string `json:"device_id"`
}

// ValidateIdentify validates the JWT token from an OpIdentify payload.
//
// This is NOT an HTTP middleware — it is called by the ws-gateway after
// WebSocket upgrade when the client sends OpIdentify. The gateway is
// responsible for:
//   - Reading the first message within IdentifyTimeout (5s)
//   - Decoding the GatewayMessage and extracting IdentifyPayload
//   - Calling ValidateIdentify with the payload
//   - Closing with 4004 (Auth Failed) on error, or proceeding to Ready
//
// Returns the validated *Claims (containing Sub, Roles, DeviceID, etc.)
// or an error if the token is invalid/expired/unknown.
func ValidateIdentify(keySet *KeySet, payload IdentifyPayload) (*Claims, error) {
	if payload.Token == "" {
		return nil, fmt.Errorf("%w: empty token in identify payload", ErrMissingToken)
	}

	claims, err := ValidateToken(keySet, payload.Token)
	if err != nil {
		return nil, fmt.Errorf("auth: identify validation failed: %w", err)
	}

	// Cross-check DeviceID if present in both token and payload.
	// The payload.DeviceID takes precedence for presence tracking,
	// but if the token has a DeviceID, they must match to prevent
	// token theft across devices.
	if claims.DeviceID != "" && payload.DeviceID != "" && claims.DeviceID != payload.DeviceID {
		return nil, fmt.Errorf("%w: device ID mismatch (token=%s, payload=%s)",
			ErrInvalidClaims, claims.DeviceID, payload.DeviceID)
	}

	// If payload provides DeviceID and token didn't, adopt it.
	if claims.DeviceID == "" && payload.DeviceID != "" {
		claims.DeviceID = payload.DeviceID
	}

	return claims, nil
}

// IdentifyWithTimeout wraps ValidateIdentify with a context deadline.
//
// Usage in the gateway:
//
//	ctx, cancel := context.WithTimeout(ctx, auth.IdentifyTimeout)
//	defer cancel()
//	claims, err := auth.IdentifyWithTimeout(ctx, keySet, payload)
//
// If the context is already expired (e.g. the gateway set it before
// waiting for the message), this returns immediately with the ctx error.
func IdentifyWithTimeout(ctx context.Context, keySet *KeySet, payload IdentifyPayload) (*Claims, error) {
	// Check context before doing any work.
	select {
	case <-ctx.Done():
		return nil, fmt.Errorf("auth: identify timed out: %w", ctx.Err())
	default:
	}

	return ValidateIdentify(keySet, payload)
}
