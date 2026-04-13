package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
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

func (h *MusicHandler) GetMusicState(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]

	if serverID == "" {
		http.Error(w, "missing serverId", http.StatusBadRequest)
		return
	}

	// Fetch queue
	rows, err := h.db.Query(ctx,
		`SELECT id, title, url, duration_seconds, requested_by, position 
		 FROM music_queues WHERE server_id = $1 ORDER BY position`, serverID)
	if err != nil {
		h.logger.Error("failed to query music queue", zap.Error(err))
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var queue []QueueItem
	for rows.Next() {
		var item QueueItem
		if err := rows.Scan(&item.ID, &item.Title, &item.URL, &item.DurationSeconds, &item.RequestedBy, &item.Position); err != nil {
			h.logger.Error("failed to scan queue item", zap.Error(err))
			continue
		}
		queue = append(queue, item)
	}

	// Fetch settings
	var settings MusicSettings
	err = h.db.QueryRow(ctx,
		`SELECT enabled, default_volume, repeat_mode, now_playing_channel_id 
		 FROM music_settings WHERE server_id = $1`, serverID).
		Scan(&settings.Enabled, &settings.DefaultVolume, &settings.RepeatMode, &settings.NowPlayingChannelID)
	
	if err != nil {
		// If no settings found, return defaults
		settings = MusicSettings{
			Enabled:       true,
			DefaultVolume: 50,
			RepeatMode:    "off",
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(MusicStateResponse{
		Queue:    queue,
		Settings: settings,
	})
}
