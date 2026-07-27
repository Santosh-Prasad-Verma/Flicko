package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"go.uber.org/zap"
)

type VoiceSFUHandler struct {
	livekitSvc services.LiveKitService
	logger     *zap.Logger
}

func NewVoiceSFUHandler(livekitSvc services.LiveKitService, logger *zap.Logger) *VoiceSFUHandler {
	return &VoiceSFUHandler{
		livekitSvc: livekitSvc,
		logger:     logger,
	}
}

type tokenRequest struct {
	RoomName            string `json:"room_name"`
	ParticipantName     string `json:"participant_name"`
	ParticipantIdentity string `json:"participant_identity"`
	CanPublish          bool   `json:"can_publish"`
	CanPublishData      bool   `json:"can_publish_data"`
}

func (h *VoiceSFUHandler) GenerateToken(w http.ResponseWriter, r *http.Request) {
	var req tokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.RoomName == "" || req.ParticipantIdentity == "" {
		writeError(w, http.StatusBadRequest, "room_name and participant_identity are required")
		return
	}

	token, err := h.livekitSvc.GenerateToken(
		req.RoomName,
		req.ParticipantName,
		req.ParticipantIdentity,
		req.CanPublish,
		req.CanPublishData,
	)
	if err != nil {
		h.logger.Error("failed to generate livekit token", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to generate voice token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"token": token,
	})
}
