package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/services"
	"go.uber.org/zap"
)

// AuthHandler handles authentication HTTP endpoints.
type AuthHandler struct {
	authSvc services.AuthService
	logger  *zap.Logger
}

// NewAuthHandler creates a new AuthHandler.
func NewAuthHandler(authSvc services.AuthService, logger *zap.Logger) *AuthHandler {
	return &AuthHandler{authSvc: authSvc, logger: logger}
}

// ── Register ────────────────────────────────────────────────────────────────

type registerRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Username == "" || req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Username, email, and password are required")
		return
	}

	user, token, err := h.authSvc.Register(r.Context(), req.Username, req.Email, req.Password)
	if err != nil {
		h.logger.Warn("registration failed", zap.String("email", req.Email), zap.Error(err))
		// Don't reveal whether email/username already exists
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"user":  user,
		"token": token,
	})
}

// ── Login ───────────────────────────────────────────────────────────────────

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Email and password are required")
		return
	}

	user, token, err := h.authSvc.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		h.logger.Warn("login failed", zap.String("email", req.Email), zap.Error(err))
		writeError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user":  user,
		"token": token,
	})
}
