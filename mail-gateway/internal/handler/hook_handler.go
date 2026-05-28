// Package handler provides HTTP handlers for the mail gateway.
package handler

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

// HookHandler receives Supabase Auth webhook events, verifies their
// HMAC-SHA256 signature, and enqueues email jobs for async sending.
type HookHandler struct {
	cfg   *config.Config
	queue *queue.EmailQueue
}

// NewHookHandler creates a new webhook handler connected to the given queue.
func NewHookHandler(cfg *config.Config, q *queue.EmailQueue) *HookHandler {
	return &HookHandler{
		cfg:   cfg,
		queue: q,
	}
}

// HandleEmail is the main webhook endpoint: POST /hooks/email
// It reads the raw body, verifies the HMAC signature, parses the payload,
// builds the action URL, and pushes an EmailJob to the queue.
//
// Response codes:
//   - 200: email queued successfully
//   - 400: bad/invalid payload
//   - 401: invalid signature (webhook_secret mismatch)
//   - 503: queue full (signals Supabase to retry)
func (h *HookHandler) HandleEmail(w http.ResponseWriter, r *http.Request) {
	// Step 1: Read the raw body BEFORE json.Decode (needed for HMAC verification)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		slog.Error("failed to read request body", "error", err)
		http.Error(w, `{"error":"failed to read body"}`, http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Step 2: Verify HMAC-SHA256 signature
	if !h.verifySignature(r, body) {
		slog.Warn("webhook signature verification failed",
			"remote_addr", r.RemoteAddr,
			"signature_header", r.Header.Get("x-supabase-signature"),
			"ua", r.UserAgent(),
		)
		http.Error(w, `{"error":"invalid signature"}`, http.StatusUnauthorized)
		return
	}

	// Step 3: Parse JSON payload
	var payload models.SupabaseHookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		slog.Error("failed to parse webhook payload",
			"error", err,
		)
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	// Step 4: Normalize payload (unifies Auth Hook and Database Webhook formats)
	payload.Normalize()

	// Step 5: Validate required fields
	if err := payload.Validate(); err != nil {
		slog.Error("webhook payload validation failed",
			"error", err,
		)
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), http.StatusBadRequest)
		return
	}

	// Step 6: Check if event type is known — skip unknown types gracefully
	if !payload.IsKnownType() {
		slog.Warn("unknown webhook event type, skipping",
			"type", payload.Type,
			"email", payload.User.Email,
		)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message":"unknown type, skipped"}`))
		return
	}

	slog.Info("webhook received",
		"type", payload.Type,
		"email", payload.User.Email,
		"user_id", payload.User.ID,
		"has_confirmation_url", payload.Data.ConfirmationURL != "",
		"has_token_hash", payload.Data.TokenHash != "",
		"has_token", payload.Data.Token != "",
		"redirect_to", payload.Data.RedirectTo,
	)

	// Step 7: Build the email job
	job := h.buildEmailJob(payload)

	// Step 8: Push to queue (non-blocking)
	if err := h.queue.Enqueue(job); err != nil {
		slog.Error("failed to enqueue email job",
			"error", err,
			"job_id", job.ID,
		)
		// 503 tells Supabase to retry later
		http.Error(w, `{"error":"queue full, retry later"}`, http.StatusServiceUnavailable)
		return
	}

	// Step 8b: For signup events, also queue a welcome email alongside the verification email.
	// The user receives both: a verification link AND a welcome message.
	if payload.Type == "signup" {
		welcomeJob := h.buildWelcomeJob(payload)
		if err := h.queue.Enqueue(welcomeJob); err != nil {
			// Non-critical — log but don't fail the whole request
			slog.Warn("failed to enqueue welcome email (verification still sent)",
				"error", err,
				"job_id", welcomeJob.ID,
			)
		} else {
			slog.Info("welcome email queued alongside verification",
				"email", payload.User.Email,
				"job_id", welcomeJob.ID,
			)
		}
	}

	// Step 9: Return 200 immediately — email will be sent asynchronously.
	// Supabase Auth Hooks require an empty JSON object {} in the response body
	// to acknowledge the hook was handled. Any other response may cause Supabase
	// to fall back to its built-in email handling or report an error.
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{}`))
}

// verifySignature checks the HMAC-SHA256 signature.
// Supports two formats:
//   1. Modern Standard Webhooks (Svix spec): parses Webhook-Signature, Webhook-Id, Webhook-Timestamp
//   2. Legacy x-supabase-signature format (v1,signature)
//
// Uses hmac.Equal for constant-time comparison (timing-attack safe).
// In development mode, skips verification if WEBHOOK_SECRET is empty.
func (h *HookHandler) verifySignature(r *http.Request, body []byte) bool {
	// In development, allow skipping signature verification
	if h.cfg.WebhookSecret == "" {
		if h.cfg.IsDevelopment() {
			slog.Warn("WEBHOOK_SECRET not set — skipping signature verification (development mode only)")
			return true
		}
		slog.Error("WEBHOOK_SECRET not set in production — rejecting request")
		return false
	}

	// 1. Try modern Standard Webhook (Svix) format: Webhook-Signature, Webhook-Id, Webhook-Timestamp
	webhookSignature := r.Header.Get("Webhook-Signature")
	webhookID := r.Header.Get("Webhook-Id")
	webhookTimestamp := r.Header.Get("Webhook-Timestamp")

	if webhookSignature != "" && webhookID != "" && webhookTimestamp != "" {
		// Clean secret prefix if copied incorrectly
		secretStr := h.cfg.WebhookSecret
		secretStr = strings.TrimPrefix(secretStr, "v1,")
		secretStr = strings.TrimPrefix(secretStr, "whsec_")

		// Decode the base64 secret (standard for Svix/Supabase)
		var secretBytes []byte
		var err error
		if secretBytes, err = base64.StdEncoding.DecodeString(secretStr); err != nil {
			secretBytes = []byte(secretStr)
		}

		// Construct signed content: msg_id + "." + timestamp + "." + raw_payload
		signedContent := fmt.Sprintf("%s.%s.%s", webhookID, webhookTimestamp, string(body))

		// Calculate HMAC-SHA256
		mac := hmac.New(sha256.New, secretBytes)
		mac.Write([]byte(signedContent))
		computed := mac.Sum(nil)

		// Supabase Webhook-Signature is v1,base64_sig or multiple sigs separated by spaces
		sigs := strings.Split(webhookSignature, " ")
		for _, sig := range sigs {
			cleanSig := strings.TrimPrefix(sig, "v1,")

			sigBytes, err := base64.StdEncoding.DecodeString(cleanSig)
			if err != nil {
				continue
			}

			// Constant-time comparison
			if hmac.Equal(computed, sigBytes) {
				return true
			}
		}

		slog.Warn("webhook standard signature verification failed", "signature_header", webhookSignature)
		return false
	}

	// 2. Fallback to old format: x-supabase-signature
	signature := r.Header.Get("x-supabase-signature")
	if signature == "" {
		headers := make(map[string]string)
		for k, v := range r.Header {
			if len(v) > 0 {
				headers[k] = v[0]
			}
		}
		slog.Warn("missing standard Webhook-Signature and legacy x-supabase-signature", "received_headers", headers)
		return false
	}

	// The signature header format is "v1,SIGNATURE"
	rawSignature := strings.TrimPrefix(signature, "v1,")

	secretStr := h.cfg.WebhookSecret
	secretStr = strings.TrimPrefix(secretStr, "v1,")
	secretStr = strings.TrimPrefix(secretStr, "whsec_")

	// Compute expected HMAC-SHA256
	mac := hmac.New(sha256.New, []byte(secretStr))
	mac.Write(body)
	expectedMAC := hex.EncodeToString(mac.Sum(nil))

	// Constant-time comparison
	return hmac.Equal([]byte(rawSignature), []byte(expectedMAC))
}

// buildEmailJob creates an EmailJob from the webhook payload, routing to
// the correct template and building the appropriate action URL.
func (h *HookHandler) buildEmailJob(payload models.SupabaseHookPayload) models.EmailJob {
	templateName, subject := h.routeEmailType(payload.Type)

	// Build the verification/action URL that goes in the email
	actionURL := h.buildActionURL(payload)

	// Determine token validity period based on type
	validFor := "24 hours"
	if payload.Type == "magiclink" {
		validFor = "10 minutes"
	}

	// Extract username from user metadata (set during signUp options.data)
	username := payload.User.DisplayName()

	return models.EmailJob{
		ID:           fmt.Sprintf("%s-%s-%d", payload.Type, payload.User.ID[:8], time.Now().UnixNano()),
		To:           payload.User.Email,
		Subject:      subject,
		TemplateName: templateName,
		Data: models.EmailData{
			To:        payload.User.Email,
			Username:  username,
			Subject:   subject,
			ActionURL: actionURL,
			AppName:   h.cfg.AppName,
			AppURL:    h.cfg.AppURL,
			Token:     payload.Data.Token,
			ValidFor:  validFor,
			Year:      time.Now().Year(),
		},
		CreatedAt: time.Now(),
		Attempts:  0,
	}
}

// buildWelcomeJob creates a welcome EmailJob for new signups.
// This is sent alongside the verification email so the user receives
// both a verification link and a warm welcome message.
func (h *HookHandler) buildWelcomeJob(payload models.SupabaseHookPayload) models.EmailJob {
	username := payload.User.DisplayName()

	// Generate a placeholder avatar using the user's email/username
	avatarURL := fmt.Sprintf(
		"https://ui-avatars.com/api/?name=%s&background=535cec&color=fff&size=128",
		url.QueryEscape(username),
	)

	return models.EmailJob{
		ID:           fmt.Sprintf("welcome-%s-%d", payload.User.ID[:8], time.Now().UnixNano()),
		To:           payload.User.Email,
		Subject:      fmt.Sprintf("🎉 Welcome to %s — you're in!", h.cfg.AppName),
		TemplateName: "welcome",
		Data: models.EmailData{
			To:          payload.User.Email,
			Username:    username,
			AvatarURL:   avatarURL,
			Subject:     fmt.Sprintf("🎉 Welcome to %s — you're in!", h.cfg.AppName),
			AppName:     h.cfg.AppName,
			AppURL:      h.cfg.AppURL,
			MemberSince: time.Now().Format("January 2006"),
			Year:        time.Now().Year(),
		},
		CreatedAt: time.Now(),
		Attempts:  0,
	}
}

// routeEmailType maps the Supabase event type to a template name and email subject.
func (h *HookHandler) routeEmailType(eventType string) (templateName, subject string) {
	switch eventType {
	case "signup":
		return "verify", fmt.Sprintf("Verify your %s account", h.cfg.AppName)
	case "recovery":
		return "reset", fmt.Sprintf("Reset your %s password", h.cfg.AppName)
	case "magiclink":
		return "magic_link", fmt.Sprintf("Your %s login link", h.cfg.AppName)
	case "email_change":
		return "confirm_email_change", fmt.Sprintf("Confirm your new %s email", h.cfg.AppName)
	case "invite":
		return "invite", fmt.Sprintf("You've been invited to %s", h.cfg.AppName)
	case "reauthentication":
		return "reauthentication", fmt.Sprintf("Confirm your identity on %s", h.cfg.AppName)
	default:
		return "verify", fmt.Sprintf("%s notification", h.cfg.AppName)
	}
}

// buildActionURL returns the verification/action URL for the email.
//
// Supabase Auth Hooks (send_email) include a pre-built confirmation_url that
// contains a properly signed token. We MUST use that when available, because
// manually constructed URLs use a different token format that Supabase won't accept.
//
// For legacy Database Webhook format (no confirmation_url), we fall back to
// building the URL manually: {SUPABASE_URL}/auth/v1/verify?token={TOKEN_HASH}&type={TYPE}&redirect_to={REDIRECT}
func (h *HookHandler) buildActionURL(payload models.SupabaseHookPayload) string {
	// Prefer the pre-built confirmation_url from Supabase Auth Hook
	if payload.Data.ConfirmationURL != "" {
		slog.Info("using pre-built confirmation_url from Supabase",
			"url_prefix", payload.Data.ConfirmationURL[:min(80, len(payload.Data.ConfirmationURL))],
		)

		// Rewrite redirect_to in the confirmation URL to point to our actual APP_URL
		// instead of whatever site_url Supabase has configured (which may be an
		// unowned domain like flicko.app)
		confURL := h.rewriteRedirectTo(payload.Data.ConfirmationURL)
		return confURL
	}

	// Fallback: build the URL manually (Database Webhook / legacy format)
	slog.Warn("no confirmation_url in payload, building URL manually")

	token := payload.Data.TokenHash
	if token == "" {
		token = payload.Data.Token
	}

	redirectTo := payload.Data.RedirectTo
	if redirectTo == "" || strings.Contains(redirectTo, "localhost") || strings.Contains(redirectTo, "127.0.0.1") {
		if h.cfg.AppURL != "" {
			baseAppURL := strings.TrimSuffix(h.cfg.AppURL, "/")
			redirectTo = baseAppURL + "/open"
		}
	}


	u, _ := url.Parse(h.cfg.SupabaseURL)
	u.Path = "/auth/v1/verify"

	q := u.Query()
	q.Set("token", token)
	q.Set("type", payload.Type)
	q.Set("redirect_to", redirectTo)
	u.RawQuery = q.Encode()

	return u.String()
}

// rewriteRedirectTo replaces the redirect_to query parameter in a Supabase
// confirmation URL with the configured APP_URL. This ensures that after
// Supabase verifies the token, the user is redirected to our actual app
// instead of whatever site_url is configured in the Supabase dashboard
// (which may be an unowned/non-existent domain).
func (h *HookHandler) rewriteRedirectTo(confirmationURL string) string {
	u, err := url.Parse(confirmationURL)
	if err != nil {
		slog.Warn("failed to parse confirmation_url, returning as-is",
			"url", confirmationURL,
			"error", err,
		)
		return confirmationURL
	}

	q := u.Query()
	oldRedirect := q.Get("redirect_to")
	if oldRedirect != "" && h.cfg.AppURL != "" {
		baseAppURL := strings.TrimSuffix(h.cfg.AppURL, "/")
		newRedirect := baseAppURL + "/open"
		slog.Info("rewriting redirect_to in confirmation URL",
			"old", oldRedirect,
			"new", newRedirect,
		)
		q.Set("redirect_to", newRedirect)
		u.RawQuery = q.Encode()
	}

	return u.String()
}
