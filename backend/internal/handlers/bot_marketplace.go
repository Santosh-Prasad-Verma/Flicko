package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type RegisterBotRequest struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	WebhookURL  string   `json:"webhook_url"`
	Permissions int64    `json:"permissions"`
	Categories  []string `json:"categories"`
}

type RegisterBotResponse struct {
	BotID         string `json:"bot_id"`
	WebhookSecret string `json:"webhook_secret"`
	APIKey        string `json:"api_key"`
}

type GenerateBotKeyRequest struct {
	Name   string   `json:"name"`
	Scopes []string `json:"scopes"`
}

var botMarketplaceDB *pgxpool.Pool
var botMarketplaceLogger *zap.Logger

// SetBotMarketplaceDB sets the database pool for bot marketplace handlers.
func SetBotMarketplaceDB(db *pgxpool.Pool, logger *zap.Logger) {
	botMarketplaceDB = db
	botMarketplaceLogger = logger
}

func generateWebhookSecret() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// HandleRegisterBot creates a new external bot in the database and generates API credentials.
func HandleRegisterBot(w http.ResponseWriter, r *http.Request) {
	if botMarketplaceDB == nil {
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	var req RegisterBotRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}

	userID, ok := r.Context().Value(GetUserIDKey()).(string)
	if !ok || userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	ctx := r.Context()

	webhookSecret, err := generateWebhookSecret()
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to generate webhook secret", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	apiKey, keyPrefix, keyHash, err := auth.GenerateAPIKey()
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to generate API key", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	tx, err := botMarketplaceDB.Begin(ctx)
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to begin transaction", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback(ctx)

	var botID string
	err = tx.QueryRow(ctx,
		`INSERT INTO external_bots (developer_id, name, description, webhook_url, webhook_secret, status)
		 VALUES ($1, $2, $3, $4, $5, 'pending')
		 RETURNING id`,
		userID, req.Name, req.Description, req.WebhookURL, webhookSecret,
	).Scan(&botID)
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to insert bot", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO bot_api_keys (bot_id, key_hash, key_prefix, name, scopes)
		 VALUES ($1, $2, $3, $4, $5)`,
		botID, keyHash, keyPrefix, req.Name+" API Key",
		[]string{auth.ScopeMessagesWrite, auth.ScopeMessagesRead},
	)
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to insert bot api key", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(ctx); err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to commit transaction", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(RegisterBotResponse{
		BotID:         botID,
		WebhookSecret: webhookSecret,
		APIKey:        apiKey,
	})
}

// HandleRotateBotSecret generates a new webhook secret for an existing bot.
func HandleRotateBotSecret(w http.ResponseWriter, r *http.Request) {
	if botMarketplaceDB == nil {
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	botID := vars["id"]

	userID, ok := r.Context().Value(GetUserIDKey()).(string)
	if !ok || userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	newSecret, err := generateWebhookSecret()
	if err != nil {
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	result, err := botMarketplaceDB.Exec(r.Context(),
		`UPDATE external_bots SET webhook_secret = $1 WHERE id = $2 AND developer_id = $3`,
		newSecret, botID, userID,
	)
	if err != nil {
		if botMarketplaceLogger != nil {
			botMarketplaceLogger.Error("failed to rotate webhook secret", zap.Error(err))
		}
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}

	if result.RowsAffected() == 0 {
		http.Error(w, "bot not found or not authorized", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":        "Secret rotated successfully",
		"webhook_secret": newSecret,
	})
}

// HandleGenerateAPIKey generates a new API key for the authenticated bot.
func HandleGenerateAPIKey(w http.ResponseWriter, r *http.Request) {
	var req GenerateBotKeyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if !auth.ValidateScopes(req.Scopes) {
		http.Error(w, "invalid scopes requested", http.StatusBadRequest)
		return
	}

	raw, prefix, hash, err := auth.GenerateAPIKey()
	if err != nil {
		http.Error(w, "failed to generate key", http.StatusInternalServerError)
		return
	}

	if botMarketplaceDB != nil {
		vars := mux.Vars(r)
		botID := vars["id"]

		_, err := botMarketplaceDB.Exec(r.Context(),
			`INSERT INTO bot_api_keys (bot_id, key_hash, key_prefix, name, scopes)
			 VALUES ($1, $2, $3, $4, $5)`,
			botID, hash, prefix, req.Name, req.Scopes,
		)
		if err != nil {
			if botMarketplaceLogger != nil {
				botMarketplaceLogger.Error("failed to insert api key", zap.Error(err))
			}
			http.Error(w, "failed to store key", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{
		"api_key": raw,
	})
}

// GetUserIDKey is an internal helper to match the context key pattern used by the middleware package.
func GetUserIDKey() interface{} {
	return contextKey("user_id")
}
