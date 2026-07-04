package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

type contextKey string

const (
	BotIDContextKey  = contextKey("botID")
	ScopesContextKey = contextKey("scopes")
)

var botAuthDB *pgxpool.Pool
var botAuthLogger *zap.Logger
var botTokenSecrets map[string][]byte
var botAuthRedis redis.Cmdable

// SetBotAuthDB sets the database pool and dependencies for bot authentication.
func SetBotAuthDB(db *pgxpool.Pool, jwtSecret string, rdb redis.Cmdable, logger *zap.Logger) {
	botAuthDB = db
	botAuthRedis = rdb
	botAuthLogger = logger
	botTokenSecrets = map[string][]byte{
		"v1": []byte(jwtSecret),
	}
}

// BotAuthMiddleware validates "Bot <token>" or "Bearer <token>" tokens.
// It performs fast SHA-256 validation via Redis and verification of the 3-segment token.
func BotAuthMiddleware(requiredScope string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "missing Authorization header", http.StatusUnauthorized)
			return
		}

		var tokenStr string
		if strings.HasPrefix(authHeader, "Bot ") {
			tokenStr = strings.TrimPrefix(authHeader, "Bot ")
		} else if strings.HasPrefix(authHeader, "Bearer ") {
			tokenStr = strings.TrimPrefix(authHeader, "Bearer ")
		} else {
			http.Error(w, "invalid Authorization header format", http.StatusUnauthorized)
			return
		}

		tokenStr = strings.TrimSpace(tokenStr)
		if tokenStr == "" {
			http.Error(w, "empty token", http.StatusUnauthorized)
			return
		}

		// 1. Verify token structure & signature using fast HMAC comparison
		botUserID, err := auth.VerifyToken(tokenStr, botTokenSecrets)
		if err != nil {
			http.Error(w, "invalid token signature or format", http.StatusUnauthorized)
			return
		}

		// 2. Compute SHA-256 token hash for database/redis lookup
		hashBytes := sha256.Sum256([]byte(tokenStr))
		tokenHash := hex.EncodeToString(hashBytes[:])

		if botAuthDB == nil {
			if botAuthLogger != nil {
				botAuthLogger.Error("bot auth db not configured")
			}
			http.Error(w, "internal service error", http.StatusInternalServerError)
			return
		}

		ctx := r.Context()
		cacheKey := fmt.Sprintf("bot_token_valid:%s", tokenHash)
		var isValid bool

		// Check Redis cache first to bypass DB completely
		if botAuthRedis != nil {
			cachedVal, err := botAuthRedis.Get(ctx, cacheKey).Result()
			if err == nil {
				if cachedVal == "1" {
					isValid = true
				} else {
					http.Error(w, "invalid or suspended token", http.StatusUnauthorized)
					return
				}
			}
		}

		if !isValid {
			// Query DB if not cached
			var (
				appID  string
				status string
			)
			query := `
				SELECT bt.application_id, a.status
				FROM public.bot_tokens bt
				JOIN public.applications a ON a.id = bt.application_id
				WHERE bt.token_hash = $1
				  AND bt.revoked_at IS NULL
				  AND a.is_active = TRUE
			`
			err = botAuthDB.QueryRow(ctx, query, tokenHash).Scan(&appID, &status)
			if err != nil {
				// Cache negative result in Redis for 1 minute to prevent DB hammering
				if botAuthRedis != nil {
					_ = botAuthRedis.Set(ctx, cacheKey, "0", 1*time.Minute).Err()
				}
				http.Error(w, "invalid token", http.StatusUnauthorized)
				return
			}

			if status != "active" {
				if botAuthRedis != nil {
					_ = botAuthRedis.Set(ctx, cacheKey, "0", 1*time.Minute).Err()
				}
				http.Error(w, "bot account is suspended or banned", http.StatusUnauthorized)
				return
			}

			// Validate that decoded user ID matches application ID (they should be 1:1)
			if botUserID != appID {
				http.Error(w, "token subject mismatch", http.StatusUnauthorized)
				return
			}

			// Cache positive result in Redis for 5 minutes
			if botAuthRedis != nil {
				_ = botAuthRedis.Set(ctx, cacheKey, "1", 5*time.Minute).Err()
			}
		}

		// Update last_used_at asynchronously
		go func() {
			_, err := botAuthDB.Exec(context.Background(),
				`UPDATE public.bot_tokens SET last_used_at = now() WHERE token_hash = $1`, tokenHash)
			if err != nil && botAuthLogger != nil {
				botAuthLogger.Error("failed to update bot token last_used_at", zap.Error(err))
			}
		}()

		// Set context values: BotIDContextKey and standard middleware GetUserIDKey()
		newCtx := context.WithValue(r.Context(), BotIDContextKey, botUserID)
		newCtx = context.WithValue(newCtx, middleware.GetUserIDKey(), botUserID)
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
