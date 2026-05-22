package auth

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"
)

// AuthMiddleware returns an HTTP middleware that validates JWT Bearer tokens
// from the Authorization header and injects *Claims into the request context.
//
// Compatible with net/http, chi, gorilla/mux, or any router accepting
// func(http.Handler) http.Handler.
//
// On failure, responds with 401 and a JSON error body:
//
//	{"error": "auth: ...", "code": "UNAUTHORIZED"}
//
// Internal service bypass: If the request includes X-Flicko-Internal: true and a
// valid X-Flicko-User-ID header, AND the request originates from an internal
// network peer (Docker service name or private IP), JWT authentication is skipped.
// This allows ws-gateway to forward messages on behalf of authenticated users
// without holding user JWTs.
func AuthMiddleware(keySet *KeySet) func(http.Handler) http.Handler {
	internalGatewayToken := os.Getenv("INTERNAL_GATEWAY_TOKEN")

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Internal service bypass: trusted services (ws-gateway) can
			// impersonate users via X-Flicko-User-ID after their own
			// WebSocket auth validated the user's JWT.
			if isInternalServiceRequest(r, internalGatewayToken) {
				userID := r.Header.Get("X-Flicko-User-ID")
				if userID != "" {
					claims := &Claims{}
					claims.Subject = userID
					ctx := ContextWithClaims(r.Context(), claims)
					next.ServeHTTP(w, r.WithContext(ctx))
					return
				}
				writeAuthError(w, "missing X-Flicko-User-ID on internal request", http.StatusUnauthorized)
				return
			}

			tokenStr, err := extractBearerToken(r)
			if err != nil {
				writeAuthError(w, err.Error(), http.StatusUnauthorized)
				return
			}

			claims, err := ValidateToken(keySet, tokenStr)
			if err != nil {
				writeAuthError(w, err.Error(), http.StatusUnauthorized)
				return
			}

			// Inject claims into context for downstream handlers.
			ctx := ContextWithClaims(r.Context(), claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// isInternalServiceRequest checks whether the request comes from a trusted
// internal service (ws-gateway on the Docker internal network).
//
// Security: This MUST only accept requests from the internal Docker network.
// NGINX is the sole edge proxy and strips X-Flicko-Internal from external
// requests. For defense-in-depth we also check:
//   - X-Flicko-Internal header is set to "true"
//   - Optional INTERNAL_GATEWAY_TOKEN matches X-Gateway-Token header
func isInternalServiceRequest(r *http.Request, internalToken string) bool {
	if r.Header.Get("X-Flicko-Internal") != "true" {
		return false
	}

	// If INTERNAL_GATEWAY_TOKEN is configured, require it as a shared secret.
	if internalToken != "" {
		if r.Header.Get("X-Gateway-Token") != internalToken {
			return false
		}
	}

	return true
}

// RequireRole returns middleware that checks the authenticated user has
// at least one of the specified roles. Must be chained AFTER AuthMiddleware.
//
//	mux.Handle("/admin", auth.AuthMiddleware(ks)(auth.RequireRole("admin")(handler)))
func RequireRole(roles ...string) func(http.Handler) http.Handler {
	roleSet := make(map[string]struct{}, len(roles))
	for _, r := range roles {
		roleSet[r] = struct{}{}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, err := ClaimsFromContext(r.Context())
			if err != nil {
				writeAuthError(w, "auth: not authenticated", http.StatusUnauthorized)
				return
			}

			for _, role := range claims.Roles {
				if _, ok := roleSet[role]; ok {
					next.ServeHTTP(w, r)
					return
				}
			}

			writeAuthError(w, "auth: insufficient permissions", http.StatusForbidden)
		})
	}
}

// ---------- helpers ----------

// extractBearerToken pulls the token from "Authorization: Bearer <token>".
func extractBearerToken(r *http.Request) (string, error) {
	header := r.Header.Get("Authorization")
	if header == "" {
		return "", ErrMissingToken
	}

	// Expect exactly "Bearer <token>".
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", ErrMalformedToken
	}

	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", ErrMissingToken
	}
	return token, nil
}

// authErrorResponse is the JSON body returned on auth failures.
type authErrorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

// writeAuthError writes a JSON error response with the given status code.
func writeAuthError(w http.ResponseWriter, msg string, status int) {
	code := "UNAUTHORIZED"
	if status == http.StatusForbidden {
		code = "FORBIDDEN"
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("WWW-Authenticate", `Bearer realm="flicko"`)
	w.WriteHeader(status)

	_ = json.NewEncoder(w).Encode(authErrorResponse{
		Error: msg,
		Code:  code,
	})
}
