package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type ChannelBackgroundHandler struct {
	db     *pgxpool.Pool
	svc    services.ChannelBackgroundService
	logger *zap.Logger
}

func NewChannelBackgroundHandler(db *pgxpool.Pool, svc services.ChannelBackgroundService, logger *zap.Logger) *ChannelBackgroundHandler {
	return &ChannelBackgroundHandler{
		db:     db,
		svc:    svc,
		logger: logger.Named("handler.channel_background"),
	}
}

func (h *ChannelBackgroundHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/channels/{channelId}/background", h.UploadBackground).Methods(http.MethodPost)
	r.HandleFunc("/channels/{channelId}/background", h.GetBackground).Methods(http.MethodGet)
	r.HandleFunc("/channels/{channelId}/background", h.DeleteBackground).Methods(http.MethodDelete)
	r.HandleFunc("/channels/{channelId}/background/override", h.SetOverride).Methods(http.MethodPut)
	r.HandleFunc("/channels/{channelId}/background/override", h.GetOverride).Methods(http.MethodGet)
}

func (h *ChannelBackgroundHandler) UploadBackground(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		http.Error(w, "invalid user id", http.StatusBadRequest)
		return
	}
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		http.Error(w, "invalid channel id", http.StatusBadRequest)
		return
	}

	// Permission check: MUST have MANAGE_CHANNEL
	var hasBgPerm bool
	err = h.db.QueryRow(ctx, "SELECT public.has_permission($1, $2, 'MANAGE_CHANNEL')", userUUID, channelUUID).Scan(&hasBgPerm)
	if err != nil || !hasBgPerm {
		http.Error(w, "You do not have permission to manage this channel's backgrounds", http.StatusForbidden)
		return
	}

	// Fetch server id
	var serverID string
	err = h.db.QueryRow(ctx, "SELECT server_id FROM channels WHERE id = $1", channelID).Scan(&serverID)
	if err != nil {
		http.Error(w, "channel not found", http.StatusNotFound)
		return
	}

	// Parse file from request body
	err = r.ParseMultipartForm(10 * 1024 * 1024) // 10MB limit
	if err != nil {
		http.Error(w, "failed to parse multipart form", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "missing background image file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	bg, err := h.svc.UploadBackground(ctx, channelID, serverID, userID, file, header)
	if err != nil {
		h.logger.Error("failed to upload channel background", zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, bg)
}

func (h *ChannelBackgroundHandler) GetBackground(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]

	bg, err := h.svc.GetBackground(ctx, channelID)
	if err != nil {
		if err.Error() == "not found" {
			http.Error(w, "background not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, bg)
}

func (h *ChannelBackgroundHandler) DeleteBackground(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		http.Error(w, "invalid user id", http.StatusBadRequest)
		return
	}
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		http.Error(w, "invalid channel id", http.StatusBadRequest)
		return
	}

	var hasBgPerm bool
	err = h.db.QueryRow(ctx, "SELECT public.has_permission($1, $2, 'MANAGE_CHANNEL')", userUUID, channelUUID).Scan(&hasBgPerm)
	if err != nil || !hasBgPerm {
		http.Error(w, "You do not have permission to delete this channel's backgrounds", http.StatusForbidden)
		return
	}

	err = h.svc.DeleteBackground(ctx, channelID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type setOverridePayload struct {
	Opacity float32 `json:"opacity"`
	Enabled bool    `json:"enabled"`
}

func (h *ChannelBackgroundHandler) SetOverride(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var payload setOverridePayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	err := h.svc.SetOverride(ctx, userID, channelID, payload.Opacity, payload.Enabled)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *ChannelBackgroundHandler) GetOverride(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]
	userID := getUserID(r)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	override, err := h.svc.GetOverride(ctx, userID, channelID)
	if err != nil {
		if err.Error() == "not found" {
			// Return default override values
			writeJSON(w, http.StatusOK, map[string]any{
				"user_id":    userID,
				"channel_id": channelID,
				"opacity":    0.3,
				"enabled":    true,
			})
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, override)
}

func (h *ChannelBackgroundHandler) RequireChannelPermission(permission string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			vars := mux.Vars(r)
			channelID := vars["channelId"]
			userID := getUserID(r)
			if userID == "" {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			userUUID, err := uuid.Parse(userID)
			if err != nil {
				http.Error(w, "invalid user id", http.StatusBadRequest)
				return
			}
			channelUUID, err := uuid.Parse(channelID)
			if err != nil {
				http.Error(w, "invalid channel id", http.StatusBadRequest)
				return
			}

			var hasPerm bool
			err = h.db.QueryRow(ctx, "SELECT public.has_permission($1, $2, $3)", userUUID, channelUUID, permission).Scan(&hasPerm)
			if err != nil || !hasPerm {
				http.Error(w, fmt.Sprintf("Missing permission: %s", permission), http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
