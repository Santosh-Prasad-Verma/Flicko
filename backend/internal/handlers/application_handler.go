package handlers

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ApplicationHandler struct {
	db              *pgxpool.Pool
	logger          *zap.Logger
	botTokenSecrets map[string][]byte
}

type CreateAppRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	IconURL     string `json:"icon_url"`
}

type UpdateAppRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	IconURL     *string `json:"icon_url"`
	IsPublic    *bool   `json:"is_public"`
}

type AppResponse struct {
	ID          string                 `json:"id"`
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	IconURL     string                 `json:"icon_url"`
	IsPublic    bool                   `json:"is_public"`
	IsActive    bool                   `json:"is_active"`
	Status      string                 `json:"status"`
	PublicKey   string                 `json:"public_key"`
	Metadata    map[string]interface{} `json:"metadata"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

type CreateAppResponse struct {
	App          AppResponse `json:"application"`
	ClientSecret string      `json:"client_secret"`
}

type ResetTokenResponse struct {
	Token string `json:"token"`
}

func NewApplicationHandler(db *pgxpool.Pool, jwtSecret string, logger *zap.Logger) *ApplicationHandler {
	return &ApplicationHandler{
		db:     db,
		logger: logger.Named("handler.application"),
		botTokenSecrets: map[string][]byte{
			"v1": []byte(jwtSecret),
		},
	}
}

func (h *ApplicationHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var req CreateAppRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if len(req.Name) < 2 {
		writeError(w, http.StatusBadRequest, "name must be at least 2 characters")
		return
	}

	// 1. Generate Client Secret & Client Secret Hash
	secretBytes := make([]byte, 32)
	if _, err := rand.Read(secretBytes); err != nil {
		h.logger.Error("failed to generate client secret", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create application")
		return
	}
	clientSecret := hex.EncodeToString(secretBytes)
	clientSecretHashBytes := sha256.Sum256([]byte(clientSecret))
	clientSecretHash := hex.EncodeToString(clientSecretHashBytes[:])

	// 2. Generate Ed25519 Keypair for Webhook Signature verification
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		h.logger.Error("failed to generate Ed25519 keypair", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create application")
		return
	}
	publicKeyHex := hex.EncodeToString(pub)
	privateKeyHex := hex.EncodeToString(priv)

	metadata := map[string]interface{}{
		"private_key": privateKeyHex,
	}
	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		h.logger.Error("failed to serialize metadata", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create application")
		return
	}

	var app AppResponse
	err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.applications (owner_id, name, description, icon_url, client_secret_hash, public_key, metadata, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
		RETURNING id, name, COALESCE(description, ''), COALESCE(icon_url, ''), is_public, is_active, status, COALESCE(public_key, ''), created_at, updated_at
	`, userUUID, req.Name, req.Description, req.IconURL, clientSecretHash, publicKeyHex, metadataJSON).Scan(
		&app.ID, &app.Name, &app.Description, &app.IconURL, &app.IsPublic, &app.IsActive, &app.Status, &app.PublicKey, &app.CreatedAt, &app.UpdatedAt,
	)
	if err != nil {
		h.logger.Error("failed to insert application", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create application")
		return
	}

	writeJSON(w, http.StatusCreated, CreateAppResponse{
		App:          app,
		ClientSecret: clientSecret,
	})
}

func (h *ApplicationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, name, COALESCE(description, ''), COALESCE(icon_url, ''), is_public, is_active, status, COALESCE(public_key, ''), created_at, updated_at
		FROM public.applications
		WHERE owner_id = $1
		ORDER BY created_at DESC
	`, userUUID)
	if err != nil {
		h.logger.Error("failed to list applications", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list applications")
		return
	}
	defer rows.Close()

	apps := make([]AppResponse, 0)
	for rows.Next() {
		var app AppResponse
		err := rows.Scan(
			&app.ID, &app.Name, &app.Description, &app.IconURL, &app.IsPublic, &app.IsActive, &app.Status, &app.PublicKey, &app.CreatedAt, &app.UpdatedAt,
		)
		if err != nil {
			h.logger.Error("failed to scan application row", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to list applications")
			return
		}
		apps = append(apps, app)
	}

	writeJSON(w, http.StatusOK, apps)
}

func (h *ApplicationHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid application id")
		return
	}

	var app AppResponse
	err = h.db.QueryRow(r.Context(), `
		SELECT id, name, COALESCE(description, ''), COALESCE(icon_url, ''), is_public, is_active, status, COALESCE(public_key, ''), created_at, updated_at
		FROM public.applications
		WHERE id = $1 AND owner_id = $2
	`, appUUID, userUUID).Scan(
		&app.ID, &app.Name, &app.Description, &app.IconURL, &app.IsPublic, &app.IsActive, &app.Status, &app.PublicKey, &app.CreatedAt, &app.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to fetch application", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to get application")
		return
	}

	writeJSON(w, http.StatusOK, app)
}

func (h *ApplicationHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid application id")
		return
	}

	var req UpdateAppRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// Build dynamic update query
	setClauses := make([]string, 0)
	args := []interface{}{appUUID, userUUID}
	argIdx := 3

	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if len(name) < 2 {
			writeError(w, http.StatusBadRequest, "name must be at least 2 characters")
			return
		}
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		args = append(args, name)
		argIdx++
	}
	if req.Description != nil {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		args = append(args, *req.Description)
		argIdx++
	}
	if req.IconURL != nil {
		setClauses = append(setClauses, fmt.Sprintf("icon_url = $%d", argIdx))
		args = append(args, *req.IconURL)
		argIdx++
	}
	if req.IsPublic != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_public = $%d", argIdx))
		args = append(args, *req.IsPublic)
		argIdx++
	}

	if len(setClauses) == 0 {
		h.Get(w, r)
		return
	}

	query := fmt.Sprintf(`
		UPDATE public.applications
		SET %s, updated_at = NOW()
		WHERE id = $1 AND owner_id = $2
		RETURNING id, name, COALESCE(description, ''), COALESCE(icon_url, ''), is_public, is_active, status, COALESCE(public_key, ''), created_at, updated_at
	`, strings.Join(setClauses, ", "))

	var app AppResponse
	err = h.db.QueryRow(r.Context(), query, args...).Scan(
		&app.ID, &app.Name, &app.Description, &app.IconURL, &app.IsPublic, &app.IsActive, &app.Status, &app.PublicKey, &app.CreatedAt, &app.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to update application", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update application")
		return
	}

	writeJSON(w, http.StatusOK, app)
}

func (h *ApplicationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid application id")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin delete transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to delete application")
		return
	}
	defer tx.Rollback(r.Context())

	// Delete from applications
	res, err := tx.Exec(r.Context(), `
		DELETE FROM public.applications
		WHERE id = $1 AND owner_id = $2
	`, appUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to delete application", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to delete application")
		return
	}

	if res.RowsAffected() == 0 {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}

	// Delete matching bot users from profiles/users
	_, _ = tx.Exec(r.Context(), `DELETE FROM public.profiles WHERE id = $1 AND is_bot = TRUE`, appUUID)
	_, _ = tx.Exec(r.Context(), `DELETE FROM public.users WHERE id = $1 AND is_bot = TRUE`, appUUID)

	if err := tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit delete transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to delete application")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *ApplicationHandler) ResetToken(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	appUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid application id")
		return
	}

	// 1. Verify ownership and get app name
	var appName string
	err = h.db.QueryRow(r.Context(), `
		SELECT name FROM public.applications WHERE id = $1 AND owner_id = $2 AND is_active = TRUE
	`, appUUID, userUUID).Scan(&appName)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "application not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to verify app ownership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	// 2. Generate new token
	secret, ok := h.botTokenSecrets["v1"]
	if !ok {
		writeError(w, http.StatusInternalServerError, "signing key v1 not configured")
		return
	}

	token, err := auth.GenerateToken(appUUID.String(), "v1", secret)
	if err != nil {
		h.logger.Error("failed to generate bot token", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	tokenHashBytes := sha256.Sum256([]byte(token))
	tokenHash := hex.EncodeToString(tokenHashBytes[:])
	tokenPrefix := base64RawURLEncode(appUUID.String())

	// 3. Update DB in transaction
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin token reset transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}
	defer tx.Rollback(r.Context())

	// Revoke old tokens
	_, err = tx.Exec(r.Context(), `
		UPDATE public.bot_tokens
		SET revoked_at = NOW()
		WHERE application_id = $1 AND revoked_at IS NULL
	`, appUUID)
	if err != nil {
		h.logger.Error("failed to revoke old tokens", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	// Insert new token
	_, err = tx.Exec(r.Context(), `
		INSERT INTO public.bot_tokens (application_id, token_hash, token_prefix, key_version)
		VALUES ($1, $2, $3, 'v1')
	`, appUUID, tokenHash, tokenPrefix)
	if err != nil {
		h.logger.Error("failed to insert new token", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	// Ensure the bot user exists in public.users
	botEmail := fmt.Sprintf("bot-%s@flicko.local", appUUID.String())
	_, err = tx.Exec(r.Context(), `
		INSERT INTO public.users (id, username, email, password_hash, is_bot)
		VALUES ($1, $2, $3, '', TRUE)
		ON CONFLICT (id) DO UPDATE SET username = EXCLUDED.username
	`, appUUID, appName, botEmail)
	if err != nil {
		h.logger.Error("failed to ensure bot user in public.users", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	// Ensure the bot profile exists in public.profiles
	_, err = tx.Exec(r.Context(), `
		INSERT INTO public.profiles (id, username, display_name, email, is_bot)
		VALUES ($1, $2, $2, $3, TRUE)
		ON CONFLICT (id) DO UPDATE SET username = EXCLUDED.username, display_name = EXCLUDED.display_name
	`, appUUID, appName, botEmail)
	if err != nil {
		h.logger.Error("failed to ensure bot user in public.profiles", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit token reset transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to reset bot token")
		return
	}

	writeJSON(w, http.StatusOK, ResetTokenResponse{
		Token: token,
	})
}

// Helpers

func base64RawURLEncode(s string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(s))
}
