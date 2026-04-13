package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// PollHandler handles poll CRUD and voting routes.
type PollHandler struct {
	svc *service.PollService
	log *zap.Logger
}

// NewPollHandler creates a PollHandler.
func NewPollHandler(svc *service.PollService, log *zap.Logger) *PollHandler {
	return &PollHandler{svc: svc, log: log}
}

// ── Request payloads ─────────────────────────────────────────────────

type createPollRequest struct {
	ChannelID string             `json:"channel_id"`
	Question  string             `json:"question"`
	Options   []createPollOption `json:"options"`
	Duration  int                `json:"duration_seconds"`
	MultiVote bool               `json:"allow_multi_vote"`
}

type createPollOption struct {
	Text  string `json:"text"`
	Emoji string `json:"emoji,omitempty"`
}

type voteRequest struct {
	OptionID string `json:"option_id"`
}

// ── Handlers ─────────────────────────────────────────────────────────

// CreatePoll handles POST /v1/channels/{channelID}/polls.
func (h *PollHandler) CreatePoll(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())

	var body createPollRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	opts := make([]service.PollOptionInput, len(body.Options))
	for i, o := range body.Options {
		opts[i] = service.PollOptionInput{Text: o.Text, Emoji: o.Emoji}
	}

	poll, err := h.svc.CreatePoll(r.Context(), service.CreatePollInput{
		ChannelID:       channelID,
		CreatorID:       userID,
		Question:        body.Question,
		Options:         opts,
		DurationSeconds: body.Duration,
		AllowMultiVote:  body.MultiVote,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusCreated, poll)
}

// GetPoll handles GET /v1/polls/{pollID}.
func (h *PollHandler) GetPoll(w http.ResponseWriter, r *http.Request) {
	pollID := chi.URLParam(r, "pollID")

	poll, err := h.svc.GetPoll(r.Context(), pollID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	JSON(w, http.StatusOK, poll)
}

// Vote handles POST /v1/polls/{pollID}/vote.
func (h *PollHandler) Vote(w http.ResponseWriter, r *http.Request) {
	pollID := chi.URLParam(r, "pollID")
	userID := auth.UserIDFromContext(r.Context())

	var body voteRequest
	if err := DecodeJSON(r, &body); err != nil {
		Error(w, h.log, err)
		return
	}

	err := h.svc.Vote(r.Context(), pollID, userID, body.OptionID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Unvote handles DELETE /v1/polls/{pollID}/vote.
func (h *PollHandler) Unvote(w http.ResponseWriter, r *http.Request) {
	pollID := chi.URLParam(r, "pollID")
	userID := auth.UserIDFromContext(r.Context())

	err := h.svc.Unvote(r.Context(), pollID, userID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// EndPoll handles POST /v1/polls/{pollID}/end.
func (h *PollHandler) EndPoll(w http.ResponseWriter, r *http.Request) {
	pollID := chi.URLParam(r, "pollID")
	userID := auth.UserIDFromContext(r.Context())

	err := h.svc.EndPoll(r.Context(), pollID, userID)
	if err != nil {
		Error(w, h.log, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
