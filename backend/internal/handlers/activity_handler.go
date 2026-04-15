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

type ActivityHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

var validActivitySessionStates = map[string]struct{}{
	"idle":      {},
	"launching": {},
	"active":    {},
	"closing":   {},
	"ended":     {},
}

const (
	maxStatePatchKeys  = 100
	maxStatePatchBytes = 16 * 1024
)

const participantRoleOnLeaveExpr = "CASE WHEN role = 'host' THEN 'participant' ELSE role END"

func NewActivityHandler(db *pgxpool.Pool, logger *zap.Logger) *ActivityHandler {
	return &ActivityHandler{
		db:     db,
		logger: logger.Named("handler.activities"),
	}
}

type LaunchActivityRequest struct {
	ActivityID string `json:"activity_id"`
	ChannelID  string `json:"channel_id"`
	ServerID   string `json:"server_id"`
}

type UpdateActivityStateRequest struct {
	State      string                 `json:"state"`
	StatePatch map[string]interface{} `json:"state_patch"`
}

type ActivityCatalogItem struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Description     string `json:"description"`
	IconURL         string `json:"icon_url"`
	Category        string `json:"category"`
	MaxParticipants int    `json:"max_participants"`
	IsPremium       bool   `json:"is_premium"`
	EmbedURL        string `json:"embed_url"`
	Developer       string `json:"developer"`
	AvgDuration     string `json:"avg_duration"`
	Enabled         bool   `json:"enabled"`
}

type ActivityParticipantResponse struct {
	UserID    string    `json:"user_id"`
	JoinedAt  time.Time `json:"joined_at"`
	SessionID string    `json:"session_id"`
	Role      string    `json:"role"`
	LeftAt    *time.Time `json:"left_at,omitempty"`
}

type ActivitySessionResponse struct {
	ID                string     `json:"id"`
	ActivityID        string     `json:"activity_id"`
	ChannelID         string     `json:"channel_id"`
	ServerID          string     `json:"server_id"`
	HostUserID        string     `json:"host_user_id"`
	PreviousHostUserID *string    `json:"previous_host_user_id,omitempty"`
	State             string     `json:"state"`
	EmbedURL          string     `json:"embed_url"`
	StartedAt         *time.Time `json:"started_at,omitempty"`
	EndedAt           *time.Time `json:"ended_at,omitempty"`
	EndedReason       *string    `json:"ended_reason,omitempty"`
	LastHeartbeatAt   *time.Time `json:"last_heartbeat_at,omitempty"`
	HostTransferredAt *time.Time `json:"host_transferred_at,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	ParticipantCount  int        `json:"participant_count"`
}

// GetCatalog handles GET /api/v1/activities/catalog
func (h *ActivityHandler) GetCatalog(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(), `
		SELECT id, name, COALESCE(description, ''), COALESCE(icon_url, ''), category,
		       COALESCE(max_participants, 25), COALESCE(is_premium, false),
		       COALESCE(embed_url, ''), COALESCE(developer, 'Flicko'),
		       COALESCE(avg_duration, '~15 min'), COALESCE(enabled, true)
		FROM public.activities
		WHERE user_id IS NULL
		  AND COALESCE(enabled, true) = true
		ORDER BY name ASC
	`)
	if err != nil {
		h.logger.Error("failed to query activities catalog", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch catalog")
		return
	}
	defer rows.Close()

	items := make([]ActivityCatalogItem, 0, 16)
	for rows.Next() {
		var item ActivityCatalogItem
		if scanErr := rows.Scan(
			&item.ID, &item.Name, &item.Description, &item.IconURL, &item.Category,
			&item.MaxParticipants, &item.IsPremium, &item.EmbedURL, &item.Developer,
			&item.AvgDuration, &item.Enabled,
		); scanErr != nil {
			h.logger.Error("failed to scan catalog row", zap.Error(scanErr))
			writeError(w, http.StatusInternalServerError, "failed to parse catalog")
			return
		}
		items = append(items, item)
	}

	if rows.Err() != nil {
		h.logger.Error("activities catalog row iteration failed", zap.Error(rows.Err()))
		writeError(w, http.StatusInternalServerError, "failed to fetch catalog")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"items": items,
		"count": len(items),
	})
}

// Launch handles POST /api/v1/activities/launch
func (h *ActivityHandler) Launch(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req LaunchActivityRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.ActivityID == "" || req.ChannelID == "" || req.ServerID == "" {
		writeError(w, http.StatusBadRequest, "activity_id, channel_id, and server_id are required")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	activityUUID, err := uuid.Parse(req.ActivityID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid activity_id")
		return
	}
	channelUUID, err := uuid.Parse(req.ChannelID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel_id")
		return
	}
	serverUUID, err := uuid.Parse(req.ServerID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid server_id")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin activity launch transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to launch activity")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var embedURL string
	if err = tx.QueryRow(r.Context(), `
		SELECT COALESCE(embed_url, '')
		FROM public.activities
		WHERE id = $1
		  AND user_id IS NULL
		  AND COALESCE(enabled, true) = true
		LIMIT 1
	`, activityUUID).Scan(&embedURL); err != nil {
		h.logger.Error("failed to validate activity", zap.Error(err))
		writeError(w, http.StatusNotFound, "activity not found")
		return
	}

	var sessionID string
	var state string
	var createdAt time.Time
	var heartbeatAt *time.Time
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.activity_sessions (activity_id, channel_id, server_id, host_user_id, state, embed_url, last_heartbeat_at)
		VALUES ($1, $2, $3, $4, 'launching', $5, NOW())
		RETURNING id, state, created_at, embed_url, last_heartbeat_at
	`, activityUUID, channelUUID, serverUUID, userUUID, embedURL).Scan(&sessionID, &state, &createdAt, &embedURL, &heartbeatAt); err != nil {
		h.logger.Error("failed to create activity session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create activity session")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		INSERT INTO public.activity_participants (session_id, user_id, role, left_at)
		VALUES ($1, $2, 'host', NULL)
		ON CONFLICT (session_id, user_id) DO NOTHING
	`, sessionID, userUUID); err != nil {
		h.logger.Error("failed to add host participant", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create activity participant")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit activity launch transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to launch activity")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"session_id":   sessionID,
		"state":        state,
		"embed_url":    embedURL,
		"host_user_id": userID,
		"created_at":   createdAt,
		"last_heartbeat_at": heartbeatAt,
	})
}

// Join handles POST /api/v1/activities/{sessionId}/join
func (h *ActivityHandler) Join(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}

	if _, err = h.db.Exec(r.Context(), `
		INSERT INTO public.activity_participants (session_id, user_id, role, left_at)
		VALUES ($1, $2, 'participant', NULL)
		ON CONFLICT (session_id, user_id)
		DO UPDATE SET
			left_at = NULL,
			role = CASE
				WHEN activity_participants.left_at IS NOT NULL THEN 'participant'
				ELSE activity_participants.role
			END
	`, sessionUUID, userUUID); err != nil {
		h.logger.Error("failed to join activity session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to join activity session")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "joined"})
}

// Leave handles POST /api/v1/activities/{sessionId}/leave
func (h *ActivityHandler) Leave(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin leave transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to leave activity session")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.activity_participants
		SET left_at = NOW(),
		    role = `+participantRoleOnLeaveExpr+`
		WHERE session_id = $1 AND user_id = $2
	`, sessionUUID, userUUID); err != nil {
		h.logger.Error("failed to remove participant", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to leave activity session")
		return
	}

	// If host left, transfer host to oldest participant; if no participants remain, end session.
	var currentHost uuid.UUID
	hostQueryErr := tx.QueryRow(r.Context(), `
		SELECT host_user_id
		FROM public.activity_sessions
		WHERE id = $1
	`, sessionUUID).Scan(&currentHost)
	if hostQueryErr == nil && currentHost == userUUID {
		var nextHost uuid.UUID
		nextHostErr := tx.QueryRow(r.Context(), `
			SELECT user_id
			FROM public.activity_participants
			WHERE session_id = $1
			  AND left_at IS NULL
			ORDER BY created_at ASC
			LIMIT 1
		`, sessionUUID).Scan(&nextHost)

		if nextHostErr == nil {
			if _, err = tx.Exec(r.Context(), `
				UPDATE public.activity_sessions
				SET host_user_id = $2,
				    previous_host_user_id = $3,
				    host_transferred_at = NOW(),
				    last_heartbeat_at = NOW()
				WHERE id = $1
			`, sessionUUID, nextHost, userUUID); err != nil {
				h.logger.Error("failed to transfer activity host", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to leave activity session")
				return
			}
			if _, err = tx.Exec(r.Context(), `
				UPDATE public.activity_participants
				SET role = 'host'
				WHERE session_id = $1
				  AND user_id = $2
				  AND left_at IS NULL
			`, sessionUUID, nextHost); err != nil {
				h.logger.Error("failed to promote new activity host", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to leave activity session")
				return
			}
		} else {
			if _, err = tx.Exec(r.Context(), `
				UPDATE public.activity_sessions
				SET state = 'ended',
				    ended_at = NOW(),
				    ended_reason = 'host_left',
				    last_heartbeat_at = NOW()
				WHERE id = $1
			`, sessionUUID); err != nil {
				h.logger.Error("failed to end empty activity session", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to leave activity session")
				return
			}
		}
	}
	var activeParticipants int
	if err = tx.QueryRow(r.Context(), `
		SELECT COUNT(*)
		FROM public.activity_participants
		WHERE session_id = $1
		  AND left_at IS NULL
	`, sessionUUID).Scan(&activeParticipants); err != nil {
		h.logger.Error("failed to count active participants", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to leave activity session")
		return
	}
	if activeParticipants == 0 {
		if _, err = tx.Exec(r.Context(), `
			UPDATE public.activity_sessions
			SET state = 'ended',
			    ended_at = COALESCE(ended_at, NOW()),
			    ended_reason = COALESCE(ended_reason, 'empty'),
			    last_heartbeat_at = NOW()
			WHERE id = $1
		`, sessionUUID); err != nil {
			h.logger.Error("failed to end empty activity session", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to leave activity session")
			return
		}
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit leave transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to leave activity session")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

// UpdateState handles POST /api/v1/activities/{sessionId}/state
func (h *ActivityHandler) UpdateState(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}

	var req UpdateActivityStateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.State == "" {
		writeError(w, http.StatusBadRequest, "state is required")
		return
	}
	if _, ok := validActivitySessionStates[req.State]; !ok {
		writeError(w, http.StatusBadRequest, "invalid state")
		return
	}

	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin update state transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	switch req.State {
	case "active":
		_, err = tx.Exec(r.Context(), `
			UPDATE public.activity_sessions
			SET state = $2,
			    started_at = COALESCE(started_at, NOW()),
			    last_heartbeat_at = NOW()
			WHERE id = $1
		`, sessionUUID, req.State)
	case "ended":
		_, err = tx.Exec(r.Context(), `
			UPDATE public.activity_sessions
			SET state = $2,
			    ended_at = NOW(),
			    ended_reason = COALESCE(ended_reason, 'host_ended'),
			    last_heartbeat_at = NOW()
			WHERE id = $1
		`, sessionUUID, req.State)
	default:
		_, err = tx.Exec(r.Context(), `
			UPDATE public.activity_sessions
			SET state = $2,
			    last_heartbeat_at = NOW()
			WHERE id = $1
		`, sessionUUID, req.State)
	}
	if err != nil {
		h.logger.Error("failed to update session state", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}

	patch := req.StatePatch
	if patch == nil {
		patch = map[string]interface{}{}
	}
	if len(patch) > maxStatePatchKeys {
		writeError(w, http.StatusBadRequest, "state_patch has too many keys")
		return
	}
	patchBytes, marshalErr := json.Marshal(patch)
	if marshalErr != nil {
		writeError(w, http.StatusBadRequest, "invalid state_patch")
		return
	}
	if len(patchBytes) > maxStatePatchBytes {
		writeError(w, http.StatusBadRequest, "state_patch exceeds 16KB")
		return
	}

	var version int64
	if err = tx.QueryRow(r.Context(), `
		SELECT COALESCE(MAX(version), 0) + 1
		FROM public.activity_state_snapshots
		WHERE session_id = $1
	`, sessionUUID).Scan(&version); err != nil {
		h.logger.Error("failed to compute snapshot version", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		INSERT INTO public.activity_state_snapshots (session_id, version, host_user_id, state_patch)
		VALUES ($1, $2, $3, $4)
	`, sessionUUID, version, userUUID, patch); err != nil {
		h.logger.Error("failed to insert activity state snapshot", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit activity state transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "updated",
		"version": version,
	})
}

// GetParticipants handles GET /api/v1/activities/{sessionId}/participants
func (h *ActivityHandler) GetParticipants(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}

	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT session_id, user_id, created_at, role, left_at
		FROM public.activity_participants
		WHERE session_id = $1
		ORDER BY created_at ASC
	`, sessionUUID)
	if err != nil {
		h.logger.Error("failed to query participants", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch participants")
		return
	}
	defer rows.Close()

	items := make([]ActivityParticipantResponse, 0, 16)
	for rows.Next() {
		var item ActivityParticipantResponse
		if scanErr := rows.Scan(&item.SessionID, &item.UserID, &item.JoinedAt, &item.Role, &item.LeftAt); scanErr != nil {
			h.logger.Error("failed to scan participant row", zap.Error(scanErr))
			writeError(w, http.StatusInternalServerError, "failed to parse participants")
			return
		}
		items = append(items, item)
	}

	if rows.Err() != nil {
		h.logger.Error("participant row iteration failed", zap.Error(rows.Err()))
		writeError(w, http.StatusInternalServerError, "failed to fetch participants")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"items": items,
		"count": len(items),
	})
}

// End handles POST /api/v1/activities/{sessionId}/end
func (h *ActivityHandler) End(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin end transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to end activity session")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	res, err := tx.Exec(r.Context(), `
		UPDATE public.activity_sessions
		SET state = 'ended',
		    ended_at = NOW(),
		    ended_reason = 'host_ended',
		    last_heartbeat_at = NOW()
		WHERE id = $1
		  AND host_user_id = $2
	`, sessionUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to end activity session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to end activity session")
		return
	}
	if res.RowsAffected() == 0 {
		writeError(w, http.StatusForbidden, "only host can end activity session")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.activity_participants
		SET left_at = NOW(),
		    role = `+participantRoleOnLeaveExpr+`
		WHERE session_id = $1
		  AND left_at IS NULL
	`, sessionUUID); err != nil {
		h.logger.Error("failed to close activity participants", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to end activity session")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit end transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to end activity session")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
}

// GetSession handles GET /api/v1/activities/{sessionId}
func (h *ActivityHandler) GetSession(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return
	}

	var out ActivitySessionResponse
	if err = h.db.QueryRow(r.Context(), `
		SELECT s.id, s.activity_id, s.channel_id, s.server_id, s.host_user_id,
		       s.previous_host_user_id, s.state, COALESCE(s.embed_url, ''),
		       s.started_at, s.ended_at, s.ended_reason, s.last_heartbeat_at,
		       s.host_transferred_at, s.created_at,
		       COALESCE((
		       	SELECT COUNT(*)
		       	FROM public.activity_participants ap
		       	WHERE ap.session_id = s.id
		       	  AND ap.left_at IS NULL
		       ), 0) AS participant_count
		FROM public.activity_sessions s
		WHERE s.id = $1
		LIMIT 1
	`, sessionUUID).Scan(
		&out.ID, &out.ActivityID, &out.ChannelID, &out.ServerID, &out.HostUserID,
		&out.PreviousHostUserID, &out.State, &out.EmbedURL, &out.StartedAt,
		&out.EndedAt, &out.EndedReason, &out.LastHeartbeatAt, &out.HostTransferredAt,
		&out.CreatedAt, &out.ParticipantCount,
	); err != nil {
		writeError(w, http.StatusNotFound, "session not found")
		return
	}

	writeJSON(w, http.StatusOK, out)
}
