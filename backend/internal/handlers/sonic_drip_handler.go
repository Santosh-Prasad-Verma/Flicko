package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/music"
)

// SonicDripHandler handles all Sonic Drip / Spotify integration endpoints.
//
// Endpoints:
//   POST   /music/session          — save Spotify session cookies (from WebView)
//   DELETE /music/session          — disconnect Spotify
//   GET    /music/session          — get session info (no cookies returned)
//   GET    /music/search           — search Spotify catalog
//   POST   /music/player/play      — play a track (idempotent)
//   POST   /music/player/pause     — pause playback
//   POST   /music/player/resume    — resume playback
//   POST   /music/player/skip-next — skip to next track
//   POST   /music/player/seek      — seek to position
//   POST   /music/player/volume    — set volume
//   GET    /music/player/state     — get current playback state
//   GET    /music/player/devices   — list available devices
type SonicDripHandler struct {
	sessions *music.SessionStore
	spotapi  *music.SpotAPIClient
	redis    redis.Cmdable
	logger   *zap.Logger
}

// NewSonicDripHandler creates a SonicDripHandler.
// rdb accepts redis.Cmdable (use cache.GetRedisClient() from the cache layer).
func NewSonicDripHandler(
	db *pgxpool.Pool,
	rdb redis.Cmdable,
	encKey []byte,
	spotAPIURL string,
	logger *zap.Logger,
) *SonicDripHandler {
	enc, err := music.NewEncryptionService(encKey)
	if err != nil {
		logger.Fatal("failed to create music encryption service", zap.Error(err))
	}

	store := music.NewSessionStore(db, rdb, enc, logger)

	var client *music.SpotAPIClient
	if spotAPIURL != "" {
		client = music.NewSpotAPIClient(spotAPIURL)
	}

	return &SonicDripHandler{
		sessions: store,
		spotapi:  client,
		redis:    rdb,
		logger:   logger.Named("handler.sonic_drip"),
	}
}

// RegisterRoutes registers all Sonic Drip routes on the given subrouter.
// The subrouter must already have auth middleware applied.
func (h *SonicDripHandler) RegisterRoutes(r interface {
	HandleFunc(string, func(http.ResponseWriter, *http.Request)) interface{ Methods(...string) interface{} }
}) {
	// Using gorilla/mux subrouter — routes are registered in main.go
}

// ── Session ───────────────────────────────────────────────────────────────────

// SaveSession stores Spotify session cookies captured from the WebView.
// Body: { "cookies": {"sp_dc": "...", ...}, "display_name": "...", "product": "free|premium" }
func (h *SonicDripHandler) SaveSession(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req struct {
		Cookies     music.SessionCookies `json:"cookies"`
		DisplayName string               `json:"display_name"`
		Product     string               `json:"product"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(req.Cookies) == 0 {
		writeError(w, http.StatusBadRequest, "cookies are required")
		return
	}

	if req.Product == "" {
		req.Product = "free"
	}

	if err := h.sessions.Save(r.Context(), userID, req.Cookies, req.DisplayName, req.Product); err != nil {
		h.logger.Error("failed to save spotify session", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to save session")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "connected"})
}

// GetSession returns session metadata (never returns cookies).
func (h *SonicDripHandler) GetSession(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	displayName, product, status, err := h.sessions.GetInfo(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "disconnected"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":       status,
		"display_name": displayName,
		"product":      product,
	})
}

// DeleteSession disconnects Spotify for the user.
func (h *SonicDripHandler) DeleteSession(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	h.sessions.Delete(r.Context(), userID)
	writeJSON(w, http.StatusOK, map[string]string{"status": "disconnected"})
}

// ── Search ────────────────────────────────────────────────────────────────────

// Search searches the Spotify catalog.
// Query params: q (required), limit (default 25)
func (h *SonicDripHandler) Search(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "q parameter is required")
		return
	}

	limit := 25
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	results, err := h.spotapi.Search(r.Context(), cookies, query, limit)
	if err != nil {
		h.logger.Error("search failed", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusBadGateway, "search failed")
		return
	}

	writeJSON(w, http.StatusOK, results)
}

// ── Player ────────────────────────────────────────────────────────────────────

// Play plays a track. Uses idempotency key to prevent duplicate plays.
// Body: { "track_id": "...", "idempotency_key": "uuid", "device_id": "..." }
func (h *SonicDripHandler) Play(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req struct {
		TrackID        string `json:"track_id"`
		IdempotencyKey string `json:"idempotency_key"`
		DeviceID       string `json:"device_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.TrackID == "" {
		writeError(w, http.StatusBadRequest, "track_id is required")
		return
	}
	if req.IdempotencyKey == "" {
		req.IdempotencyKey = uuid.New().String()
	}

	// Idempotency check — 5-minute dedup window
	dedupeKey := "idempotent:play:" + userID + ":" + req.IdempotencyKey
	set, err := h.redis.SetNX(r.Context(), dedupeKey, "1", 5*time.Minute).Result()
	if err == nil && !set {
		// Duplicate request — return success without replaying
		writeJSON(w, http.StatusOK, map[string]string{"status": "already_processed"})
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	if err := h.spotapi.Play(r.Context(), cookies, req.TrackID, req.DeviceID); err != nil {
		h.redis.Del(r.Context(), dedupeKey) // allow retry on error
		h.logger.Error("play failed", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusBadGateway, "playback failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "playing", "track_id": req.TrackID})
}

// Pause pauses playback.
func (h *SonicDripHandler) Pause(w http.ResponseWriter, r *http.Request) {
	h.simplePlayerAction(w, r, func(cookies music.SessionCookies) error {
		return h.spotapi.Pause(r.Context(), cookies)
	})
}

// Resume resumes playback.
func (h *SonicDripHandler) Resume(w http.ResponseWriter, r *http.Request) {
	h.simplePlayerAction(w, r, func(cookies music.SessionCookies) error {
		return h.spotapi.Resume(r.Context(), cookies)
	})
}

// SkipNext skips to the next track.
func (h *SonicDripHandler) SkipNext(w http.ResponseWriter, r *http.Request) {
	h.simplePlayerAction(w, r, func(cookies music.SessionCookies) error {
		return h.spotapi.SkipNext(r.Context(), cookies)
	})
}

// Seek seeks to a position in the current track.
// Body: { "position_ms": 45000 }
func (h *SonicDripHandler) Seek(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req struct {
		PositionMs int `json:"position_ms"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	if err := h.spotapi.Seek(r.Context(), cookies, req.PositionMs); err != nil {
		writeError(w, http.StatusBadGateway, "seek failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// SetVolume sets playback volume.
// Body: { "volume": 0.75 }
func (h *SonicDripHandler) SetVolume(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req struct {
		Volume float64 `json:"volume"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Volume < 0 || req.Volume > 1 {
		writeError(w, http.StatusBadRequest, "volume must be between 0.0 and 1.0")
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	if err := h.spotapi.SetVolume(r.Context(), cookies, req.Volume); err != nil {
		writeError(w, http.StatusBadGateway, "volume change failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// GetState returns the current playback state.
func (h *SonicDripHandler) GetState(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	state, err := h.spotapi.GetState(r.Context(), cookies)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to get playback state")
		return
	}

	writeJSON(w, http.StatusOK, state)
}

// GetDevices returns available playback devices.
func (h *SonicDripHandler) GetDevices(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	devices, err := h.spotapi.GetDevices(r.Context(), cookies)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to get devices")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"devices": devices})
}

// ── Internal helpers ──────────────────────────────────────────────────────────

func (h *SonicDripHandler) simplePlayerAction(
	w http.ResponseWriter,
	r *http.Request,
	action func(music.SessionCookies) error,
) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	if h.spotapi == nil {
		writeError(w, http.StatusServiceUnavailable, "music service not configured")
		return
	}

	cookies, err := h.sessions.Load(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "spotify not connected")
		return
	}

	if err := action(cookies); err != nil {
		h.logger.Error("player action failed", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusBadGateway, "player action failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
