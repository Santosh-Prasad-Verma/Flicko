package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/ai/message_summary"
)

// AISummaryHandler exposes the Catch-Me-Up endpoints.
//
// Routes (registered via RegisterRoutes on a /api/v1 subrouter):
//
//	POST /api/v1/ai/summary/request
//	GET  /api/v1/ai/summary/stream/{request_id}    (SSE)
//	GET  /api/v1/ai/summary/{id}
//	POST /api/v1/ai/summary/{id}/feedback
type AISummaryHandler struct {
	svc    message_summary.Service
	logger *zap.Logger
}

// NewAISummaryHandler wires the handler.
func NewAISummaryHandler(svc message_summary.Service, logger *zap.Logger) *AISummaryHandler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &AISummaryHandler{svc: svc, logger: logger.Named("handler.ai_summary")}
}

// RegisterRoutes hooks the handler into a (presumably authenticated) router.
func (h *AISummaryHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/ai/summary/request", h.Request).Methods(http.MethodPost)
	r.HandleFunc("/ai/summary/stream/{request_id}", h.Stream).Methods(http.MethodGet)
	r.HandleFunc("/ai/summary/{id}", h.Get).Methods(http.MethodGet)
	r.HandleFunc("/ai/summary/{id}/feedback", h.Feedback).Methods(http.MethodPost)
}

type requestBody struct {
	ChannelID   string  `json:"channel_id"`
	ServerID    string  `json:"server_id"`
	SinceTS     string  `json:"since_ts"`
	AnchorMsgID *string `json:"anchor_msg_id,omitempty"`
}

// Request validates input and kicks off generation.
func (h *AISummaryHandler) Request(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body requestBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if body.ChannelID == "" || body.ServerID == "" {
		writeError(w, http.StatusBadRequest, "channel_id and server_id are required")
		return
	}
	since := time.Now().Add(-24 * time.Hour)
	if body.SinceTS != "" {
		t, err := time.Parse(time.RFC3339, body.SinceTS)
		if err != nil {
			writeError(w, http.StatusBadRequest, "since_ts must be RFC3339")
			return
		}
		since = t
	}

	resp, err := h.svc.Request(r.Context(), message_summary.RequestInput{
		UserID:      userID,
		ChannelID:   body.ChannelID,
		ServerID:    body.ServerID,
		SinceTS:     since,
		AnchorMsgID: body.AnchorMsgID,
	})
	switch {
	case errors.Is(err, message_summary.ErrACLDenied):
		writeError(w, http.StatusForbidden, "no_channel_access")
		return
	case errors.Is(err, message_summary.ErrTooFewMessages):
		writeJSON(w, http.StatusUnprocessableEntity, map[string]any{
			"code":    "too_few_messages",
			"minimum": 5,
		})
		return
	case errors.Is(err, message_summary.ErrRateLimited):
		writeError(w, http.StatusTooManyRequests, "rate_limited")
		return
	case err != nil:
		h.logger.Error("summary request", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// Stream pipes generation events as SSE.
func (h *AISummaryHandler) Stream(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requestID := mux.Vars(r)["request_id"]
	if requestID == "" {
		writeError(w, http.StatusBadRequest, "missing request_id")
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "streaming_unsupported")
		return
	}

	ch, err := h.svc.Stream(r.Context(), requestID, userID)
	if err != nil {
		writeError(w, http.StatusNotFound, "unknown_request")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	// Heartbeat keeps proxies from timing out idle SSE connections.
	hb := time.NewTicker(15 * time.Second)
	defer hb.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-hb.C:
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case ev, ok := <-ch:
			if !ok {
				return
			}
			payload, err := json.Marshal(ev.Data)
			if err != nil {
				continue
			}
			fmt.Fprintf(w, "event: %s\ndata: %s\n\n", ev.Type, payload)
			flusher.Flush()
			if ev.Type == "done" || ev.Type == "error" {
				return
			}
		}
	}
}

// Get returns the persisted summary by id.
func (h *AISummaryHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	id := mux.Vars(r)["id"]
	s, err := h.svc.Get(r.Context(), id, userID)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found")
		return
	}
	writeJSON(w, http.StatusOK, s)
}

type feedbackBody struct {
	Rating int16   `json:"rating"`
	Reason *string `json:"reason,omitempty"`
}

// Feedback records a thumb up/down with optional reason.
func (h *AISummaryHandler) Feedback(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	id := mux.Vars(r)["id"]
	var body feedbackBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if body.Rating != 1 && body.Rating != -1 {
		writeError(w, http.StatusBadRequest, "rating must be 1 or -1")
		return
	}
	if err := h.svc.Feedback(r.Context(), id, userID, body.Rating, body.Reason); err != nil {
		h.logger.Error("feedback", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal_error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
