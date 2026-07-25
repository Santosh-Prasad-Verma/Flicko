package musicparty

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

// Handler implements HTTP handlers for Music Party endpoints.
type Handler struct {
	svc    Service
	logger *zap.Logger
}

// NewHandler creates a new Music Party HTTP handler.
func NewHandler(svc Service, logger *zap.Logger) *Handler {
	return &Handler{
		svc:    svc,
		logger: logger.Named("handler.musicparty"),
	}
}

// ── Helpers ────────────────────────────────────────────────────

func (h *Handler) getUserID(r *http.Request) string {
	if uid, ok := r.Context().Value(middleware.GetUserIDKey()).(string); ok {
		return uid
	}
	return ""
}

func (h *Handler) writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func (h *Handler) writeError(w http.ResponseWriter, code int, msg string) {
	h.writeJSON(w, code, map[string]string{"error": msg})
}

func (h *Handler) parseUserID(r *http.Request) (uuid.UUID, bool) {
	uidStr := h.getUserID(r)
	if uidStr == "" {
		return uuid.Nil, false
	}
	uid, err := uuid.Parse(uidStr)
	if err != nil {
		return uuid.Nil, false
	}
	return uid, true
}

// ── Session Endpoints ──────────────────────────────────────────

// HandleCreateSession — POST /sessions
func (h *Handler) HandleCreateSession(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req CreateSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.RoomID == "" {
		h.writeError(w, http.StatusBadRequest, "room_id is required")
		return
	}

	session, err := h.svc.CreateSession(r.Context(), &req, userID)
	if err != nil {
		h.logger.Error("failed to create session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusCreated, session)
}

// HandleGetSession — GET /sessions/{id}
func (h *Handler) HandleGetSession(w http.ResponseWriter, r *http.Request) {
	_, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	session, err := h.svc.GetSession(r.Context(), sessionID)
	if err != nil {
		h.writeError(w, http.StatusNotFound, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

// HandleUpdateSession — PATCH /sessions/{id}
func (h *Handler) HandleUpdateSession(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req UpdateSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	session, err := h.svc.UpdateSession(r.Context(), sessionID, &req, userID)
	if err != nil {
		h.logger.Error("failed to update session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

// HandleEndSession — DELETE /sessions/{id}
func (h *Handler) HandleEndSession(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	if err := h.svc.EndSession(r.Context(), sessionID, userID); err != nil {
		h.logger.Error("failed to end session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Participant Endpoints ──────────────────────────────────────

// HandleJoinSession — POST /sessions/{id}/join
func (h *Handler) HandleJoinSession(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req JoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		// Allow empty body — default to tier "none"
		req = JoinRequest{SpotifyTier: "none"}
	}

	resp, err := h.svc.JoinSession(r.Context(), sessionID, userID, &req)
	if err != nil {
		h.logger.Error("failed to join session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

// HandleLeaveSession — POST /sessions/{id}/leave
func (h *Handler) HandleLeaveSession(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	if err := h.svc.LeaveSession(r.Context(), sessionID, userID); err != nil {
		h.logger.Error("failed to leave session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Queue Endpoints ────────────────────────────────────────────

// HandleAddToQueue — POST /sessions/{id}/queue
func (h *Handler) HandleAddToQueue(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req AddQueueItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.SpotifyURI == "" {
		h.writeError(w, http.StatusBadRequest, "spotify_uri is required")
		return
	}

	item, err := h.svc.AddToQueue(r.Context(), sessionID, &req, userID)
	if err != nil {
		h.logger.Error("failed to add to queue", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusCreated, item)
}

// HandleGetQueue — GET /sessions/{id}/queue
func (h *Handler) HandleGetQueue(w http.ResponseWriter, r *http.Request) {
	_, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	items, err := h.svc.GetQueue(r.Context(), sessionID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	if items == nil {
		items = []*MPQueueItem{}
	}

	h.writeJSON(w, http.StatusOK, items)
}

// HandleReorderQueueItem — PATCH /sessions/{id}/queue/{itemId}
func (h *Handler) HandleReorderQueueItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	vars := mux.Vars(r)
	sessionID := vars["id"]
	itemID := vars["itemId"]

	var req ReorderQueueItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.svc.ReorderQueueItem(r.Context(), sessionID, itemID, &req, userID); err != nil {
		h.logger.Error("failed to reorder queue item", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// HandleRemoveQueueItem — DELETE /sessions/{id}/queue/{itemId}
func (h *Handler) HandleRemoveQueueItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	vars := mux.Vars(r)
	sessionID := vars["id"]
	itemID := vars["itemId"]

	if err := h.svc.RemoveQueueItem(r.Context(), sessionID, itemID, userID); err != nil {
		h.logger.Error("failed to remove queue item", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Playback Control Endpoints ─────────────────────────────────

// HandlePlay — POST /sessions/{id}/play
func (h *Handler) HandlePlay(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	session, err := h.svc.Play(r.Context(), sessionID, userID)
	if err != nil {
		h.logger.Error("failed to start playback", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

// HandleSkip — POST /sessions/{id}/skip
func (h *Handler) HandleSkip(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req SkipRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		req = SkipRequest{Reason: "dj"}
	}

	session, err := h.svc.Skip(r.Context(), sessionID, &req, userID)
	if err != nil {
		h.logger.Error("failed to skip", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

// HandleHandoffDJ — POST /sessions/{id}/dj
func (h *Handler) HandleHandoffDJ(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req HandoffDJRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.ToUserID == "" {
		h.writeError(w, http.StatusBadRequest, "to_user_id is required")
		return
	}

	session, err := h.svc.HandoffDJ(r.Context(), sessionID, &req, userID)
	if err != nil {
		h.logger.Error("failed to handoff DJ", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

// ── Anchor Endpoints ───────────────────────────────────────────

// HandlePushAnchor — POST /sessions/{id}/anchor
func (h *Handler) HandlePushAnchor(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req PushAnchorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.svc.PushAnchor(r.Context(), sessionID, &req, userID); err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// HandleGetAnchor — GET /sessions/{id}/anchor
func (h *Handler) HandleGetAnchor(w http.ResponseWriter, r *http.Request) {
	_, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	anchor, err := h.svc.GetAnchor(r.Context(), sessionID)
	if err != nil {
		h.writeError(w, http.StatusNotFound, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, anchor)
}

// ── Vibe Endpoints ─────────────────────────────────────────────

// HandleAddVibe — POST /sessions/{id}/vibe
func (h *Handler) HandleAddVibe(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.parseUserID(r)
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	sessionID := mux.Vars(r)["id"]
	var req VibeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Kind == "" {
		h.writeError(w, http.StatusBadRequest, "kind is required")
		return
	}

	status, err := h.svc.AddVibe(r.Context(), sessionID, &req, userID)
	if err != nil {
		h.logger.Error("failed to add vibe", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	if status != nil {
		h.writeJSON(w, http.StatusOK, status)
	} else {
		w.WriteHeader(http.StatusNoContent)
	}
}
