package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type MusicHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewMusicHandler(db *pgxpool.Pool, logger *zap.Logger) *MusicHandler {
	return &MusicHandler{
		db:     db,
		logger: logger.Named("handler.music"),
	}
}

type MusicStateResponse struct {
	Queue    []QueueItem   `json:"queue"`
	Settings MusicSettings `json:"settings"`
}

type QueueItem struct {
	ID              string `json:"id"`
	Title           string `json:"title"`
	URL             string `json:"url"`
	DurationSeconds int    `json:"duration_seconds"`
	RequestedBy     string `json:"requested_by"`
	Position        int    `json:"position"`
}

type MusicSettings struct {
	Enabled             bool    `json:"enabled"`
	DefaultVolume       int     `json:"default_volume"`
	RepeatMode          string  `json:"repeat_mode"`
	NowPlayingChannelID *string `json:"now_playing_channel_id"`
}

// GetMusicState returns the queue and settings for a server.
// Requires the requester to be a member of the server (IDOR fix).
func (h *MusicHandler) GetMusicState(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]

	if serverID == "" {
		http.Error(w, "missing serverId", http.StatusBadRequest)
		return
	}

	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	// Membership check — prevents IDOR enumeration of any server's queue.
	var isMember bool
	if err := h.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1 AND user_id = $2)`,
		serverID, userID).Scan(&isMember); err != nil {
		h.logger.Error("failed to verify music server membership", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify membership")
		return
	}
	if !isMember {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}

	// Fetch queue
	rows, err := h.db.Query(ctx,
		`SELECT id, title, url, duration_seconds, requested_by, position 
		 FROM music_queues WHERE server_id = $1 ORDER BY position`, serverID)
	if err != nil {
		h.logger.Error("failed to query music queue", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "internal service error")
		return
	}
	defer rows.Close()

	queue := make([]QueueItem, 0)
	for rows.Next() {
		var item QueueItem
		if err := rows.Scan(&item.ID, &item.Title, &item.URL, &item.DurationSeconds, &item.RequestedBy, &item.Position); err != nil {
			h.logger.Error("failed to scan queue item", zap.Error(err))
			continue
		}
		queue = append(queue, item)
	}

	// Fetch settings — distinguish "no row" (use defaults) from real errors.
	var settings MusicSettings
	err = h.db.QueryRow(ctx,
		`SELECT enabled, default_volume, repeat_mode, now_playing_channel_id 
		 FROM music_settings WHERE server_id = $1`, serverID).
		Scan(&settings.Enabled, &settings.DefaultVolume, &settings.RepeatMode, &settings.NowPlayingChannelID)

	switch {
	case errors.Is(err, pgx.ErrNoRows):
		settings = MusicSettings{
			Enabled:       true,
			DefaultVolume: 50,
			RepeatMode:    "off",
		}
	case err != nil:
		h.logger.Error("failed to query music settings", zap.Error(err), zap.String("server_id", serverID))
		writeError(w, http.StatusInternalServerError, "failed to load music settings")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(MusicStateResponse{
		Queue:    queue,
		Settings: settings,
	}); err != nil {
		h.logger.Error("failed to encode music state response", zap.Error(err))
	}
}
