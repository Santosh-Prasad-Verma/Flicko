package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	storage_go "github.com/supabase-community/storage-go"
	"go.uber.org/zap"
)

// maxSoundUploadBytes caps a single soundboard upload. Shared by the validation
// middleware and the handler so the two cannot drift apart.
const maxSoundUploadBytes = 5 * 1024 * 1024 // 5MB

type SoundboardHandler struct {
	db        *pgxpool.Pool
	repo      repo.SoundboardRepo
	publisher centrifugo.Publisher
	storage   *storage_go.Client
	cfg       *config.Config
	logger    *zap.Logger
}

func NewSoundboardHandler(
	db *pgxpool.Pool,
	r repo.SoundboardRepo,
	pub centrifugo.Publisher,
	cfg *config.Config,
	logger *zap.Logger,
) *SoundboardHandler {
	storageUrl := fmt.Sprintf("%s/storage/v1", cfg.SupabaseURL)
	storageClient := storage_go.NewClient(storageUrl, cfg.SupabaseServiceKey, nil)

	return &SoundboardHandler{
		db:        db,
		repo:      r,
		publisher: pub,
		storage:   storageClient,
		cfg:       cfg,
		logger:    logger.Named("handler.soundboard"),
	}
}

func (h *SoundboardHandler) RegisterRoutes(r *mux.Router) {
	// Sound uploads land in a public bucket, so file contents — not the
	// client-supplied extension — must decide whether the upload is accepted.
	audioValidation := middleware.AudioUploadValidationMiddleware(maxSoundUploadBytes, h.logger)

	r.HandleFunc("/servers/{serverId}/soundboard", h.GetSounds).Methods(http.MethodGet)
	r.Handle("/servers/{serverId}/soundboard",
		audioValidation(http.HandlerFunc(h.UploadSound))).Methods(http.MethodPost)
	r.HandleFunc("/servers/{serverId}/soundboard/play", h.PlaySound).Methods(http.MethodPost)
	r.HandleFunc("/soundboard/favorites", h.GetFavorites).Methods(http.MethodGet)
	r.HandleFunc("/soundboard/sounds/{soundId}/favorite", h.FavoriteSound).Methods(http.MethodPost)
	r.HandleFunc("/soundboard/sounds/{soundId}/favorite", h.UnfavoriteSound).Methods(http.MethodDelete)
	r.HandleFunc("/soundboard/sounds/{soundId}", h.DeleteSound).Methods(http.MethodDelete)
}

func (h *SoundboardHandler) GetSounds(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]

	sounds, err := h.repo.GetSoundsByServerID(ctx, serverID)
	if err != nil {
		h.logger.Error("failed to get server sounds", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, sounds)
}

func (h *SoundboardHandler) UploadSound(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	err := r.ParseMultipartForm(maxSoundUploadBytes)
	if err != nil {
		http.Error(w, "failed to parse multipart form", http.StatusBadRequest)
		return
	}

	name := r.FormValue("name")
	emoji := r.FormValue("emoji")
	if name == "" {
		http.Error(w, "missing sound name", http.StatusBadRequest)
		return
	}
	if emoji == "" {
		emoji = "🔊"
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "missing sound file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Reduce the client-supplied name to a single safe path segment before it
	// reaches the storage key, then validate the extension on that safe name.
	filename := services.SanitizeUploadFilename(header.Filename)
	if filename == "" {
		http.Error(w, "invalid filename", http.StatusBadRequest)
		return
	}

	// Check file extension. This is a convenience filter only — the authoritative
	// check is the magic-byte validation in the upload middleware, since an
	// extension is attacker-controlled.
	if !strings.HasSuffix(strings.ToLower(filename), ".mp3") &&
		!strings.HasSuffix(strings.ToLower(filename), ".wav") &&
		!strings.HasSuffix(strings.ToLower(filename), ".ogg") {
		http.Error(w, "invalid file format: only mp3, wav, or ogg supported", http.StatusBadRequest)
		return
	}

	// Create unique file path
	fileID := uuid.NewString()
	filePath := fmt.Sprintf("%s/%s_%s", serverID, fileID, filename)

	// Upload to Supabase Storage
	_, err = h.storage.UploadFile("soundboard-sounds", filePath, file)
	if err != nil {
		h.logger.Error("failed to upload sound to storage", zap.Error(err))
		http.Error(w, "failed to upload sound file", http.StatusInternalServerError)
		return
	}

	soundURL := fmt.Sprintf("%s/storage/v1/object/public/soundboard-sounds/%s", h.cfg.SupabaseURL, filePath)

	sound := &models.SoundboardSound{
		ID:         fileID,
		ServerID:   serverID,
		Name:       name,
		Emoji:      emoji,
		SoundURL:   soundURL,
		Duration:   3.0, // Default fallback duration
		UploadedBy: userID,
		PlayCount:  0,
	}

	err = h.repo.InsertSound(ctx, sound)
	if err != nil {
		h.logger.Error("failed to insert sound metadata", zap.Error(err))
		http.Error(w, "failed to save sound metadata", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, sound)
}

type playSoundPayload struct {
	SoundID   string `json:"sound_id"`
	ChannelID string `json:"channel_id"`
}

func (h *SoundboardHandler) PlaySound(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var payload playSoundPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	sound, err := h.repo.GetSoundByID(ctx, payload.SoundID)
	if err != nil {
		if err.Error() == "not found" {
			http.Error(w, "sound not found", http.StatusNotFound)
			return
		}
		h.logger.Error("failed to get sound details", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Verify sound belongs to server
	if sound.ServerID != serverID {
		http.Error(w, "sound does not belong to this server", http.StatusBadRequest)
		return
	}

	// Increment play count
	err = h.repo.IncrementPlayCount(ctx, payload.SoundID)
	if err != nil {
		h.logger.Warn("failed to increment play count", zap.Error(err))
	}

	// Trigger Centrifugo real-time event
	realtimeChannel := fmt.Sprintf("voice:%s", payload.ChannelID)
	playEvent := map[string]any{
		"event":      "sound_played",
		"sound_id":   sound.ID,
		"sound_url":  sound.SoundURL,
		"name":       sound.Name,
		"emoji":      sound.Emoji,
		"user_id":    userID,
		"channel_id": payload.ChannelID,
	}

	err = h.publisher.Publish(ctx, realtimeChannel, playEvent)
	if err != nil {
		h.logger.Error("failed to publish real-time play event", zap.Error(err))
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *SoundboardHandler) GetFavorites(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	favorites, err := h.repo.GetFavoritesByUserID(ctx, userID)
	if err != nil {
		h.logger.Error("failed to get user favorites", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, favorites)
}

func (h *SoundboardHandler) FavoriteSound(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	soundID := vars["soundId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	err := h.repo.InsertFavorite(ctx, userID, soundID)
	if err != nil {
		h.logger.Error("failed to favorite sound", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *SoundboardHandler) UnfavoriteSound(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	soundID := vars["soundId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	err := h.repo.DeleteFavorite(ctx, userID, soundID)
	if err != nil {
		h.logger.Error("failed to unfavorite sound", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *SoundboardHandler) DeleteSound(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	soundID := vars["soundId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	sound, err := h.repo.GetSoundByID(ctx, soundID)
	if err != nil {
		if err.Error() == "not found" {
			http.Error(w, "sound not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Verify ownership or admin permission
	if sound.UploadedBy != userID {
		// In a real app we'd check permission public.has_permission(userID, sound.ServerID, 'MANAGE_GUILD')
		// For simplicity, verify they own the sound
		http.Error(w, "forbidden: you did not upload this sound", http.StatusForbidden)
		return
	}

	err = h.repo.DeleteSound(ctx, soundID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Clean up from storage best effort
	// SoundURL format: .../soundboard-sounds/[serverId]/[fileID]_[filename]
	parts := strings.Split(sound.SoundURL, "soundboard-sounds/")
	if len(parts) > 1 {
		_, _ = h.storage.RemoveFile("soundboard-sounds", []string{parts[1]})
	}

	w.WriteHeader(http.StatusNoContent)
}
