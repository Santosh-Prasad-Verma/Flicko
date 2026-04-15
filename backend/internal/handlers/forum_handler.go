package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ForumHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type voteForumPostRequest struct {
	Vote *int `json:"vote,omitempty"`
}

func NewForumHandler(db *pgxpool.Pool, logger *zap.Logger) *ForumHandler {
	return &ForumHandler{
		db:     db,
		logger: logger.Named("handler.forum"),
	}
}

func (h *ForumHandler) VoteForumPost(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	threadUUID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid forum post id")
		return
	}

	req := voteForumPostRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	voteValue := 1
	if req.Vote != nil {
		voteValue = *req.Vote
	}
	if voteValue != 1 && voteValue != -1 {
		writeError(w, http.StatusBadRequest, "vote must be 1 or -1")
		return
	}

	var isMember bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.threads t
			JOIN public.server_members sm ON sm.server_id = t.server_id
			WHERE t.id = $1
			  AND sm.user_id = $2
		)
	`, threadUUID, userUUID).Scan(&isMember); err != nil {
		h.logger.Error("failed to verify forum thread membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to submit vote")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	var updatedAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.forum_post_votes (thread_id, user_id, vote)
		VALUES ($1, $2, $3)
		ON CONFLICT (thread_id, user_id)
		DO UPDATE SET
			vote = EXCLUDED.vote,
			updated_at = NOW()
		RETURNING updated_at
	`, threadUUID, userUUID, voteValue).Scan(&updatedAt); err != nil {
		h.logger.Error("failed to upsert forum vote", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to submit vote")
		return
	}

	var upvotes int
	var downvotes int
	var score int
	if err = h.db.QueryRow(r.Context(), `
		SELECT
			COUNT(*) FILTER (WHERE vote = 1) AS upvotes,
			COUNT(*) FILTER (WHERE vote = -1) AS downvotes,
			COALESCE(SUM(vote), 0) AS score
		FROM public.forum_post_votes
		WHERE thread_id = $1
	`, threadUUID).Scan(&upvotes, &downvotes, &score); err != nil {
		h.logger.Error("failed to aggregate forum votes", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to submit vote")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"thread_id":  threadUUID.String(),
		"user_id":    userUUID.String(),
		"vote":       voteValue,
		"upvotes":    upvotes,
		"downvotes":  downvotes,
		"score":      score,
		"updated_at": updatedAt,
	})
}
