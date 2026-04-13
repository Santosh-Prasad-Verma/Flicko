package middleware

import (
	"net/http"
)

// CORSConfig holds CORS settings.
type CORSConfig struct {
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
	MaxAge         string // seconds
}

// DefaultCORSConfig returns sensible defaults for development.
func DefaultCORSConfig() CORSConfig {
	return CORSConfig{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Authorization", "Content-Type", "X-Request-ID", "Idempotency-Key"},
		MaxAge:         "86400",
	}
}

// CORS returns middleware that handles CORS preflight and headers.
func CORS(cfg CORSConfig) func(http.Handler) http.Handler {
	origins := "*"
	if len(cfg.AllowedOrigins) > 0 && cfg.AllowedOrigins[0] != "*" {
		origins = cfg.AllowedOrigins[0] // simplified: first origin
	}

	methods := "GET, POST, PATCH, DELETE, OPTIONS"
	if len(cfg.AllowedMethods) > 0 {
		methods = joinStrings(cfg.AllowedMethods)
	}

	headers := "Authorization, Content-Type, X-Request-ID"
	if len(cfg.AllowedHeaders) > 0 {
		headers = joinStrings(cfg.AllowedHeaders)
	}

	maxAge := cfg.MaxAge
	if maxAge == "" {
		maxAge = "86400"
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", origins)
			w.Header().Set("Access-Control-Allow-Methods", methods)
			w.Header().Set("Access-Control-Allow-Headers", headers)
			w.Header().Set("Access-Control-Max-Age", maxAge)

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func joinStrings(ss []string) string {
	if len(ss) == 0 {
		return ""
	}
	result := ss[0]
	for _, s := range ss[1:] {
		result += ", " + s
	}
	return result
}
