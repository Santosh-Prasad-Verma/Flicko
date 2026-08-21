package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"go.uber.org/zap"
)

type VoiceSFUHandler struct {
	acsSvc services.AzureACSService
	logger *zap.Logger
}

func NewVoiceSFUHandler(acsSvc services.AzureACSService, logger *zap.Logger) *VoiceSFUHandler {
	return &VoiceSFUHandler{
		acsSvc: acsSvc,
		logger: logger,
	}
}

type tokenRequest struct {
	RoomName            string   `json:"room_name"`
	ParticipantName     string   `json:"participant_name"`
	ParticipantIdentity string   `json:"participant_identity"`
	CanPublish          bool     `json:"can_publish"`
	CanPublishData      bool     `json:"can_publish_data"`
	Scopes              []string `json:"scopes"`
}

func (h *VoiceSFUHandler) GenerateToken(w http.ResponseWriter, r *http.Request) {
	var req tokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	scopes := req.Scopes
	if len(scopes) == 0 {
		scopes = []string{"voip", "chat"}
	}

	tokenResp, err := h.acsSvc.IssueToken(r.Context(), scopes)
	if err != nil {
		h.logger.Error("failed to generate azure acs token", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to generate voice communication token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"token":      tokenResp.Token,
		"user_id":    tokenResp.User.ID,
		"expires_on": tokenResp.ExpiresOn,
		"room":       req.RoomName,
	})
}
