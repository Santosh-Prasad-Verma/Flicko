package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	voicePermissionAdministrator = 2
	voicePermissionManageChannel = 8
	maxVoiceChannelUserLimit     = 99
)

type VoiceAdminHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type moveVoiceUserRequest struct {
	UserID string `json:"user_id"`
}

type patchVoiceChannelRequest struct {
	UserLimit *int `json:"user_limit"`
}

func NewVoiceAdminHandler(db *pgxpool.Pool, logger *zap.Logger) *VoiceAdminHandler {
	return &VoiceAdminHandler{
		db:     db,
		logger: logger.Named("handler.voice_admin"),
	}
}

func (h *VoiceAdminHandler) MoveUser(w http.ResponseWriter, r *http.Request) {
	requesterID := getUserID(r)
	if requesterID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requesterUUID, err := uuid.Parse(requesterID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	targetChannelID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}

	req := moveVoiceUserRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	targetUserUUID, err := uuid.Parse(req.UserID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid target user id")
		return
	}

	serverID, channelType, userLimit, err := h.resolveVoiceChannel(r, targetChannelID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "voice channel not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to resolve voice channel for move", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to move user")
		return
	}
	if channelType != "voice" && channelType != "stage" {
		writeError(w, http.StatusBadRequest, "target channel must be voice or stage")
		return
	}

	hasPermission, err := h.hasVoiceAdminPermission(r, serverID, requesterUUID)
	if err != nil {
		h.logger.Error("failed to check voice move permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to move user")
		return
	}
	if !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}

	var sourceChannelID uuid.UUID
	err = h.db.QueryRow(r.Context(), `
		SELECT channel_id
		FROM public.voice_states
		WHERE user_id = $1
	`, targetUserUUID).Scan(&sourceChannelID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "target user is not in voice")
		return
	}
	if err != nil {
		h.logger.Error("failed to resolve current voice channel", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to move user")
		return
	}
	if sourceChannelID == targetChannelID {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"server_id":         serverID.String(),
			"target_channel_id": targetChannelID.String(),
			"source_channel_id": sourceChannelID.String(),
			"user_id":           targetUserUUID.String(),
			"moved":             false,
		})
		return
	}

	currentUsers, err := h.countVoiceUsers(r, targetChannelID)
	if err != nil {
		h.logger.Error("failed to count voice users", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to move user")
		return
	}
	if userLimit > 0 && currentUsers >= userLimit {
		writeError(w, http.StatusConflict, "target channel is full")
		return
	}

	var movedAt time.Time
	err = h.db.QueryRow(r.Context(), `
		UPDATE public.voice_states
		SET channel_id = $1,
		    server_id = $2,
		    updated_at = NOW()
		WHERE user_id = $3
		RETURNING updated_at
	`, targetChannelID, serverID, targetUserUUID).Scan(&movedAt)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "target user is not in voice")
		return
	}
	if err != nil {
		h.logger.Error("failed to move voice user", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to move user")
		return
	}

	if err = h.insertVoiceAdminAction(r, serverID, targetChannelID, requesterUUID, &targetUserUUID, "move_user", map[string]interface{}{
		"target_channel_id": targetChannelID.String(),
		"source_channel_id": sourceChannelID.String(),
	}); err != nil {
		h.logger.Warn("failed to log move_user action", zap.Error(err))
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":         serverID.String(),
		"target_channel_id": targetChannelID.String(),
		"user_id":           targetUserUUID.String(),
		"moved_at":          movedAt,
	})
}

func (h *VoiceAdminHandler) PatchVoiceChannel(w http.ResponseWriter, r *http.Request) {
	requesterID := getUserID(r)
	if requesterID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requesterUUID, err := uuid.Parse(requesterID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	channelID, err := uuid.Parse(mux.Vars(r)["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}

	req := patchVoiceChannelRequest{}
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.UserLimit == nil {
		writeError(w, http.StatusBadRequest, "user_limit is required")
		return
	}
	if *req.UserLimit < 0 || *req.UserLimit > maxVoiceChannelUserLimit {
		writeError(w, http.StatusBadRequest, "user_limit must be between 0 and 99")
		return
	}

	serverID, channelType, _, err := h.resolveVoiceChannel(r, channelID)
	if err == pgx.ErrNoRows {
		writeError(w, http.StatusNotFound, "voice channel not found")
		return
	}
	if err != nil {
		h.logger.Error("failed to resolve voice channel for patch", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to patch voice channel")
		return
	}
	if channelType != "voice" && channelType != "stage" {
		writeError(w, http.StatusBadRequest, "target channel must be voice or stage")
		return
	}

	hasPermission, err := h.hasVoiceAdminPermission(r, serverID, requesterUUID)
	if err != nil {
		h.logger.Error("failed to check patch voice permissions", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to patch voice channel")
		return
	}
	if !hasPermission {
		writeError(w, http.StatusForbidden, "insufficient permissions")
		return
	}

	var updatedAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		UPDATE public.channels
		SET user_limit = $2,
		    updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at
	`, channelID, *req.UserLimit).Scan(&updatedAt); err != nil {
		h.logger.Error("failed to update voice channel user_limit", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to patch voice channel")
		return
	}

	if err = h.insertVoiceAdminAction(r, serverID, channelID, requesterUUID, nil, "update_user_limit", map[string]interface{}{
		"user_limit": *req.UserLimit,
	}); err != nil {
		h.logger.Warn("failed to log update_user_limit action", zap.Error(err))
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"server_id":  serverID.String(),
		"channel_id": channelID.String(),
		"user_limit": *req.UserLimit,
		"updated_at": updatedAt,
	})
}

func (h *VoiceAdminHandler) resolveVoiceChannel(r *http.Request, channelID uuid.UUID) (uuid.UUID, string, int, error) {
	var serverID uuid.UUID
	var channelType string
	var userLimit int
	err := h.db.QueryRow(r.Context(), `
		SELECT server_id, type, COALESCE(user_limit, 0)
		FROM public.channels
		WHERE id = $1
	`, channelID).Scan(&serverID, &channelType, &userLimit)
	return serverID, channelType, userLimit, err
}

func (h *VoiceAdminHandler) hasVoiceAdminPermission(r *http.Request, serverID, userID uuid.UUID) (bool, error) {
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
			  AND (
				(COALESCE(r.permissions, 0) & $3) > 0
				OR (COALESCE(r.permissions, 0) & $4) > 0
			  )
		)
	`, serverID, userID, voicePermissionManageChannel, voicePermissionAdministrator).Scan(&hasPermission)
	return hasPermission, err
}

func (h *VoiceAdminHandler) countVoiceUsers(r *http.Request, channelID uuid.UUID) (int, error) {
	var count int
	err := h.db.QueryRow(r.Context(), `
		SELECT COUNT(*)
		FROM public.voice_states
		WHERE channel_id = $1
	`, channelID).Scan(&count)
	return count, err
}

func (h *VoiceAdminHandler) insertVoiceAdminAction(
	r *http.Request,
	serverID uuid.UUID,
	channelID uuid.UUID,
	actorID uuid.UUID,
	targetUserID *uuid.UUID,
	actionType string,
	metadata map[string]interface{},
) error {
	raw, err := json.Marshal(metadata)
	if err != nil {
		return err
	}
	_, err = h.db.Exec(r.Context(), `
		INSERT INTO public.voice_admin_actions (
			server_id, channel_id, actor_id, target_user_id, action_type, action_metadata
		)
		VALUES ($1, $2, $3, $4, $5, $6::jsonb)
	`, serverID, channelID, actorID, targetUserID, actionType, raw)
	return err
}
