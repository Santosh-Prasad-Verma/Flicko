package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services"
)

// AuraLogHandler handles HTTP requests for AI Aura conversation log endpoints.
type AuraLogHandler struct {
	svc    services.AuraLogService
	logger *zap.Logger
}

// NewAuraLogHandler creates a new AuraLogHandler.
func NewAuraLogHandler(svc services.AuraLogService, logger *zap.Logger) *AuraLogHandler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &AuraLogHandler{
		svc:    svc,
		logger: logger.Named("handler.aura_log"),
	}
}

// RegisterRoutes registers Aura log endpoints on the given router.
func (h *AuraLogHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/aura/conversations", h.SaveConversation).Methods(http.MethodPost)
	r.HandleFunc("/aura/conversations", h.GetHistory).Methods(http.MethodGet)
	r.HandleFunc("/aura/search", h.Search).Methods(http.MethodPost)
}

type saveConversationRequest struct {
	Turns []services.AuraLogTurn `json:"turns"`
}

// SaveConversation persists a batch of Aura conversation turns.
func (h *AuraLogHandler) SaveConversation(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body saveConversationRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}

	err := h.svc.SaveConversation(r.Context(), userID, body.Turns)
	switch {
	case errors.Is(err, services.ErrAuraInvalidInput):
		writeError(w, http.StatusBadRequest, err.Error())
		return
	case errors.Is(err, services.ErrAuraBatchTooLarge):
		writeError(w, http.StatusBadRequest, err.Error())
		return
	case err != nil:
		h.logger.Error("save conversation", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"status": "ok",
		"count":  len(body.Turns),
	})
}

// GetHistory returns the user's Aura conversation history.
func (h *AuraLogHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	limit := 50
	if q := r.URL.Query().Get("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil && n > 0 {
			limit = n
		}
	}

	logs, err := h.svc.GetHistory(r.Context(), userID, limit)
	if err != nil {
		h.logger.Error("get history", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"conversations": logs,
	})
}

type searchRequest struct {
	Query string `json:"query"`
	Limit int    `json:"limit"`
}

// Search performs a semantic search across past Aura conversations.
func (h *AuraLogHandler) Search(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body searchRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}

	results, err := h.svc.Search(r.Context(), userID, body.Query, body.Limit)
	if err != nil {
		h.logger.Error("search", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"results": results,
	})
}
