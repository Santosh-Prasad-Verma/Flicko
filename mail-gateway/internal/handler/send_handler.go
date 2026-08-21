package handler

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"time"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

// SendHandler exposes a REST endpoint the frontend calls AFTER a user
// successfully signs up or logs in — Supabase does NOT fire webhooks for
// login events, so the client must trigger this manually.
//
// POST /send
// Header: x-api-key: <SEND_API_KEY from .env>
// Body:   { "to": "user@example.com", "type": "welcome" }
type SendHandler struct {
	cfg    *config.Config
	queue  *queue.EmailQueue
	apiKey string // shared secret the frontend sends in x-api-key header
}

// SendRequest is the JSON body accepted by POST /send.
type SendRequest struct {
	// To is the recipient email address
	To string `json:"to"`

	// Username is the user's display name
	Username string `json:"username,omitempty"`

	// Type is the email to send: "welcome", "verify", "flicko_plus", etc.
	Type string `json:"type"`

	// Token is the verification code for verify emails
	Token string `json:"token,omitempty"`

	// AvatarURL is an optional profile picture URL
	AvatarURL string `json:"avatar_url,omitempty"`

	// TransactionID is the payment reference for receipts
	TransactionID string `json:"transaction_id,omitempty"`

	// TotalAmount is the formatted price for receipts
	TotalAmount string `json:"total_amount,omitempty"`
}

// NewSendHandler creates a new SendHandler. apiKey must match the header
// value sent by the frontend for authentication.
func NewSendHandler(cfg *config.Config, q *queue.EmailQueue) *SendHandler {
	return &SendHandler{
		cfg:    cfg,
		queue:  q,
		apiKey: cfg.SendAPIKey,
	}
}

// HandleSend accepts direct email send requests from the frontend.
// It validates the API key, builds an EmailJob, and pushes it to the queue.
//
// POST /send
// Responses:
//   - 200: email queued
//   - 400: bad request body
//   - 401: missing or wrong API key
//   - 503: queue full
func (h *SendHandler) HandleSend(w http.ResponseWriter, r *http.Request) {
	// Step 1: Verify API key — prevents public abuse
	apiKey := r.Header.Get("x-api-key")
	if apiKey == "" {
		apiKey = r.Header.Get("X-Internal-Token")
	}
	if apiKey == "" {
		authHeader := r.Header.Get("Authorization")
		if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
			apiKey = authHeader[7:]
		}
	}
	if !h.validateAPIKey(apiKey) {
		slog.Warn("send endpoint: invalid or missing api key",
			"remote_addr", r.RemoteAddr,
			"auth_attempted", apiKey != "", // Log if auth was attempted but failed
		)
		http.Error(w, `{"error":"invalid api key"}`, http.StatusUnauthorized)
		return
	}

	// Step 2: Parse request body
	var req SendRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid JSON body"}`, http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Step 3: Validate required fields
	if req.To == "" {
		http.Error(w, `{"error":"field 'to' is required"}`, http.StatusBadRequest)
		return
	}
	if req.Type == "" {
		req.Type = "welcome" // default to welcome email
	}

	// Use To as username fallback
	username := req.Username
	if username == "" {
		username = req.To
	}

	// Step 4: Route to correct template
	templateName, subject, err := h.routeSendType(req.Type)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusBadRequest)
		return
	}

	// Generate fallback avatar if none provided
	avatarURL := req.AvatarURL
	if avatarURL == "" {
		avatarURL = fmt.Sprintf("https://ui-avatars.com/api/?name=%s&background=535cec&color=fff&size=128", url.QueryEscape(username))
	}

	// Step 5: Build job
	job := models.EmailJob{
		ID:           fmt.Sprintf("%s-%d", req.Type, time.Now().UnixNano()),
		To:           req.To,
		Subject:      subject,
		TemplateName: templateName,
		Data: models.EmailData{
			To:            req.To,
			Username:      username,
			AvatarURL:     avatarURL,
			Subject:       subject,
			Token:         req.Token,
			AppName:       h.cfg.AppName,
			AppURL:        h.cfg.AppURL,
			MemberSince:   time.Now().Format("January 02, 2006"),
			TransactionID: req.TransactionID,
			TotalAmount:   req.TotalAmount,
			Year:          time.Now().Year(),
		},
		CreatedAt: time.Now(),
	}

	// Step 6: Push to queue
	if err := h.queue.Enqueue(job); err != nil {
		slog.Error("send endpoint: queue full", "to", req.To, "type", req.Type)
		http.Error(w, `{"error":"queue full, retry later"}`, http.StatusServiceUnavailable)
		return
	}

	slog.Info("send endpoint: email queued",
		"type", req.Type,
		"to", req.To,
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message":"email queued"}`))
}

// routeSendType maps send type string to template name and subject.
func (h *SendHandler) routeSendType(sendType string) (templateName, subject string, err error) {
	switch sendType {
	case "welcome":
		return "welcome",
			fmt.Sprintf("Welcome to %s — Let's get started!", h.cfg.AppName),
			nil
	case "verify":
		return "verify",
			fmt.Sprintf("Verify your %s account", h.cfg.AppName),
			nil
	case "flicko_plus":
		return "flicko_plus",
			fmt.Sprintf("✨ Welcome to %s Plus — You're in!", h.cfg.AppName),
			nil
	default:
		return "", "", fmt.Errorf("unknown send type: %q (supported: welcome, verify, flicko_plus)", sendType)
	}
}

// validateAPIKey checks the provided key against the configured SEND_API_KEY.
// SECURITY FIXED: Requires explicit ENABLE_INSECURE_DEV_MODE=true for development
// bypass; missing SEND_API_KEY no longer implies development mode.
// Uses constant-time comparison to prevent timing attacks.
func (h *SendHandler) validateAPIKey(key string) bool {
	// Case 1: No API key configured
	if h.apiKey == "" {
		// Development mode ONLY if explicitly enabled via config flag
		// (not just because the key is missing)
		if h.cfg.EnableInsecureDevMode {
			slog.Warn("validateAPIKey: development mode enabled with no API key",
				"severity", "development-only",
				"recommendation", "set SEND_API_KEY in production",
			)
			return true
		}

		// Production mode: missing API key = always reject
		slog.Error("validateAPIKey: SEND_API_KEY not configured",
			"hint", "Set SEND_API_KEY in .env or ENABLE_INSECURE_DEV_MODE=true (dev only)",
			"security_impact", "all email requests rejected",
		)
		return false
	}

	// Case 2: API key configured - use constant-time comparison
	// Prevents timing attacks that could leak key length/content
	return constantTimeCompare(key, h.apiKey)
}

// constantTimeCompare compares two strings in constant time to prevent
// timing-based attacks. Returns true if strings are equal, false otherwise.
func constantTimeCompare(a, b string) bool {
	// First check: lengths must match
	if len(a) != len(b) {
		return false
	}

	// Second check: compare all bytes even if mismatch found
	// (prevents early exit that could leak byte position/value)
	result := 0
	for i := 0; i < len(a); i++ {
		result |= int(a[i]) ^ int(b[i])
	}

	return result == 0
}
