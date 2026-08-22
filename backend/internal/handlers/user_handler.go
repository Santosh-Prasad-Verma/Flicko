package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

// UserHandler handles user profile and settings HTTP endpoints.
type UserHandler struct {
	userSvc services.UserService
	logger  *zap.Logger
}

// NewUserHandler creates a new UserHandler instance.
func NewUserHandler(userSvc services.UserService, logger *zap.Logger) *UserHandler {
	return &UserHandler{
		userSvc: userSvc,
		logger:  logger,
	}
}

// GetMe returns the authenticated user's profile.
func (h *UserHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	user, err := h.userSvc.GetUser(r.Context(), userID)
	if err != nil {
		h.logger.Error("failed to get user profile for @me", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusNotFound, "User profile not found")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

// GetUser returns a user's public profile by ID or @me.
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["id"]
	if userID == "" || userID == "@me" {
		h.GetMe(w, r)
		return
	}

	user, err := h.userSvc.GetUser(r.Context(), userID)
	if err != nil {
		h.logger.Error("failed to get user profile", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusNotFound, "User not found")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

// UpdateProfile updates the current user's profile.
func (h *UserHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	user, err := h.userSvc.UpdateProfile(r.Context(), userID, updates)
	if err != nil {
		h.logger.Error("failed to update user profile", zap.String("user_id", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to update profile")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

// SearchUsers searches for users by username or display name.
func (h *UserHandler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		writeJSON(w, http.StatusOK, []interface{}{})
		return
	}

	users, err := h.userSvc.SearchUsers(r.Context(), query)
	if err != nil {
		h.logger.Error("failed to search users", zap.String("query", query), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "Failed to search users")
		return
	}

	writeJSON(w, http.StatusOK, users)
}
