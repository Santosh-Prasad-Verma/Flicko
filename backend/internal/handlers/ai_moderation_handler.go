package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gorilla/mux"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/ai/moderation"
)

// AIModerationHandler exposes the AI moderation REST surface used by the
// moderator UI and the user-facing appeal flow.
//
//	POST   /api/v1/ai/moderation/check                  (server-only; called by send pipeline)
//	GET    /api/v1/servers/{serverId}/mod-queue
//	POST   /api/v1/mod-queue/{queueId}/decision         { action: approved|denied }
//	GET    /api/v1/servers/{serverId}/automod/ai-thresholds
//	PATCH  /api/v1/servers/{serverId}/automod/ai-thresholds
//	POST   /api/v1/messages/{messageId}/appeal          { signal_id, reason? }
type AIModerationHandler struct {
	svc    moderation.Service
	logger *zap.Logger
}

func NewAIModerationHandler(svc moderation.Service, logger *zap.Logger) *AIModerationHandler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &AIModerationHandler{svc: svc, logger: logger.Named("handler.ai_moderation")}
}

func (h *AIModerationHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/ai/moderation/check", h.Check).Methods(http.MethodPost)
	r.HandleFunc("/servers/{serverId}/mod-queue", h.ListQueue).Methods(http.MethodGet)
	r.HandleFunc("/mod-queue/{queueId}/decision", h.Decide).Methods(http.MethodPost)
	r.HandleFunc("/servers/{serverId}/automod/ai-thresholds", h.GetThresholds).Methods(http.MethodGet)
	r.HandleFunc("/servers/{serverId}/automod/ai-thresholds", h.SetThresholds).Methods(http.MethodPatch)
	r.HandleFunc("/mod-signals/{signalId}/appeal", h.Appeal).Methods(http.MethodPost)
}

type checkBody struct {
	Text      string `json:"text"`
	ServerID  string `json:"server_id"`
	ChannelID string `json:"channel_id"`
	MessageID string `json:"message_id,omitempty"`
}

// Check classifies a message. Used by the send pipeline before publish; we
// also expose it as a REST endpoint so internal tooling can dry-run a string.
func (h *AIModerationHandler) Check(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var b checkBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if b.Text == "" {
		writeError(w, http.StatusBadRequest, "text required")
		return
	}
	if len(b.Text) > 8000 {
		writeError(w, http.StatusBadRequest, "text too long (max 8000 chars)")
		return
	}
	res, err := h.svc.Check(r.Context(), moderation.CheckInput{
		UserID:    userID,
		ServerID:  b.ServerID,
		ChannelID: b.ChannelID,
		MessageID: b.MessageID,
		Text:      b.Text,
	})
	if err != nil {
		if errors.Is(err, moderation.ErrTextEmpty) {
			writeError(w, http.StatusBadRequest, "text empty")
			return
		}
		h.logger.Error("ai mod check", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// ListQueue returns the open mod queue for a server. Mod permission required.
func (h *AIModerationHandler) ListQueue(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	// Server membership is enforced by RLS on read; permission tightening
	// (MANAGE_MESSAGES) is handled by the existing perm middleware on this
	// route. We deliberately keep the handler thin.
	_ = mux.Vars(r)["serverId"]
	writeJSON(w, http.StatusOK, map[string]any{
		"items": []any{},
		"note":  "stub: list query lives in repo layer; wired to existing report_service in next iteration",
	})
}

type decideBody struct {
	Action string `json:"action"`
}

// Decide approves or denies a queue item. Plaintext on the row is purged
// regardless.
func (h *AIModerationHandler) Decide(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	queueID := mux.Vars(r)["queueId"]
	var b decideBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if err := h.svc.Decide(r.Context(), queueID, userID, b.Action); err != nil {
		if errors.Is(err, moderation.ErrUnknownQueueItem) {
			writeError(w, http.StatusNotFound, "unknown_queue_item")
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetThresholds returns the per-server thresholds (defaults if unset).
func (h *AIModerationHandler) GetThresholds(w http.ResponseWriter, r *http.Request) {
	if userID := getUserID(r); userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	serverID := mux.Vars(r)["serverId"]
	t, err := h.svc.GetThresholds(r.Context(), serverID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	writeJSON(w, http.StatusOK, t)
}

// SetThresholds upserts the per-server thresholds. Caller permission
// (MANAGE_SERVER) must be enforced upstream.
func (h *AIModerationHandler) SetThresholds(w http.ResponseWriter, r *http.Request) {
	if userID := getUserID(r); userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	serverID := mux.Vars(r)["serverId"]
	var t moderation.Thresholds
	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if err := h.svc.SetThresholds(r.Context(), serverID, t); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type appealBody struct {
	Reason string `json:"reason,omitempty"`
}

// Appeal opens an appeal against a `blocked` mod_signals row.
func (h *AIModerationHandler) Appeal(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	signalID := mux.Vars(r)["signalId"]
	var b appealBody
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		// Empty body is fine; the reason is optional.
		b = appealBody{}
	}
	if err := h.svc.Appeal(r.Context(), signalID, userID, b.Reason); err != nil {
		if errors.Is(err, moderation.ErrAppealCapped) {
			writeError(w, http.StatusTooManyRequests, "appeal_capped")
			return
		}
		h.logger.Error("appeal", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
