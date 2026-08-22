package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/golang-jwt/jwt/v5"
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
	Phone    string `json:"phone"`
	Password string `json:"password"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Username == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Username and password are required")
		return
	}

	user, token, err := h.authSvc.Register(r.Context(), req.Username, req.Email, req.Phone, req.Password)
	if err != nil {
		h.logger.Warn("registration failed", zap.String("username", req.Username), zap.Error(err))
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
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Identifier == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Identifier and password are required")
		return
	}

	user, token, err := h.authSvc.Login(r.Context(), req.Identifier, req.Password)
	if err != nil {
		h.logger.Warn("login failed", zap.String("identifier", req.Identifier), zap.Error(err))
		writeError(w, http.StatusUnauthorized, "Invalid credentials")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user":  user,
		"token": token,
	})
}

// ── Entra ID (Azure AD) SSO ───────────────────────────────────────────────────

type entraIDLoginRequest struct {
	IDToken string `json:"id_token"`
}

func (h *AuthHandler) EntraIDLogin(w http.ResponseWriter, r *http.Request) {
	var req entraIDLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if strings.TrimSpace(req.IDToken) == "" {
		writeError(w, http.StatusBadRequest, "Microsoft Entra ID token (id_token) is required")
		return
	}

	// Parse ID Token to extract claims
	var claims jwt.MapClaims
	parser := jwt.NewParser()
	_, _, err := parser.ParseUnverified(req.IDToken, &claims)
	if err != nil {
		h.logger.Warn("failed to parse entra id token", zap.Error(err))
		writeError(w, http.StatusBadRequest, "Invalid Microsoft Entra ID token format")
		return
	}

	email, _ := claims["email"].(string)
	if email == "" {
		email, _ = claims["preferred_username"].(string)
	}
	if email == "" {
		email, _ = claims["upn"].(string)
	}
	if email == "" {
		writeError(w, http.StatusBadRequest, "Entra ID token missing verified email claim")
		return
	}

	username, _ := claims["name"].(string)
	if username == "" {
		username, _ = claims["preferred_username"].(string)
	}
	if username == "" {
		username = strings.Split(email, "@")[0]
	}

	// Generate a cryptographically secure random password for the SSO account
	randBytes := make([]byte, 32)
	if _, err := rand.Read(randBytes); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to generate security token")
		return
	}
	ssoPassword := "sso_rand_" + hex.EncodeToString(randBytes) + "!"

	user, token, err := h.authSvc.Login(r.Context(), email, ssoPassword)
	if err != nil {
		user, token, err = h.authSvc.Register(r.Context(), username, email, "", ssoPassword)
		if err != nil {
			h.logger.Warn("entra id sso failed", zap.String("email", email), zap.Error(err))
			writeError(w, http.StatusUnauthorized, "Microsoft Entra ID authentication failed")
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"provider": "microsoft_entra_id",
		"user":     user,
		"token":    token,
	})
}

// ── Verify Email ────────────────────────────────────────────────────────────

type verifyEmailRequest struct {
	Email string `json:"email"`
	Token string `json:"token"`
}

func (h *AuthHandler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Email == "" || req.Token == "" {
		writeError(w, http.StatusBadRequest, "Email and verification code are required")
		return
	}

	err := h.authSvc.VerifyEmail(r.Context(), req.Email, req.Token)
	if err != nil {
		h.logger.Warn("email verification failed",
			zap.String("email", req.Email),
			zap.Error(err),
		)
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Email verified successfully",
	})
}

// ── Resend Verification ─────────────────────────────────────────────────────

type resendVerificationRequest struct {
	Email string `json:"email"`
}

func (h *AuthHandler) ResendVerification(w http.ResponseWriter, r *http.Request) {
	var req resendVerificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Email == "" {
		writeError(w, http.StatusBadRequest, "Email is required")
		return
	}

	err := h.authSvc.ResendVerification(r.Context(), req.Email)
	if err != nil {
		h.logger.Warn("resend verification failed",
			zap.String("email", req.Email),
			zap.Error(err),
		)
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Verification code sent",
	})
}
