package handlers

import (
"context"
"net/http"
"strings"

"github.com/flicko-org/flicko-backend/internal/bots/auth"
)

type contextKey string

const (
BotIDContextKey = contextKey("botID")
ScopesContextKey = contextKey("scopes")
)

// BotAuthMiddleware checks Authorization: Bearer {flicko_bot_xyz} headers against Postgres
func BotAuthMiddleware(requiredScope string, next http.Handler) http.Handler {
return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
authHeader := r.Header.Get("Authorization")
if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
http.Error(w, "missing or malformed Authorization header", http.StatusUnauthorized)
return
}

rawKey := strings.TrimPrefix(authHeader, "Bearer ")
if !strings.HasPrefix(rawKey, "flicko_bot_") {
http.Error(w, "invalid token format", http.StatusUnauthorized)
return
}

// Example Database Lookup pseudo-code
// prefix := parts[0]+"_"+parts[1]+"_"+parts[2][:8]
// storedPrefix, storedHash, scopes := pg.Query("SELECT ... WHERE prefix=$1 AND revoked_at IS NULL", prefix)

storedHash := "$2a$12$e..." // mock bcrypt hash
storedPrefix := "flicko_bot_ABCDEFGH"
grantedScopes := []string{auth.ScopeMessagesWrite, auth.ScopeMessagesRead}

if err := auth.CompareAPIKey(rawKey, storedPrefix, storedHash); err != nil {
http.Error(w, "invalid token", http.StatusUnauthorized)
return
}

if requiredScope != "" && !auth.HasScope(grantedScopes, requiredScope) {
http.Error(w, "insufficient scope", http.StatusForbidden)
return
}

// Proceed
ctx := context.WithValue(r.Context(), BotIDContextKey, "mock-bot-uuid")
ctx = context.WithValue(ctx, ScopesContextKey, grantedScopes)

next.ServeHTTP(w, r.WithContext(ctx))
})
}
