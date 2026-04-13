package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

// VideoHandler manages all video/streaming HTTP endpoints.
type VideoHandler struct {
	streamSvc services.StreamService
	voiceSvc  services.VoiceService
	permSvc   services.PermissionService
	logger    *zap.Logger
}

// NewVideoHandler creates a VideoHandler wired to stream and voice services.
func NewVideoHandler(streamSvc services.StreamService, voiceSvc services.VoiceService, permSvc services.PermissionService, logger *zap.Logger) *VideoHandler {
	return &VideoHandler{
		streamSvc: streamSvc,
		voiceSvc:  voiceSvc,
		permSvc:   permSvc,
		logger:    logger,
	}
}

// RegisterRoutes binds video/streaming endpoints to the given router.
func (h *VideoHandler) RegisterRoutes(r *mux.Router) {
	// Stream (Go Live) endpoints
	r.HandleFunc("/api/v1/streams", h.CreateStream).Methods("POST")
	r.HandleFunc("/api/v1/channels/{channelId}/streams", h.GetActiveStreams).Methods("GET")
	r.HandleFunc("/api/v1/streams/{streamId}/start", h.StartStream).Methods("POST")
	r.HandleFunc("/api/v1/streams/{streamId}/end", h.EndStream).Methods("POST")
	r.HandleFunc("/api/v1/streams/{streamId}/viewers", h.GetStreamViewers).Methods("GET")
	r.HandleFunc("/api/v1/streams/{streamId}/watch", h.WatchStream).Methods("POST")
	r.HandleFunc("/api/v1/streams/{streamId}/leave", h.LeaveStream).Methods("POST")

	// Voice state video updates
	r.HandleFunc("/api/v1/voice-states/video", h.UpdateVideoState).Methods("PATCH")
}

// ── Create Stream (Go Live) ──

type createStreamRequest struct {
	ChannelID  string `json:"channel_id"`
	ServerID   string `json:"server_id"`
	Title      string `json:"title"`
	StreamType string `json:"stream_type"`
	MaxQuality string `json:"max_quality"`
}

func (h *VideoHandler) CreateStream(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req createStreamRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	stream, err := h.streamSvc.CreateStream(r.Context(), services.CreateStreamInput{
		UserID:     userID,
		ChannelID:  req.ChannelID,
		ServerID:   req.ServerID,
		Title:      req.Title,
		StreamType: req.StreamType,
		MaxQuality: req.MaxQuality,
	})
	if err != nil {
		switch err {
		case services.ErrStreamAlreadyActive:
			writeError(w, http.StatusConflict, err.Error())
		default:
			h.logger.Error("CreateStream failed", zap.Error(err))
			writeError(w, http.StatusInternalServerError, err.Error())
		}
		return
	}

	writeJSON(w, http.StatusCreated, stream)
}

// ── Get Active Streams ──

func (h *VideoHandler) GetActiveStreams(w http.ResponseWriter, r *http.Request) {
	channelID := mux.Vars(r)["channelId"]
	if channelID == "" {
		writeError(w, http.StatusBadRequest, "missing channelId")
		return
	}

	streams, err := h.streamSvc.GetActiveStreams(r.Context(), channelID)
	if err != nil {
		h.logger.Error("GetActiveStreams failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, streams)
}

// ── Start Stream ──

func (h *VideoHandler) StartStream(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	streamID := mux.Vars(r)["streamId"]
	if streamID == "" {
		writeError(w, http.StatusBadRequest, "missing streamId")
		return
	}

	if err := h.streamSvc.StartStream(r.Context(), streamID, userID); err != nil {
		h.logger.Error("StartStream failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── End Stream ──

func (h *VideoHandler) EndStream(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	streamID := mux.Vars(r)["streamId"]
	if streamID == "" {
		writeError(w, http.StatusBadRequest, "missing streamId")
		return
	}

	// The ownership and admin check are now handled intrinsically by streamSvc.EndStream.
	if err := h.streamSvc.EndStream(r.Context(), streamID, userID); err != nil {
		h.logger.Error("EndStream failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Get Stream Viewers ──

func (h *VideoHandler) GetStreamViewers(w http.ResponseWriter, r *http.Request) {
	streamID := mux.Vars(r)["streamId"]
	if streamID == "" {
		writeError(w, http.StatusBadRequest, "missing streamId")
		return
	}

	viewers, err := h.streamSvc.GetStreamViewers(r.Context(), streamID)
	if err != nil {
		h.logger.Error("GetStreamViewers failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, viewers)
}

// ── Watch Stream ──

func (h *VideoHandler) WatchStream(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	streamID := mux.Vars(r)["streamId"]
	if streamID == "" {
		writeError(w, http.StatusBadRequest, "missing streamId")
		return
	}

	if err := h.streamSvc.JoinStreamAsViewer(r.Context(), streamID, userID); err != nil {
		h.logger.Error("WatchStream failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Leave Stream ──

func (h *VideoHandler) LeaveStream(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	streamID := mux.Vars(r)["streamId"]
	if streamID == "" {
		writeError(w, http.StatusBadRequest, "missing streamId")
		return
	}

	if err := h.streamSvc.LeaveStream(r.Context(), streamID, userID); err != nil {
		h.logger.Error("LeaveStream failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Update Video State ──

type updateVideoStateRequest struct {
	VideoEnabled  *bool   `json:"video_enabled"`
	ScreenSharing *bool   `json:"screen_sharing"`
	VideoQuality  *string `json:"video_quality"`
	VideoFPS      *int    `json:"video_fps"`
	CameraFacing  *string `json:"camera_facing"`
	SuppressVideo *bool   `json:"suppress_video"`
}

func (h *VideoHandler) UpdateVideoState(w http.ResponseWriter, r *http.Request) {
	userID := getVideoUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req updateVideoStateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// Map video-specific toggles onto the existing VoiceService UpdateVoiceState.
	// isStreaming maps to screen_sharing, isVideo maps to video_enabled.
	_, err := h.voiceSvc.UpdateVoiceState(r.Context(), userID, nil, nil, req.ScreenSharing, req.VideoEnabled)
	if err != nil {
		h.logger.Error("UpdateVideoState failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Helpers ──

func getVideoUserID(r *http.Request) string {
	if uid, ok := r.Context().Value(middleware.GetUserIDKey()).(string); ok {
		return uid
	}
	return ""
}
