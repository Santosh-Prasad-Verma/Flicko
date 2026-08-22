package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ReactionRoleHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

type createReactionRoleRequest struct {
	ChannelID string `json:"channel_id"`
	MessageID string `json:"message_id"`
	Emoji     string `json:"emoji"`
	RoleID    string `json:"role_id"`
}

func NewReactionRoleHandler(db *pgxpool.Pool, logger *zap.Logger) *ReactionRoleHandler {
	return &ReactionRoleHandler{
		db:     db,
		logger: logger.Named("handler.reaction_roles"),
	}
}

func (h *ReactionRoleHandler) CreateReactionRole(w http.ResponseWriter, r *http.Request) {
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

	serverID := mux.Vars(r)["id"]
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}

	var req createReactionRoleRequest
	if err = json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	channelUUID, err := uuid.Parse(req.ChannelID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}
	messageUUID, err := uuid.Parse(req.MessageID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid message id")
		return
	}
	roleUUID, err := uuid.Parse(req.RoleID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid role id")
		return
	}
	req.Emoji = strings.TrimSpace(req.Emoji)
	if req.Emoji == "" {
		writeError(w, http.StatusBadRequest, "emoji is required")
		return
	}

	hasPerm, permErr := h.hasManageRolesPermission(r, serverUUID, userUUID)
	if permErr != nil {
		h.logger.Error("failed to verify server permissions", zap.Error(permErr))
		writeError(w, http.StatusInternalServerError, "failed to create reaction role mapping")
		return
	}
	if !hasPerm {
		writeError(w, http.StatusForbidden, "insufficient permissions: MANAGE_ROLES required")
		return
	}

	var mappingID uuid.UUID
	var createdAt time.Time
	if err = h.db.QueryRow(r.Context(), `
		INSERT INTO public.reaction_roles (
			server_id, channel_id, message_id, emoji, role_id, created_by
		)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`, serverUUID, channelUUID, messageUUID, req.Emoji, roleUUID, userUUID).Scan(&mappingID, &createdAt); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "reaction role mapping already exists")
			return
		}
		h.logger.Error("failed to create reaction role mapping", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create reaction role mapping")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":         mappingID.String(),
		"server_id":  serverUUID.String(),
		"channel_id": channelUUID.String(),
		"message_id": messageUUID.String(),
		"emoji":      req.Emoji,
		"role_id":    roleUUID.String(),
		"created_at": createdAt,
	})
}

func (h *ReactionRoleHandler) DeleteReactionRole(w http.ResponseWriter, r *http.Request) {
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

	vars := mux.Vars(r)
	serverUUID, err := uuid.Parse(vars["id"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server id")
		return
	}
	mappingUUID, err := uuid.Parse(vars["mappingId"])
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid mapping id")
		return
	}

	hasPerm, permErr := h.hasManageRolesPermission(r, serverUUID, userUUID)
	if permErr != nil {
		h.logger.Error("failed to verify server permissions", zap.Error(permErr))
		writeError(w, http.StatusInternalServerError, "failed to delete reaction role mapping")
		return
	}
	if !hasPerm {
		writeError(w, http.StatusForbidden, "insufficient permissions: MANAGE_ROLES required")
		return
	}

	var deletedID uuid.UUID
	if err = h.db.QueryRow(r.Context(), `
		DELETE FROM public.reaction_roles
		WHERE id = $1
		  AND server_id = $2
		RETURNING id
	`, mappingUUID, serverUUID).Scan(&deletedID); err != nil {
		if err == pgx.ErrNoRows {
			writeError(w, http.StatusNotFound, "reaction role mapping not found")
			return
		}
		h.logger.Error("failed to delete reaction role mapping", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to delete reaction role mapping")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":      deletedID.String(),
		"deleted": true,
	})
}

func (h *ReactionRoleHandler) hasManageRolesPermission(r *http.Request, serverID, userID uuid.UUID) (bool, error) {
	var hasPerm bool
	err := h.db.QueryRow(r.Context(), `
		SELECT (s.owner_id = $2 OR EXISTS (
			SELECT 1 FROM public.member_roles mr
			JOIN public.roles r ON r.id = mr.role_id
			WHERE mr.server_id = $1 AND mr.user_id = $2
			  AND ((COALESCE(r.permissions, 0) & 268435456) > 0
			    OR (COALESCE(r.permissions, 0) & 8) > 0
			    OR (COALESCE(r.permissions, 0) & 32) > 0)
		))
		FROM public.servers s WHERE s.id = $1
	`, serverID, userID).Scan(&hasPerm)
	return hasPerm, err
}
