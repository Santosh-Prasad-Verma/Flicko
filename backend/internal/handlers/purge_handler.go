package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type PurgeHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type purgeRequest struct {
	Count  int     `json:"count"`
	UserID *string `json:"user_id,omitempty"`
	Reason string  `json:"reason,omitempty"`
}

func NewPurgeHandler(db *pgxpool.Pool, logger *zap.Logger) *PurgeHandler {
	return &PurgeHandler{
		db:     db,
		logger: logger.Named("handler.purge"),
	}
}

func (h *PurgeHandler) PurgeChannelMessages(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requesterID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	channelID := mux.Vars(r)["id"]
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}

	var req purgeRequest
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Count < 1 || req.Count > 100 {
		writeError(w, http.StatusBadRequest, "count must be between 1 and 100")
		return
	}

	var targetUserID *uuid.UUID
	if req.UserID != nil && *req.UserID != "" {
		targetParsed, parseErr := uuid.Parse(*req.UserID)
		if parseErr != nil {
			writeError(w, http.StatusBadRequest, "invalid target user id")
			return
		}
		targetUserID = &targetParsed
	}

	var serverID uuid.UUID
	var hasPermission bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT c.server_id,
		       (
		         s.owner_id = $2
		         OR EXISTS (
		           SELECT 1
		           FROM public.member_roles mr
		           JOIN public.roles r2 ON r2.id = mr.role_id
		           WHERE mr.server_id = c.server_id
		             AND mr.user_id = $2
		             AND ((COALESCE(r2.permissions, 0) & 8) > 0 OR (COALESCE(r2.permissions, 0) & 2) > 0)
		         )
		       ) AS has_permission
		FROM public.channels c
		JOIN public.servers s ON s.id = c.server_id
		WHERE c.id = $1
	`, channelUUID, requesterID).Scan(&serverID, &hasPermission); err != nil {
		writeError(w, http.StatusNotFound, "channel not found")
		return
	}
	if !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}

	now := time.Now().UTC()
	auditMetadata, err := json.Marshal(map[string]interface{}{
		"operation":      "message_purge",
		"channel_id":     channelUUID.String(),
		"server_id":      serverID.String(),
		"target_user_id": req.UserID,
		"request_source": "api",
	})
	if err != nil {
		h.logger.Error("failed to encode purge audit metadata", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin purge transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var jobID uuid.UUID
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.purge_jobs (
			server_id, channel_id, requested_by, target_user_id, status, requested_count,
			reason, audit_metadata, requested_at, started_at
		)
		VALUES ($1, $2, $3, $4, 'processing', $5, $6, $7::jsonb, NOW(), NOW())
		RETURNING id
	`, serverID, channelUUID, requesterID, targetUserID, req.Count, req.Reason, auditMetadata).Scan(&jobID); err != nil {
		h.logger.Error("failed to create purge job", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	var deletedCount int64
	if targetUserID == nil {
		err = tx.QueryRow(r.Context(), `
			WITH target_messages AS (
				SELECT id
				FROM public.messages
				WHERE channel_id = $1
				ORDER BY created_at DESC
				LIMIT $2
			),
			deleted AS (
				DELETE FROM public.messages m
				USING target_messages t
				WHERE m.id = t.id
				RETURNING m.id
			)
			SELECT COUNT(*) FROM deleted
		`, channelUUID, req.Count).Scan(&deletedCount)
	} else {
		err = tx.QueryRow(r.Context(), `
			WITH target_messages AS (
				SELECT id
				FROM public.messages
				WHERE channel_id = $1
				  AND author_id = $2
				ORDER BY created_at DESC
				LIMIT $3
			),
			deleted AS (
				DELETE FROM public.messages m
				USING target_messages t
				WHERE m.id = t.id
				RETURNING m.id
			)
			SELECT COUNT(*) FROM deleted
		`, channelUUID, *targetUserID, req.Count).Scan(&deletedCount)
	}
	if err != nil {
		h.logger.Error("failed to delete messages for purge", zap.Error(err))
		if _, updateErr := tx.Exec(r.Context(), `
			UPDATE public.purge_jobs
			SET status = 'failed',
			    error_message = $2,
			    completed_at = NOW()
			WHERE id = $1
		`, jobID, err.Error()); updateErr != nil {
			h.logger.Error("failed to mark purge job failed", zap.Error(updateErr))
		}
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	finalMetadata, err := json.Marshal(map[string]interface{}{
		"operation":      "message_purge",
		"channel_id":     channelUUID.String(),
		"server_id":      serverID.String(),
		"target_user_id": req.UserID,
		"request_source": "api",
		"deleted_count":  deletedCount,
	})
	if err != nil {
		h.logger.Error("failed to encode final purge audit metadata", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	var completedAt time.Time
	if err = tx.QueryRow(r.Context(), `
		UPDATE public.purge_jobs
		SET status = 'completed',
		    deleted_count = $2,
		    completed_at = NOW(),
		    audit_metadata = $3::jsonb
		WHERE id = $1
		RETURNING completed_at
	`, jobID, deletedCount, finalMetadata).Scan(&completedAt); err != nil {
		h.logger.Error("failed to finalize purge job", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit purge transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to purge messages")
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]interface{}{
		"job_id":          jobID.String(),
		"status":          "completed",
		"server_id":       serverID.String(),
		"channel_id":      channelUUID.String(),
		"requested_count": req.Count,
		"deleted_count":   deletedCount,
		"completed_at":    completedAt,
		"requested_at":    now,
	})
}
