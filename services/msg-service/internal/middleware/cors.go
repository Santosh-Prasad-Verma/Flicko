package middleware

import (
	"net/http"
	"strings"
)

// CORSConfig holds CORS settings.
type CORSConfig struct {
	// AllowedOrigins is the exact-match allowlist of browser origins, e.g.
	// "https://flicko.tech". A request whose Origin is absent from this list
	// receives no Access-Control-Allow-Origin header and is therefore blocked
	// by the browser.
	AllowedOrigins []string

	// AllowAllOrigins responds with a "*" wildcard regardless of the request
	// Origin. Development only — NewCORSConfig refuses to set this in
	// production. Note that "*" is incompatible with credentialed requests,
	// which is acceptable here because this service authenticates via the
	// Authorization header rather than cookies.
	AllowAllOrigins bool

	AllowedMethods []string
	AllowedHeaders []string
	MaxAge         string // seconds
}

// NewCORSConfig builds a CORSConfig from a comma-separated origin list.
//
// In production an empty list yields a config that permits no browser origin,
// rather than falling open to a wildcard. In development an empty list keeps
// the permissive wildcard so local tooling works without configuration.
func NewCORSConfig(originsCSV string, isProd bool) CORSConfig {
	var origins []string
	for _, o := range strings.Split(originsCSV, ",") {
		if o = strings.TrimSpace(o); o != "" && o != "*" {
			origins = append(origins, o)
		}
	}

	return CORSConfig{
		AllowedOrigins:  origins,
		AllowAllOrigins: len(origins) == 0 && !isProd,
		AllowedMethods:  []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:  []string{"Authorization", "Content-Type", "X-Request-ID", "Idempotency-Key"},
		MaxAge:          "86400",
	}
}

// DefaultCORSConfig returns permissive defaults for development.
//
// Deprecated: prefer NewCORSConfig, which derives the origin allowlist from
// configuration and fails closed in production.
func DefaultCORSConfig() CORSConfig {
	return NewCORSConfig("", false)
}

// CORS returns middleware that handles CORS preflight and headers.
//
// The request's own Origin is echoed back when it matches the allowlist, so
// every configured origin works — the previous implementation only ever
// honored the first entry.
func CORS(cfg CORSConfig) func(http.Handler) http.Handler {
	allowed := make(map[string]bool, len(cfg.AllowedOrigins))
	for _, o := range cfg.AllowedOrigins {
		if o = strings.TrimSpace(strings.ToLower(o)); o != "" {
			allowed[o] = true
		}
	}

	methods := joinStrings(cfg.AllowedMethods)
	if methods == "" {
		methods = "GET, POST, PATCH, DELETE, OPTIONS"
	}

	headers := joinStrings(cfg.AllowedHeaders)
	if headers == "" {
		headers = "Authorization, Content-Type, X-Request-ID"
	}

	maxAge := cfg.MaxAge
	if maxAge == "" {
		maxAge = "86400"
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := strings.TrimSpace(r.Header.Get("Origin"))

			// The response depends on Origin, so shared caches must not serve
			// one origin's response to another. Declared even when the origin is
			// rejected, since that outcome is origin-dependent too.
			w.Header().Add("Vary", "Origin")

			switch {
			case cfg.AllowAllOrigins:
				w.Header().Set("Access-Control-Allow-Origin", "*")
			case origin != "" && allowed[strings.ToLower(origin)]:
				w.Header().Set("Access-Control-Allow-Origin", origin)
			}

			if r.Method == http.MethodOptions {
				w.Header().Set("Access-Control-Allow-Methods", methods)
				w.Header().Set("Access-Control-Allow-Headers", headers)
				w.Header().Set("Access-Control-Max-Age", maxAge)
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
