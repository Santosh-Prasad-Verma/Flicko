package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// ChannelHandler handles channel CRUD routes.
type ChannelHandler struct {
	svc *service.ChannelService
	log *zap.Logger
}

// NewChannelHandler creates a ChannelHandler.
func NewChannelHandler(svc *service.ChannelService, log *zap.Logger) *ChannelHandler {
	return &ChannelHandler{svc: svc, log: log}
}

// createChannelRequest is the JSON body for POST /v1/guilds/{guildID}/channels.
type createChannelRequest struct {
	Name     string `json:"name"`
	Type     string `json:"type,omitempty"`
	ParentID string `json:"parent_id,omitempty"`
	Topic    string `json:"topic,omitempty"`
}

// CreateChannel handles POST /v1/guilds/{guildID}/channels.
func (h *ChannelHandler) CreateChannel(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")
	userID := auth.UserIDFromContext(r.Context())

	var body createChannelRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	ch, err := h.svc.CreateChannel(r.Context(), service.CreateChannelRequest{
		GuildID:  guildID,
		UserID:   userID,
		Name:     body.Name,
		Type:     body.Type,
		ParentID: body.ParentID,
		Topic:    body.Topic,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusCreated, ch)
}

// ListChannels handles GET /v1/guilds/{guildID}/channels.
func (h *ChannelHandler) ListChannels(w http.ResponseWriter, r *http.Request) {
	guildID := chi.URLParam(r, "guildID")
	userID := auth.UserIDFromContext(r.Context())

	chs, err := h.svc.ListChannels(r.Context(), guildID, userID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSONList(w, chs, "")
}

// UpdateChannel handles PATCH /v1/channels/{channelID}.
func (h *ChannelHandler) UpdateChannel(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())

	var body repository.ChannelUpdate
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	if err := h.svc.UpdateChannel(r.Context(), channelID, userID, body); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// DeleteChannel handles DELETE /v1/channels/{channelID}.
func (h *ChannelHandler) DeleteChannel(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())

	if err := h.svc.DeleteChannel(r.Context(), channelID, userID); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
