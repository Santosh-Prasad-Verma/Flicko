package auth

import (
	"context"
	"errors"
)

// contextKey is an unexported type to prevent collisions in context.Value.
type contextKey struct{}

// claimsKey is the context key for *Claims.
var claimsKey = contextKey{}

// ContextWithClaims returns a new context with claims attached.
func ContextWithClaims(ctx context.Context, c *Claims) context.Context {
	return context.WithValue(ctx, claimsKey, c)
}

// ClaimsFromContext extracts the *Claims from the request context.
// Returns an error if no claims are present (unauthenticated request).
func ClaimsFromContext(ctx context.Context) (*Claims, error) {
	c, ok := ctx.Value(claimsKey).(*Claims)
	if !ok || c == nil {
		return nil, errors.New("auth: no claims in context")
	}
	return c, nil
}

// UserIDFromContext is a convenience that extracts the user ID (sub claim)
// from the context. Returns "" if no claims are present.
func UserIDFromContext(ctx context.Context) string {
	c, err := ClaimsFromContext(ctx)
	if err != nil {
		return ""
	}
	return c.Subject
}

// DeviceIDFromContext extracts the device ID from the context.
// Returns "" if no claims are present.
func DeviceIDFromContext(ctx context.Context) string {
	c, err := ClaimsFromContext(ctx)
	if err != nil {
		return ""
	}
	return c.DeviceID
}

// HasRole checks if the authenticated user has the given role.
// Returns false if no claims are present.
func HasRole(ctx context.Context, role string) bool {
	c, err := ClaimsFromContext(ctx)
	if err != nil {
		return false
	}
	for _, r := range c.Roles {
		if r == role {
			return true
		}
	}
	return false
}
