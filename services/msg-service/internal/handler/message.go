package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// MessageHandler handles message CRUD routes.
type MessageHandler struct {
	svc *service.MessageService
	log *zap.Logger
}

// NewMessageHandler creates a MessageHandler.
func NewMessageHandler(svc *service.MessageService, log *zap.Logger) *MessageHandler {
	return &MessageHandler{svc: svc, log: log}
}

// createMessageRequest is the JSON body for POST /v1/channels/{channelID}/messages.
type createMessageRequest struct {
	Content     string `json:"content"`
	Nonce       string `json:"nonce,omitempty"`
	Type        string `json:"type,omitempty"`
	ReferenceID string `json:"reference_id,omitempty"`
}

// CreateMessage handles POST /v1/channels/{channelID}/messages.
func (h *MessageHandler) CreateMessage(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())

	var body createMessageRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	msg, err := h.svc.CreateMessage(r.Context(), service.CreateMessageRequest{
		ChannelID:   channelID,
		AuthorID:    userID,
		Content:     body.Content,
		Nonce:       body.Nonce,
		Type:        body.Type,
		ReferenceID: body.ReferenceID,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusCreated, msg)
}

// GetMessages handles GET /v1/channels/{channelID}/messages.
// Query: ?before=<cursor>&limit=50
func (h *MessageHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())
	before := r.URL.Query().Get("before")
	limit := QueryInt(r, "limit", 50, 100)

	msgs, err := h.svc.GetMessages(r.Context(), channelID, userID, before, limit)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	// Cursor is the ID of the last message (for next page).
	var cursor string
	if len(msgs) > 0 {
		cursor = msgs[len(msgs)-1].ID
	}

	JSONList(w, msgs, cursor)
}

// editMessageRequest is the JSON body for PATCH /v1/messages/{messageID}.
type editMessageRequest struct {
	Content string `json:"content"`
}

// EditMessage handles PATCH /v1/messages/{messageID}.
func (h *MessageHandler) EditMessage(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "messageID")
	userID := auth.UserIDFromContext(r.Context())

	var body editMessageRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	if err := h.svc.EditMessage(r.Context(), messageID, userID, body.Content); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// DeleteMessage handles DELETE /v1/messages/{messageID}.
func (h *MessageHandler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "messageID")
	userID := auth.UserIDFromContext(r.Context())

	if err := h.svc.DeleteMessage(r.Context(), messageID, userID); err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
