// Package middleware provides HTTP middleware for the msg-service.
//
// Middleware chain order:
//
//	RequestID → Logger → Recovery → CORS → Auth → RateLimit → (route-specific: Idempotency)
package middleware

import (
	"context"
	"net/http"

	"github.com/flicko-org/flicko/services/shared/id"
)

type requestIDKey struct{}

// RequestID injects a unique ULID request ID into the context and
// sets the X-Request-ID response header.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rid := r.Header.Get("X-Request-ID")
		if rid == "" {
			rid = id.New()
		}
		w.Header().Set("X-Request-ID", rid)

		ctx := context.WithValue(r.Context(), requestIDKey{}, rid)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// GetRequestID extracts the request ID from the context.
func GetRequestID(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey{}).(string); ok {
		return v
	}
	return ""
}
