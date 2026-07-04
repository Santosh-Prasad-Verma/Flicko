package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type OAuth2Handler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewOAuth2Handler(db *pgxpool.Pool, logger *zap.Logger) *OAuth2Handler {
	return &OAuth2Handler{
		db:     db,
		logger: logger.Named("handler.oauth2"),
	}
}

type AuthorizeRequest struct {
	ClientID    string `json:"client_id"`
	GuildID     string `json:"guild_id"`
	Permissions string `json:"permissions"` // Bitset string or number
	State       string `json:"state"`
}

type ApplicationAuthorizeInfo struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Icon        *string  `json:"icon"`
	BotUserID   string   `json:"bot_user_id"`
	Scopes      []string `json:"scopes"`
}

func (h *OAuth2Handler) GetAuthorizeInfo(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	clientID := r.URL.Query().Get("client_id")
	scope := r.URL.Query().Get("scope")

	if clientID == "" {
		http.Error(w, "missing client_id parameter", http.StatusBadRequest)
		return
	}

	appUUID, err := uuid.Parse(clientID)
	if err != nil {
		http.Error(w, "invalid client_id", http.StatusBadRequest)
		return
	}

	var app ApplicationAuthorizeInfo
	var isActive bool
	var status string

	err = h.db.QueryRow(ctx, `
		SELECT id, name, description, icon, is_active, status
		FROM public.applications
		WHERE id = $1
	`, appUUID).Scan(&app.ID, &app.Name, &app.Description, &app.Icon, &isActive, &status)

	if err != nil || !isActive || status != "active" {
		http.Error(w, "application not found or suspended", http.StatusNotFound)
		return
	}

	app.BotUserID = app.ID
	app.Scopes = strings.Split(scope, " ")

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(app)
}

func (h *OAuth2Handler) AuthorizeBot(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID, ok := ctx.Value(middleware.GetUserIDKey()).(string)
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req AuthorizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.ClientID == "" || req.GuildID == "" {
		http.Error(w, "client_id and guild_id are required", http.StatusBadRequest)
		return
	}

	appUUID, err1 := uuid.Parse(req.ClientID)
	guildUUID, err2 := uuid.Parse(req.GuildID)
	userUUID, err3 := uuid.Parse(userID)

	if err1 != nil || err2 != nil || err3 != nil {
		http.Error(w, "invalid UUID format", http.StatusBadRequest)
		return
	}

	// 1. Verify User has permission to add bots to the server (MANAGE_GUILD = 32 or Owner)
	var canManage bool
	err := h.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM servers s
			LEFT JOIN member_roles mr ON s.id = mr.server_id AND mr.user_id = $2
			LEFT JOIN roles r ON mr.role_id = r.id AND mr.server_id = r.server_id
			WHERE s.id = $1 AND (
				s.owner_id = $2 
				OR (COALESCE(r.permissions, 0) & 32) > 0
				OR (COALESCE(r.permissions, 0) & 4611686018427387904) > 0
			)
		)
	`, guildUUID, userUUID).Scan(&canManage)

	if err != nil || !canManage {
		http.Error(w, "you do not have permission to manage bots in this server", http.StatusForbidden)
		return
	}

	permBitset, _ := strconv.ParseInt(req.Permissions, 10, 64)

	// 2. Insert or Update oauth2_grants (idempotent ON CONFLICT)
	_, err = h.db.Exec(ctx, `
		INSERT INTO public.oauth2_grants (application_id, user_id, guild_id, scopes, granted_permissions)
		VALUES ($1, $2, $3, ARRAY['bot', 'applications.commands'], $4)
		ON CONFLICT (application_id, user_id, guild_id) 
		DO UPDATE SET granted_permissions = EXCLUDED.granted_permissions, updated_at = NOW()
	`, appUUID, userUUID, guildUUID, permBitset)

	if err != nil {
		h.logger.Error("failed to record oauth2_grant", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	// 3. Add bot user to server_members if not already a member
	_, err = h.db.Exec(ctx, `
		INSERT INTO public.server_members (server_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT (server_id, user_id) DO NOTHING
	`, guildUUID, appUUID)

	if err != nil {
		h.logger.Error("failed to add bot to server members", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"authorized": true,
		"guild_id":   req.GuildID,
		"bot_id":     req.ClientID,
	})
}
