package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ModerationActionsHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type timeoutMemberRequest struct {
	DurationSeconds int    `json:"duration_seconds"`
	Reason          string `json:"reason,omitempty"`
}

type banMemberRequest struct {
	Reason          string `json:"reason,omitempty"`
	DurationSeconds *int   `json:"duration_seconds,omitempty"`
}

func NewModerationActionsHandler(db *pgxpool.Pool, logger *zap.Logger) *ModerationActionsHandler {
	return &ModerationActionsHandler{
		db:     db,
		logger: logger.Named("handler.moderation_actions"),
	}
}

func (h *ModerationActionsHandler) TimeoutMember(w http.ResponseWriter, r *http.Request) {
	requesterID, serverID, targetID, ok := h.parseMemberActionIDs(w, r)
	if !ok {
		return
	}

	if requesterID == targetID {
		writeError(w, http.StatusBadRequest, "cannot timeout yourself")
		return
	}

	req := timeoutMemberRequest{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.DurationSeconds < 1 || req.DurationSeconds > 2419200 { // 28 days
		writeError(w, http.StatusBadRequest, "duration_seconds must be between 1 and 2419200")
		return
	}

	isOwner, hasPermission, ownerID, err := h.getModerationAuth(r, serverID, requesterID)
	if err != nil {
		h.logger.Error("failed to evaluate timeout permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to timeout member")
		return
	}
	if !isOwner && !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}
	if targetID == ownerID {
		writeError(w, http.StatusForbidden, "cannot timeout server owner")
		return
	}

	var timeoutUntil time.Time
	if err = h.db.QueryRow(r.Context(), `
		UPDATE public.server_members
		SET timeout_until = NOW() + ($3 * INTERVAL '1 second')
		WHERE server_id = $1
		  AND user_id = $2
		RETURNING timeout_until
	`, serverID, targetID, req.DurationSeconds).Scan(&timeoutUntil); err != nil {
		writeError(w, http.StatusNotFound, "member not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":     serverID.String(),
		"user_id":       targetID.String(),
		"action":        "timeout",
		"duration_secs": req.DurationSeconds,
		"timeout_until": timeoutUntil,
		"reason":        req.Reason,
	})
}

func (h *ModerationActionsHandler) BanMember(w http.ResponseWriter, r *http.Request) {
	requesterID, serverID, targetID, ok := h.parseMemberActionIDs(w, r)
	if !ok {
		return
	}

	if requesterID == targetID {
		writeError(w, http.StatusBadRequest, "cannot ban yourself")
		return
	}

	req := banMemberRequest{}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.DurationSeconds != nil && (*req.DurationSeconds < 1 || *req.DurationSeconds > 31536000) {
		writeError(w, http.StatusBadRequest, "duration_seconds must be between 1 and 31536000")
		return
	}

	isOwner, hasPermission, ownerID, err := h.getModerationAuth(r, serverID, requesterID)
	if err != nil {
		h.logger.Error("failed to evaluate ban permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to ban member")
		return
	}
	if !isOwner && !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}
	if targetID == ownerID {
		writeError(w, http.StatusForbidden, "cannot ban server owner")
		return
	}

	var expiresAt *time.Time
	if req.DurationSeconds != nil {
		ts := time.Now().UTC().Add(time.Duration(*req.DurationSeconds) * time.Second)
		expiresAt = &ts
	}

	// Keep behavior consistent with old and new schemas.
	if err = h.insertBan(r, serverID, targetID, requesterID, req.Reason, expiresAt); err != nil {
		h.logger.Error("failed to insert ban", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to ban member")
		return
	}

	if _, err = h.db.Exec(r.Context(), `
		DELETE FROM public.server_members
		WHERE server_id = $1
		  AND user_id = $2
	`, serverID, targetID); err != nil {
		h.logger.Warn("failed to remove banned member from server_members", zap.Error(err))
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":     serverID.String(),
		"user_id":       targetID.String(),
		"action":        "ban",
		"reason":        req.Reason,
		"duration_secs": req.DurationSeconds,
		"expires_at":    expiresAt,
		"revoked_at":    nil,
	})
}

func (h *ModerationActionsHandler) parseMemberActionIDs(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, uuid.UUID, bool) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return uuid.Nil, uuid.Nil, uuid.Nil, false
	}
	requesterID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return uuid.Nil, uuid.Nil, uuid.Nil, false
	}

	vars := mux.Vars(r)
	serverID, err := uuid.Parse(vars["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return uuid.Nil, uuid.Nil, uuid.Nil, false
	}
	targetID, err := uuid.Parse(vars["userId"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid target user id")
		return uuid.Nil, uuid.Nil, uuid.Nil, false
	}
	return requesterID, serverID, targetID, true
}

func (h *ModerationActionsHandler) getModerationAuth(r *http.Request, serverID, requesterID uuid.UUID) (bool, bool, uuid.UUID, error) {
	var ownerID uuid.UUID
	if err := h.db.QueryRow(r.Context(), `
		SELECT owner_id
		FROM public.servers
		WHERE id = $1
	`, serverID).Scan(&ownerID); err != nil {
		return false, false, uuid.Nil, err
	}
	isOwner := ownerID == requesterID
	if isOwner {
		return true, true, ownerID, nil
	}

	var hasPermission bool
	err := h.db.QueryRow(r.Context(), `
		SELECT EXISTS(
			SELECT 1
			FROM public.member_roles mr
			JOIN public.roles r ON r.id = mr.role_id
			WHERE mr.server_id = $1
			  AND mr.user_id = $2
			  AND ((COALESCE(r.permissions, 0) & 8) > 0 OR (COALESCE(r.permissions, 0) & 2) > 0)
		)
	`, serverID, requesterID).Scan(&hasPermission)
	return false, hasPermission, ownerID, err
}

func (h *ModerationActionsHandler) insertBan(
	r *http.Request,
	serverID uuid.UUID,
	targetID uuid.UUID,
	requesterID uuid.UUID,
	reason string,
	expiresAt *time.Time,
) error {
	_, err := h.db.Exec(r.Context(), `
		INSERT INTO public.bans (server_id, user_id, reason, banned_by, expires_at, revoked_at)
		VALUES ($1, $2, $3, $4, $5, NULL)
		ON CONFLICT (server_id, user_id) DO UPDATE
		SET reason = EXCLUDED.reason,
		    banned_by = EXCLUDED.banned_by,
		    expires_at = EXCLUDED.expires_at,
		    revoked_at = NULL
	`, serverID, targetID, reason, requesterID, expiresAt)
	if err == nil {
		return nil
	}

	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "42P01" {
		_, fallbackErr := h.db.Exec(r.Context(), `
			INSERT INTO public.server_bans (server_id, user_id, reason, executor_id, expires_at, revoked_at)
			VALUES ($1, $2, $3, $4, $5, NULL)
			ON CONFLICT (server_id, user_id) DO UPDATE
			SET reason = EXCLUDED.reason,
			    executor_id = EXCLUDED.executor_id,
			    expires_at = EXCLUDED.expires_at,
			    revoked_at = NULL
		`, serverID, targetID, reason, requesterID, expiresAt)
		return fallbackErr
	}
	return err
}
