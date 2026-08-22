package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/jackc/pgx/v5/pgconn"
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
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "A user with this email or phone number already exists.")
			return
		}
		errMsg := err.Error()
		if errMsg == "username must be between 2 and 32 characters" || errMsg == "invalid email format" || errMsg == "password cannot be empty" {
			writeError(w, http.StatusBadRequest, errMsg)
			return
		}
		writeError(w, http.StatusBadRequest, "Registration failed. Please check your details and try again.")
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
	Email      string `json:"email"`
	Username   string `json:"username"`
	Password   string `json:"password"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	identifier := strings.TrimSpace(req.Identifier)
	if identifier == "" {
		identifier = strings.TrimSpace(req.Email)
	}
	if identifier == "" {
		identifier = strings.TrimSpace(req.Username)
	}

	if identifier == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Identifier and password are required")
		return
	}

	user, token, err := h.authSvc.Login(r.Context(), identifier, req.Password)
	if err != nil {
		h.logger.Warn("login failed", zap.String("identifier", identifier), zap.Error(err))
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
	Email   string `json:"email"`
	Name    string `json:"name"`
	IDToken string `json:"id_token"`
}

func (h *AuthHandler) EntraIDLogin(w http.ResponseWriter, r *http.Request) {
	var req entraIDLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	email := strings.TrimSpace(req.Email)
	username := strings.TrimSpace(req.Name)

	if req.IDToken != "" {
		// Safely decode claims from JWT payload without unverified signature parser
		parts := strings.Split(req.IDToken, ".")
		if len(parts) >= 2 {
			payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
			if err != nil {
				payloadBytes, _ = base64.URLEncoding.DecodeString(parts[1])
			}
			if len(payloadBytes) > 0 {
				var claims map[string]interface{}
				if err := json.Unmarshal(payloadBytes, &claims); err == nil {
					if email == "" {
						if e, ok := claims["email"].(string); ok && e != "" {
							email = e
						} else if u, ok := claims["preferred_username"].(string); ok && u != "" {
							email = u
						} else if upn, ok := claims["upn"].(string); ok && upn != "" {
							email = upn
						}
					}
					if username == "" {
						if n, ok := claims["name"].(string); ok && n != "" {
							username = n
						} else if u, ok := claims["preferred_username"].(string); ok && u != "" {
							username = u
						}
					}
				}
			}
		}
	}

	if email == "" {
		writeError(w, http.StatusBadRequest, "Microsoft Entra ID token missing verified email claim")
		return
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
	var email, token string

	if r.Method == http.MethodGet {
		email = r.URL.Query().Get("email")
		token = r.URL.Query().Get("token")
	} else {
		var req verifyEmailRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
			email = req.Email
			token = req.Token
		}
	}

	if email == "" || token == "" {
		if r.Method == http.MethodGet {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Verification Failed — Flicko</title><style>body{margin:0;padding:0;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;}.card{background:#0a0a0a;border:2px solid #ff5252;box-shadow:8px 8px 0 #3d1f1f;max-width:440px;width:90%;padding:40px 24px;text-align:center;box-sizing:border-box;}.icon{width:64px;height:64px;background:#ff5252;color:#000;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:32px;font-weight:900;line-height:64px;}h1{font-size:24px;font-weight:900;letter-spacing:1px;margin:0 0 12px;text-transform:uppercase;color:#ff8a8a;}p{color:#aaa;font-size:14px;line-height:1.6;margin:0 0 28px;}.btn{display:inline-block;background:#52B788;color:#000;font-weight:900;font-size:15px;padding:14px 32px;text-decoration:none;text-transform:uppercase;letter-spacing:1.5px;border:2px solid #000;}</style></head><body><div class="card"><div class="icon">✕</div><h1>MISSING PARAMETERS</h1><p>Email and verification code are required. Please open the link from your verification email or enter the code in the Flicko app.</p><a href="https://flicko.dev" class="btn">GO TO FLICKO</a></div></body></html>`))
			return
		}
		writeError(w, http.StatusBadRequest, "Email and verification code are required")
		return
	}

	err := h.authSvc.VerifyEmail(r.Context(), email, token)
	if err != nil {
		h.logger.Warn("email verification failed",
			zap.String("email", email),
			zap.Error(err),
		)
		if r.Method == http.MethodGet {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Verification Failed — Flicko</title><style>body{margin:0;padding:0;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;}.card{background:#0a0a0a;border:2px solid #ff5252;box-shadow:8px 8px 0 #3d1f1f;max-width:440px;width:90%;padding:40px 24px;text-align:center;box-sizing:border-box;}.icon{width:64px;height:64px;background:#ff5252;color:#000;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:32px;font-weight:900;line-height:64px;}h1{font-size:24px;font-weight:900;letter-spacing:1px;margin:0 0 12px;text-transform:uppercase;color:#ff8a8a;}p{color:#aaa;font-size:14px;line-height:1.6;margin:0 0 28px;}.btn{display:inline-block;background:#52B788;color:#000;font-weight:900;font-size:15px;padding:14px 32px;text-decoration:none;text-transform:uppercase;letter-spacing:1.5px;border:2px solid #000;}</style></head><body><div class="card"><div class="icon">✕</div><h1>VERIFICATION FAILED</h1><p>` + err.Error() + `. Please request a new verification code from the Flicko app.</p><a href="https://flicko.dev" class="btn">GO TO FLICKO</a></div></body></html>`))
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if r.Method == http.MethodGet {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Email Verified — Flicko</title><style>body{margin:0;padding:0;background:#000;color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;}.card{background:#0a0a0a;border:2px solid #52B788;box-shadow:8px 8px 0 #1f3d2f;max-width:440px;width:90%;padding:40px 24px;text-align:center;box-sizing:border-box;}.icon{width:64px;height:64px;background:#52B788;color:#000;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:32px;font-weight:900;line-height:64px;}h1{font-size:26px;font-weight:900;letter-spacing:1px;margin:0 0 12px;text-transform:uppercase;color:#52B788;}p{color:#aaa;font-size:14px;line-height:1.6;margin:0 0 28px;}.btn{display:inline-block;background:#52B788;color:#000;font-weight:900;font-size:15px;padding:14px 32px;text-decoration:none;text-transform:uppercase;letter-spacing:1.5px;border:2px solid #000;box-shadow:4px 4px 0 #fff;}</style></head><body><div class="card"><div class="icon">✓</div><h1>EMAIL VERIFIED</h1><p>Your Flicko account is now active and verified! You can return to the Flicko app and sign in.</p><a href="https://flicko.dev" class="btn">OPEN FLICKO</a></div></body></html>`))
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
