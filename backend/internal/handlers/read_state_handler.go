package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type ReadStateHandler struct {
	service services.ReadStateService
	logger  *zap.Logger
}

func NewReadStateHandler(service services.ReadStateService, logger *zap.Logger) *ReadStateHandler {
	return &ReadStateHandler{
		service: service,
		logger:  logger,
	}
}

// MarkAsRead handles POST /api/v1/channels/{channelId}/messages/{messageId}/read
func (h *ReadStateHandler) MarkAsRead(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	channelIDStr := vars["channelId"]
	messageIDStr := vars["messageId"]

	// Get UserID from JWT Auth context
	userIDStr, ok := r.Context().Value(middleware.GetUserIDKey()).(string)
	if !ok || userIDStr == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Parse UUIDs
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.logger.Warn("invalid user UUID", zap.Error(err), zap.String("userID", userIDStr))
		http.Error(w, "Invalid User ID format", http.StatusBadRequest)
		return
	}

	channelID, err := uuid.Parse(channelIDStr)
	if err != nil {
		http.Error(w, "Invalid Channel ID format", http.StatusBadRequest)
		return
	}

	messageID, err := uuid.Parse(messageIDStr)
	if err != nil {
		http.Error(w, "Invalid Message ID format", http.StatusBadRequest)
		return
	}

	// Persist
	rs, err := h.service.MarkAsRead(r.Context(), channelID, userID, messageID)
	if err != nil {
		h.logger.Error("failed to mark message as read",
			zap.Error(err),
			zap.String("channel_id", channelID.String()),
			zap.String("user_id", userID.String()),
		)
		http.Error(w, "Failed to mark message as read", http.StatusInternalServerError)
		return
	}

	// Usually we'd emit an event so the user's other sessions sync up
	// e.g. h.eventBus.Publish(ReadEvent{...})

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(rs); err != nil {
		h.logger.Error("failed to encode response", zap.Error(err))
	}
}

// GetUserReadStates handles GET /api/v1/users/@me/read_states
func (h *ReadStateHandler) GetUserReadStates(w http.ResponseWriter, r *http.Request) {
	// Get UserID from JWT
	userIDStr, ok := r.Context().Value(middleware.GetUserIDKey()).(string)
	if !ok || userIDStr == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		http.Error(w, "Invalid User ID format", http.StatusBadRequest)
		return
	}

	states, err := h.service.GetReadStatesForUser(r.Context(), userID)
	if err != nil {
		h.logger.Error("failed to fetch read states", zap.Error(err))
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"read_states": states,
	}); err != nil {
		h.logger.Error("failed to encode read states", zap.Error(err))
	}
}
