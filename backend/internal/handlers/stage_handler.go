package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type StageHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewStageHandler(db *pgxpool.Pool, logger *zap.Logger) *StageHandler {
	return &StageHandler{
		db:     db,
		logger: logger.Named("handler.stage"),
	}
}

func (h *StageHandler) RaiseHand(w http.ResponseWriter, r *http.Request) {
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

	channelUUID, serverUUID, err := h.resolveStageChannel(r, mux.Vars(r)["channelId"])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "stage channel not found")
			return
		}
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}

	isMember, err := h.isServerMember(r, serverUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to verify stage membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin raise-hand transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	sessionID, err := h.ensureActiveStageSession(r, tx, channelUUID, serverUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to ensure active stage session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}

	var queueID uuid.UUID
	var position int
	var handRaisedAt time.Time
	err = tx.QueryRow(r.Context(), `
		SELECT id, position, hand_raised_at
		FROM public.stage_speaker_queue
		WHERE session_id = $1
		  AND user_id = $2
		  AND status = 'waiting'
		ORDER BY hand_raised_at DESC
		LIMIT 1
	`, sessionID, userUUID).Scan(&queueID, &position, &handRaisedAt)
	if err == nil {
		if commitErr := tx.Commit(r.Context()); commitErr != nil {
			h.logger.Error("failed to commit existing raise-hand transaction", zap.Error(commitErr))
			writeError(w, http.StatusInternalServerError, "failed to raise hand")
			return
		}
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"id":             queueID.String(),
			"session_id":     sessionID.String(),
			"server_id":      serverUUID.String(),
			"channel_id":     channelUUID.String(),
			"user_id":        userUUID.String(),
			"status":         "waiting",
			"position":       position,
			"hand_raised_at": handRaisedAt,
		})
		return
	}
	if err != nil && err != pgx.ErrNoRows {
		h.logger.Error("failed to query existing raise-hand record", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}

	var nextPosition int
	if err = tx.QueryRow(r.Context(), `
		SELECT COALESCE(MAX(position), 0) + 1
		FROM public.stage_speaker_queue
		WHERE session_id = $1
		  AND status = 'waiting'
	`, sessionID).Scan(&nextPosition); err != nil {
		h.logger.Error("failed to determine next stage queue position", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}

	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.stage_speaker_queue (
			session_id, server_id, channel_id, user_id, position, status, hand_raised_at
		)
		VALUES ($1, $2, $3, $4, $5, 'waiting', NOW())
		RETURNING id, hand_raised_at
	`, sessionID, serverUUID, channelUUID, userUUID, nextPosition).Scan(&queueID, &handRaisedAt); err != nil {
		h.logger.Error("failed to insert stage queue entry", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit raise-hand transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to raise hand")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":             queueID.String(),
		"session_id":     sessionID.String(),
		"server_id":      serverUUID.String(),
		"channel_id":     channelUUID.String(),
		"user_id":        userUUID.String(),
		"status":         "waiting",
		"position":       nextPosition,
		"hand_raised_at": handRaisedAt,
	})
}

func (h *StageHandler) PromoteSpeaker(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requesterUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	vars := mux.Vars(r)
	channelUUID, serverUUID, err := h.resolveStageChannel(r, vars["channelId"])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "stage channel not found")
			return
		}
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}
	targetUUID, err := uuid.Parse(vars["userId"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid target user id")
		return
	}

	isMember, err := h.isServerMember(r, serverUUID, requesterUUID)
	if err != nil {
		h.logger.Error("failed to verify stage promoter membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to promote speaker")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	hasPermission, err := h.hasModerationPermission(r, serverUUID, requesterUUID)
	if err != nil {
		h.logger.Error("failed to verify stage promoter permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to promote speaker")
		return
	}
	if !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}

	var sessionID uuid.UUID
	err = h.db.QueryRow(r.Context(), `
		SELECT id
		FROM public.stage_sessions
		WHERE channel_id = $1
		  AND status = 'active'
		ORDER BY started_at DESC
		LIMIT 1
	`, channelUUID).Scan(&sessionID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "no active stage session")
		return
	}
	if err != nil {
		h.logger.Error("failed to query active stage session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to promote speaker")
		return
	}

	var queueID uuid.UUID
	var promotedAt time.Time
	var priorPosition int
	err = h.db.QueryRow(r.Context(), `
		UPDATE public.stage_speaker_queue
		SET status = 'promoted',
		    promoted_at = NOW(),
		    resolved_by = $3
		WHERE session_id = $1
		  AND user_id = $2
		  AND status = 'waiting'
		RETURNING id, promoted_at, position
	`, sessionID, targetUUID, requesterUUID).Scan(&queueID, &promotedAt, &priorPosition)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "target user is not in the stage queue")
		return
	}
	if err != nil {
		h.logger.Error("failed to promote stage speaker", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to promote speaker")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":               queueID.String(),
		"session_id":       sessionID.String(),
		"server_id":        serverUUID.String(),
		"channel_id":       channelUUID.String(),
		"user_id":          targetUUID.String(),
		"status":           "promoted",
		"prior_position":   priorPosition,
		"promoted_at":      promotedAt,
		"promoted_by_user": requesterUUID.String(),
	})
}

func (h *StageHandler) resolveStageChannel(r *http.Request, channelID string) (uuid.UUID, uuid.UUID, error) {
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}

	var serverID uuid.UUID
	var channelType string
	err = h.db.QueryRow(r.Context(), `
		SELECT server_id, type
		FROM public.channels
		WHERE id = $1
	`, channelUUID).Scan(&serverID, &channelType)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	if channelType != "stage" {
		return uuid.Nil, uuid.Nil, pgx.ErrNoRows
	}
	return channelUUID, serverID, nil
}

func (h *StageHandler) ensureActiveStageSession(
	r *http.Request,
	tx pgx.Tx,
	channelID uuid.UUID,
	serverID uuid.UUID,
	createdBy uuid.UUID,
) (uuid.UUID, error) {
	var sessionID uuid.UUID
	err := tx.QueryRow(r.Context(), `
		SELECT id
		FROM public.stage_sessions
		WHERE channel_id = $1
		  AND status = 'active'
		ORDER BY started_at DESC
		LIMIT 1
	`, channelID).Scan(&sessionID)
	if err == nil {
		return sessionID, nil
	}
	if err != pgx.ErrNoRows {
		return uuid.Nil, err
	}

	err = tx.QueryRow(r.Context(), `
		INSERT INTO public.stage_sessions (
			server_id, channel_id, created_by, status, started_at
		)
		VALUES ($1, $2, $3, 'active', NOW())
		RETURNING id
	`, serverID, channelID, createdBy).Scan(&sessionID)
	return sessionID, err
}

func (h *StageHandler) isServerMember(r *http.Request, serverID, userID uuid.UUID) (bool, error) {
	var isMember bool
	err := h.db.QueryRow(r.Context(), `
		SELECT EXISTS (
			SELECT 1
			FROM public.server_members
			WHERE server_id = $1
			  AND user_id = $2
		)
	`, serverID, userID).Scan(&isMember)
	return isMember, err
}

func (h *StageHandler) hasModerationPermission(r *http.Request, serverID, userID uuid.UUID) (bool, error) {
	var ownerID uuid.UUID
	if err := h.db.QueryRow(r.Context(), `
		SELECT owner_id
		FROM public.servers
		WHERE id = $1
	`, serverID).Scan(&ownerID); err != nil {
		return false, err
	}
	if ownerID == userID {
		return true, nil
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
	`, serverID, userID).Scan(&hasPermission)
	return hasPermission, err
}
