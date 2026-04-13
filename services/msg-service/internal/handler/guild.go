package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// GuildHandler handles guild CRUD and membership routes.
type GuildHandler struct {
	svc *service.GuildService
	log *zap.Logger
}

// NewGuildHandler creates a GuildHandler.
func NewGuildHandler(svc *service.GuildService, log *zap.Logger) *GuildHandler {
	return &GuildHandler{svc: svc, log: log}
}

// createGuildRequest is the JSON body for POST /v1/guilds.
type createGuildRequest struct {
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
	Region      string `json:"region,omitempty"`
}

// CreateGuild handles POST /v1/guilds.
func (h *GuildHandler) CreateGuild(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())

	var body createGuildRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	g, err := h.svc.CreateGuild(r.Context(), service.CreateGuildRequest{
		UserID:      userID,
		Name:        body.Name,
		Description: body.Description,
		Region:      body.Region,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusCreated, g)
}

// GetGuild handles GET /v1/guilds/{guildID}.
func (h *GuildHandler) GetGuild(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")

	g, err := h.svc.GetGuild(r.Context(), guildID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusOK, g)
}

// GetMyGuilds handles GET /v1/users/@me/guilds.
func (h *GuildHandler) GetMyGuilds(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())

	guilds, err := h.svc.GetMyGuilds(r.Context(), userID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSONList(w, guilds, "")
}

// joinGuildRequest is the JSON body for POST /v1/guilds/{guildID}/members.
type joinGuildRequest struct {
	UserID string `json:"user_id,omitempty"` // defaults to caller
}

// JoinGuild handles POST /v1/guilds/{guildID}/members.
func (h *GuildHandler) JoinGuild(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")
	callerID := auth.UserIDFromContext(r.Context())

	// Allow body to specify user_id (for invites), default to self.
	var body joinGuildRequest
	_ = DecodeJSON(r, &body) // optional body
	targetUserID := callerID
	if body.UserID != "" {
		targetUserID = body.UserID
	}

	if err := h.svc.JoinGuild(r.Context(), guildID, callerID, targetUserID); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// LeaveGuild handles DELETE /v1/guilds/{guildID}/members/{userID}.
func (h *GuildHandler) LeaveGuild(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")
	callerID := auth.UserIDFromContext(r.Context())
	targetUserID := chi.URLParam(r, "userID")

	if err := h.svc.LeaveGuild(r.Context(), guildID, callerID, targetUserID); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ListMembers handles GET /v1/guilds/{guildID}/members.
// Query: ?limit=100&offset=0
func (h *GuildHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")
	limit := QueryInt(r, "limit", 100, 1000)
	offset := QueryInt(r, "offset", 0, 100000)

	members, err := h.svc.ListMembers(r.Context(), guildID, limit, offset)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSONList(w, members, "")
}
