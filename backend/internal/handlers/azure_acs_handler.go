package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"go.uber.org/zap"
)

type AzureACSHandler struct {
	acsService services.AzureACSService
	logger     *zap.Logger
}

func NewAzureACSHandler(acsService services.AzureACSService, logger *zap.Logger) *AzureACSHandler {
	return &AzureACSHandler{
		acsService: acsService,
		logger:     logger,
	}
}

type acsTokenReq struct {
	Scopes []string `json:"scopes"`
}

func (h *AzureACSHandler) IssueToken(w http.ResponseWriter, r *http.Request) {
	var req acsTokenReq
	_ = json.NewDecoder(r.Body).Decode(&req)

	scopes := req.Scopes
	if len(scopes) == 0 {
		scopes = []string{"voip", "chat"}
	}

	tokenResp, err := h.acsService.IssueToken(r.Context(), scopes)
	if err != nil {
		h.logger.Error("failed to issue acs token", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to issue voice communication token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":    tokenResp.User.ID,
		"token":      tokenResp.Token,
		"expires_on": tokenResp.ExpiresOn,
	})
}

type pushNotificationReq struct {
	DeviceToken string                 `json:"device_token"`
	Platform    string                 `json:"platform"`
	Payload     map[string]interface{} `json:"payload"`
}

func (h *AzureACSHandler) SendPushNotification(w http.ResponseWriter, r *http.Request) {
	var req pushNotificationReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.DeviceToken == "" {
		writeError(w, http.StatusBadRequest, "device_token and platform are required")
		return
	}

	if req.Platform == "" {
		req.Platform = "fcm"
	}

	err := h.acsService.SendPushNotification(r.Context(), req.DeviceToken, req.Platform, req.Payload)
	if err != nil {
		h.logger.Error("failed to send push notification", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to dispatch push notification")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "success",
	})
}
