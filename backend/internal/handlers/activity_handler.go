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

type SyncPlayRequest struct {
	PlayheadMS int64  `json:"playhead_ms"`
	MediaURL   string `json:"media_url"`
}

type SyncPauseRequest struct {
	PlayheadMS int64 `json:"playhead_ms"`
}

type SyncSeekRequest struct {
	PlayheadMS int64 `json:"playhead_ms"`
}

type ActivitySyncStateResponse struct {
	SessionID   string    `json:"session_id"`
	LeaderUserID *string   `json:"leader_user_id,omitempty"`
	PlayheadMS  int64     `json:"playhead_ms"`
	IsPlaying   bool      `json:"is_playing"`
	MediaURL    string    `json:"media_url"`
	UpdatedAt   time.Time `json:"updated_at"`
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

type ValidateCatalogActivityResponse struct {
	ActivityID      string        `json:"activity_id"`
	Valid           bool          `json:"valid"`
	Slug            *string       `json:"slug,omitempty"`
	Provider        *string       `json:"provider,omitempty"`
	Capabilities    []interface{} `json:"capabilities"`
	MobileSupported bool          `json:"mobile_supported"`
	Enabled         bool          `json:"enabled"`
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

// ValidateCatalogActivity handles POST /api/v1/activities/catalog/{id}/validate
func (h *ActivityHandler) ValidateCatalogActivity(w http.ResponseWriter, r *http.Request) {
	activityID := mux.Vars(r)["id"]
	if activityID == "" {
		writeError(w, http.StatusBadRequest, "missing id")
		return
	}
	activityUUID, err := uuid.Parse(activityID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}

	var out ValidateCatalogActivityResponse
	var capabilitiesRaw []byte
	if err = h.db.QueryRow(r.Context(), `
		SELECT
			a.id,
			(COALESCE(a.enabled, true) AND COALESCE(c.enabled, true)) AS valid,
			c.slug,
			c.provider,
			COALESCE(c.capabilities, '[]'::jsonb) AS capabilities,
			COALESCE(c.mobile_supported, true) AS mobile_supported,
			(COALESCE(a.enabled, true) AND COALESCE(c.enabled, true)) AS enabled
		FROM public.activities a
		LEFT JOIN public.activities_catalog c
			ON c.activity_id = a.id
		WHERE a.id = $1
		  AND a.user_id IS NULL
		LIMIT 1
	`, activityUUID).Scan(
		&out.ActivityID,
		&out.Valid,
		&out.Slug,
		&out.Provider,
		&capabilitiesRaw,
		&out.MobileSupported,
		&out.Enabled,
	); err != nil {
		writeError(w, http.StatusNotFound, "activity not found")
		return
	}

	out.Capabilities = make([]interface{}, 0)
	if unmarshalErr := json.Unmarshal(capabilitiesRaw, &out.Capabilities); unmarshalErr != nil {
		h.logger.Error("failed to parse activity capabilities", zap.Error(unmarshalErr))
		writeError(w, http.StatusInternalServerError, "failed to validate activity")
		return
	}

	writeJSON(w, http.StatusOK, out)
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

// SyncPlay handles POST /api/v1/activities/{sessionId}/sync/play
func (h *ActivityHandler) SyncPlay(w http.ResponseWriter, r *http.Request) {
	userUUID, sessionUUID, ok := h.validateSyncActor(w, r)
	if !ok {
		return
	}

	var req SyncPlayRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.PlayheadMS < 0 {
		writeError(w, http.StatusBadRequest, "playhead_ms must be non-negative")
		return
	}

	isPlaying := true
	out, err := h.upsertSyncState(r, sessionUUID, userUUID, &isPlaying, &req.PlayheadMS, &req.MediaURL)
	if err != nil {
		h.logger.Error("failed to apply sync play", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to sync play")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// SyncPause handles POST /api/v1/activities/{sessionId}/sync/pause
func (h *ActivityHandler) SyncPause(w http.ResponseWriter, r *http.Request) {
	userUUID, sessionUUID, ok := h.validateSyncActor(w, r)
	if !ok {
		return
	}

	var req SyncPauseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.PlayheadMS < 0 {
		writeError(w, http.StatusBadRequest, "playhead_ms must be non-negative")
		return
	}

	isPlaying := false
	out, err := h.upsertSyncState(r, sessionUUID, userUUID, &isPlaying, &req.PlayheadMS, nil)
	if err != nil {
		h.logger.Error("failed to apply sync pause", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to sync pause")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// SyncSeek handles POST /api/v1/activities/{sessionId}/sync/seek
func (h *ActivityHandler) SyncSeek(w http.ResponseWriter, r *http.Request) {
	userUUID, sessionUUID, ok := h.validateSyncActor(w, r)
	if !ok {
		return
	}

	var req SyncSeekRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.PlayheadMS < 0 {
		writeError(w, http.StatusBadRequest, "playhead_ms must be non-negative")
		return
	}

	out, err := h.upsertSyncState(r, sessionUUID, userUUID, nil, &req.PlayheadMS, nil)
	if err != nil {
		h.logger.Error("failed to apply sync seek", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to sync seek")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// GetUserActiveActivity handles GET /api/v1/users/{id}/active-activity
func (h *ActivityHandler) GetUserActiveActivity(w http.ResponseWriter, r *http.Request) {
	userID := mux.Vars(r)["id"]
	if userID == "" {
		writeError(w, http.StatusBadRequest, "missing user id")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var sessionID string
	err = h.db.QueryRow(r.Context(), `
		SELECT s.id
		FROM public.activity_sessions s
		JOIN public.activity_participants p ON p.session_id = s.id
		WHERE p.user_id = $1
		  AND p.left_at IS NULL
		  AND s.state IN ('launching', 'active')
		ORDER BY s.created_at DESC
		LIMIT 1
	`, userUUID).Scan(&sessionID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]interface{}{"active_activity": nil})
		return
	}

	h.writeSessionByID(w, r, sessionID)
}

// GetChannelActiveActivity handles GET /api/v1/channels/{id}/active-activity
func (h *ActivityHandler) GetChannelActiveActivity(w http.ResponseWriter, r *http.Request) {
	channelID := mux.Vars(r)["id"]
	if channelID == "" {
		writeError(w, http.StatusBadRequest, "missing channel id")
		return
	}
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid channel id")
		return
	}

	var sessionID string
	err = h.db.QueryRow(r.Context(), `
		SELECT s.id
		FROM public.activity_sessions s
		WHERE s.channel_id = $1
		  AND s.state IN ('launching', 'active')
		ORDER BY s.created_at DESC
		LIMIT 1
	`, channelUUID).Scan(&sessionID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]interface{}{"active_activity": nil})
		return
	}

	h.writeSessionByID(w, r, sessionID)
}

func (h *ActivityHandler) validateSyncActor(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, bool) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return uuid.Nil, uuid.Nil, false
	}
	sessionID := mux.Vars(r)["sessionId"]
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "missing sessionId")
		return uuid.Nil, uuid.Nil, false
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return uuid.Nil, uuid.Nil, false
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid sessionId")
		return uuid.Nil, uuid.Nil, false
	}

	var isParticipant bool
	if err = h.db.QueryRow(r.Context(), `
		SELECT EXISTS(
			SELECT 1
			FROM public.activity_participants
			WHERE session_id = $1
			  AND user_id = $2
			  AND left_at IS NULL
		)
	`, sessionUUID, userUUID).Scan(&isParticipant); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to validate participant")
		return uuid.Nil, uuid.Nil, false
	}
	if !isParticipant {
		writeError(w, http.StatusForbidden, "participant membership required")
		return uuid.Nil, uuid.Nil, false
	}

	return userUUID, sessionUUID, true
}

func (h *ActivityHandler) upsertSyncState(
	r *http.Request,
	sessionUUID uuid.UUID,
	userUUID uuid.UUID,
	isPlaying *bool,
	playheadMS *int64,
	mediaURL *string,
) (*ActivitySyncStateResponse, error) {
	var out ActivitySyncStateResponse
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO public.activity_sync_state (session_id, leader_user_id, playhead_ms, is_playing, media_url, updated_at)
		VALUES (
			$1,
			$2,
			COALESCE($3, 0),
			COALESCE($4, false),
			COALESCE($5, ''),
			NOW()
		)
		ON CONFLICT (session_id)
		DO UPDATE SET
			leader_user_id = $2,
			playhead_ms = COALESCE($3, activity_sync_state.playhead_ms),
			is_playing = COALESCE($4, activity_sync_state.is_playing),
			media_url = COALESCE(NULLIF($5, ''), activity_sync_state.media_url),
			updated_at = NOW()
		RETURNING session_id, leader_user_id, playhead_ms, is_playing, media_url, updated_at
	`, sessionUUID, userUUID, playheadMS, isPlaying, mediaURL).Scan(
		&out.SessionID, &out.LeaderUserID, &out.PlayheadMS, &out.IsPlaying, &out.MediaURL, &out.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &out, nil
}

func (h *ActivityHandler) writeSessionByID(w http.ResponseWriter, r *http.Request, sessionID string) {
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		writeError(w, http.StatusNotFound, "session not found")
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

	writeJSON(w, http.StatusOK, map[string]interface{}{"active_activity": out})
}
