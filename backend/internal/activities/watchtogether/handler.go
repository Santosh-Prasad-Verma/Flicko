package watchtogether

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"go.uber.org/zap"
)

type Handler struct {
	svc    Service
	logger *zap.Logger
}

func NewHandler(svc Service, logger *zap.Logger) *Handler {
	return &Handler{
		svc:    svc,
		logger: logger.Named("handler.watchtogether"),
	}
}

func (h *Handler) HandleCreate(w http.ResponseWriter, r *http.Request) {
	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var req CreateSessionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Media.URL == "" {
		h.writeError(w, http.StatusBadRequest, "media url is required")
		return
	}

	session, err := h.svc.CreateSession(r.Context(), &req, userID)
	if err != nil {
		h.logger.Error("failed to create watch together session", zap.Error(err))
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.writeJSON(w, http.StatusCreated, session)
}

func (h *Handler) HandleGet(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	session, err := h.svc.GetSession(r.Context(), sessionID)
	if err != nil {
		h.writeError(w, http.StatusNotFound, "session not found")
		return
	}

	h.writeJSON(w, http.StatusOK, session)
}

func (h *Handler) HandleEnd(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	err = h.svc.EndSession(r.Context(), sessionID, userID)
	if err != nil {
		h.writeError(w, http.StatusForbidden, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) HandleJoin(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	// Wait, we need a username for LiveKit tokens.
	// In the future, this can be retrieved from profiles. For the REST skeleton, we can fallback to the userID or parse a query param.
	// Let's check query parameter `username` or use a default "Viewer".
	userName := r.URL.Query().Get("username")
	if userName == "" {
		userName = fmt.Sprintf("User_%s", userIDStr[:8])
	}

	resp, err := h.svc.JoinSession(r.Context(), sessionID, userID, userName)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) HandleLeave(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	err = h.svc.LeaveSession(r.Context(), sessionID, userID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) HandleTransferHost(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var req TransferHostRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	toUserID, err := uuid.Parse(req.ToUserID)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid target user id")
		return
	}

	err = h.svc.TransferHost(r.Context(), sessionID, userID, toUserID)
	if err != nil {
		h.writeError(w, http.StatusForbidden, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]string{"status": "transferred"})
}

func (h *Handler) HandleUpdateAnchor(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	userIDStr := h.getUserID(r)
	if userIDStr == "" {
		h.writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var req PushAnchorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	err = h.svc.UpdateSessionAnchor(r.Context(), sessionID, userID, &req)
	if err != nil {
		if err == ErrAnchorRateLimitExceeded {
			h.writeError(w, http.StatusTooManyRequests, err.Error())
			return
		}
		h.writeError(w, http.StatusForbidden, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (h *Handler) HandleGetAnchor(w http.ResponseWriter, r *http.Request) {
	sessionID := mux.Vars(r)["id"]
	if sessionID == "" {
		h.writeError(w, http.StatusBadRequest, "session id is required")
		return
	}

	anchor, err := h.svc.GetSessionAnchor(r.Context(), sessionID)
	if err != nil {
		h.writeError(w, http.StatusNotFound, err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, anchor)
}

func (h *Handler) HandleListLobbies(w http.ResponseWriter, r *http.Request) {
	lobbies, err := h.svc.ListPublicLobbies(r.Context())
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	h.writeJSON(w, http.StatusOK, lobbies)
}


// Private helpers matching Flicko internal style

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
