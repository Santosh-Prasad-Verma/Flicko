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

	var sessionID string
	var state string
	var createdAt time.Time
	var embedURL string
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.activity_sessions (activity_id, channel_id, server_id, host_user_id, state, embed_url)
		SELECT $1, $2, $3, $4, 'launching', COALESCE(a.embed_url, '')
		FROM public.activities a
		WHERE a.id = $1
		RETURNING id, state, created_at, embed_url
	`, activityUUID, channelUUID, serverUUID, userUUID).Scan(&sessionID, &state, &createdAt, &embedURL); err != nil {
		h.logger.Error("failed to create activity session", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create activity session")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		INSERT INTO public.activity_participants (session_id, user_id)
		VALUES ($1, $2)
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
		"session_id":  sessionID,
		"state":       state,
		"embed_url":   embedURL,
		"host_user_id": userID,
		"created_at":  createdAt,
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
		INSERT INTO public.activity_participants (session_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT (session_id, user_id) DO NOTHING
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
		DELETE FROM public.activity_participants
		WHERE session_id = $1 AND user_id = $2
	`, sessionUUID, userUUID); err != nil {
		h.logger.Error("failed to remove participant", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to leave activity session")
		return
	}

	// If host left, transfer host to oldest participant; if no participants remain, end session.
	var currentHost uuid.UUID
	hostErr := tx.QueryRow(r.Context(), `
		SELECT host_user_id
		FROM public.activity_sessions
		WHERE id = $1
	`, sessionUUID).Scan(&currentHost)
	if hostErr == nil && currentHost == userUUID {
		var nextHost uuid.UUID
		nextHostErr := tx.QueryRow(r.Context(), `
			SELECT user_id
			FROM public.activity_participants
			WHERE session_id = $1
			ORDER BY created_at ASC
			LIMIT 1
		`, sessionUUID).Scan(&nextHost)

		if nextHostErr == nil {
			if _, err = tx.Exec(r.Context(), `
				UPDATE public.activity_sessions
				SET host_user_id = $2
				WHERE id = $1
			`, sessionUUID, nextHost); err != nil {
				h.logger.Error("failed to transfer activity host", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to leave activity session")
				return
			}
		} else {
			if _, err = tx.Exec(r.Context(), `
				UPDATE public.activity_sessions
				SET state = 'ended', ended_at = NOW()
				WHERE id = $1
			`, sessionUUID); err != nil {
				h.logger.Error("failed to end empty activity session", zap.Error(err))
				writeError(w, http.StatusInternalServerError, "failed to leave activity session")
				return
			}
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
	if req.State != "idle" && req.State != "launching" && req.State != "active" && req.State != "closing" && req.State != "ended" {
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

	updates := "state = $2"
	if req.State == "active" {
		updates += ", started_at = COALESCE(started_at, NOW())"
	}
	if req.State == "ended" {
		updates += ", ended_at = NOW()"
	}

	if _, err = tx.Exec(r.Context(), `
		UPDATE public.activity_sessions
		SET `+updates+`
		WHERE id = $1
	`, sessionUUID, req.State); err != nil {
		h.logger.Error("failed to update session state", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to update activity state")
		return
	}

	patch := req.StatePatch
	if patch == nil {
		patch = map[string]interface{}{}
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
		SELECT session_id, user_id, created_at
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
		if scanErr := rows.Scan(&item.SessionID, &item.UserID, &item.JoinedAt); scanErr != nil {
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
