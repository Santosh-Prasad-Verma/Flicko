package handler

import (
	"net/http"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// VoiceHandler handles voice channel token generation.
type VoiceHandler struct {
	svc *service.VoiceService
	log *zap.Logger
}

// NewVoiceHandler creates a VoiceHandler.
func NewVoiceHandler(svc *service.VoiceService, log *zap.Logger) *VoiceHandler {
	return &VoiceHandler{svc: svc, log: log}
}

// tokenRequest is the JSON body for POST /v1/voice/token.
type tokenRequest struct {
	ChannelID string `json:"channel_id"`
	ServerID  string `json:"server_id"`
}

// GenerateToken handles POST /v1/voice/token.
// Generates a LiveKit access token for the requesting user.
func (h *VoiceHandler) GenerateToken(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserIDFromContext(r.Context())

	var body tokenRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	token, err := h.svc.GenerateToken(r.Context(), service.VoiceTokenInput{
		UserID:    userID,
		ChannelID: body.ChannelID,
		ServerID:  body.ServerID,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusOK, map[string]string{"token": token})
}
