package handlers

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type contextKey string

const (
	BotIDContextKey = contextKey("botID")
	ScopesContextKey = contextKey("scopes")
)

var botAuthDB *pgxpool.Pool
var botAuthLogger *zap.Logger

// SetBotAuthDB sets the database pool for bot authentication.
func SetBotAuthDB(db *pgxpool.Pool, logger *zap.Logger) {
	botAuthDB = db
	botAuthLogger = logger
}

// BotAuthMiddleware validates flicko_bot_ Bearer tokens against the bot_api_keys table.
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

		parts := strings.SplitN(rawKey, "_", 3)
		if len(parts) != 3 {
			http.Error(w, "malformed API key", http.StatusUnauthorized)
			return
		}

		keyPrefix := parts[0] + "_" + parts[1] + "_" + parts[2][:8]

		if botAuthDB == nil {
			if botAuthLogger != nil {
				botAuthLogger.Error("bot auth db not configured")
			}
			http.Error(w, "internal service error", http.StatusInternalServerError)
			return
		}

		ctx := r.Context()
		query := `
			SELECT eb.id, bak.key_hash, bak.scopes
			FROM bot_api_keys bak
			JOIN external_bots eb ON eb.id = bak.bot_id
			WHERE bak.key_prefix = $1
			  AND bak.revoked = false
			  AND (bak.expires_at IS NULL OR bak.expires_at > now())
			  AND eb.status = 'approved'
		`

		var (
			botID   string
			keyHash string
			scopes  []string
		)

		err := botAuthDB.QueryRow(ctx, query, keyPrefix).Scan(&botID, &keyHash, &scopes)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		if err := auth.CompareAPIKey(rawKey, keyPrefix, keyHash); err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		if requiredScope != "" && !auth.HasScope(scopes, requiredScope) {
			http.Error(w, "insufficient scope", http.StatusForbidden)
			return
		}

		// Update last_used_at asynchronously
		go func() {
			_, err := botAuthDB.Exec(context.Background(),
				`UPDATE bot_api_keys SET last_used_at = now() WHERE key_prefix = $1`, keyPrefix)
			if err != nil && botAuthLogger != nil {
				botAuthLogger.Error("failed to update bot key last_used_at",
					zap.String("prefix", keyPrefix), zap.Error(err))
			}
		}()

		newCtx := context.WithValue(r.Context(), BotIDContextKey, botID)
		newCtx = context.WithValue(newCtx, ScopesContextKey, scopes)
		next.ServeHTTP(w, r.WithContext(newCtx))
	})
}

// BotIDFromContext extracts the bot ID from the request context.
func BotIDFromContext(ctx context.Context) (string, error) {
	botID, ok := ctx.Value(BotIDContextKey).(string)
	if !ok || botID == "" {
		return "", fmt.Errorf("bot ID not found in context")
	}
	return botID, nil
}
