package handler

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

// MoonclerkHandler handles webhook events from Moonclerk.
type MoonclerkHandler struct {
	cfg        *config.Config
	emailQueue *queue.EmailQueue
}

// NewMoonclerkHandler creates a new handler for Moonclerk events.
func NewMoonclerkHandler(cfg *config.Config, emailQueue *queue.EmailQueue) *MoonclerkHandler {
	return &MoonclerkHandler{
		cfg:        cfg,
		emailQueue: emailQueue,
	}
}

// HandleWebhook is the entry point for Moonclerk webhooks: POST /hooks/moonclerk
func (h *MoonclerkHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	// 1. Read the raw body for signature verification
	body, err := io.ReadAll(r.Body)
	if err != nil {
		slog.Error("failed to read Moonclerk request body", "error", err)
		http.Error(w, `{"error":"failed to read body"}`, http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// 2. Verify Moonclerk signature
	if !h.verifySignature(r, body) {
		slog.Warn("Moonclerk webhook signature verification failed",
			"remote_addr", r.RemoteAddr,
			"signature_header", r.Header.Get("X-Moonclerk-Signature"),
		)
		http.Error(w, `{"error":"invalid signature"}`, http.StatusUnauthorized)
		return
	}

	// 3. Parse payload
	var payload models.MoonclerkWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		slog.Error("failed to parse Moonclerk payload", "error", err)
		http.Error(w, `{"error":"invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	slog.Info("Moonclerk webhook received",
		"event", payload.Event,
		"email", payload.Data.CustomerEmail,
		"amount", payload.Data.Amount,
		"status", payload.Data.Status,
	)

	// 4. Process specific events
	switch payload.Event {
	case "payment_created":
		h.handlePaymentCreated(payload)
	default:
		slog.Debug("ignoring Moonclerk event", "event", payload.Event)
	}

	// 5. Acknowledge receipt
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"success"}`))
}

func (h *MoonclerkHandler) verifySignature(r *http.Request, body []byte) bool {
	// In development, skip if secret is empty
	if h.cfg.MoonclerkWebhookSecret == "" {
		if h.cfg.IsDevelopment() {
			slog.Warn("MOONCLERK_WEBHOOK_SECRET not set — skipping verification (dev only)")
			return true
		}
		slog.Error("MOONCLERK_WEBHOOK_SECRET not set in production")
		return false
	}

	signature := r.Header.Get("X-Moonclerk-Signature")
	if signature == "" {
		return false
	}

	mac := hmac.New(sha256.New, []byte(h.cfg.MoonclerkWebhookSecret))
	mac.Write(body)
	expectedMAC := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(signature), []byte(expectedMAC))
}

func (h *MoonclerkHandler) handlePaymentCreated(payload models.MoonclerkWebhookPayload) {
	if payload.Data.Status != "succeeded" {
		slog.Info("skipping non-successful payment", "status", payload.Data.Status)
		return
	}

	username := payload.GetUsername()
	if username == "" {
		username = payload.Data.CustomerEmail
	}

	// Enqueue a "Flicko Plus" welcome/receipt email
	if err := h.emailQueue.Enqueue(models.EmailJob{
		To:           payload.Data.CustomerEmail,
		Subject:      "Welcome to Flicko Plus! ✨",
		TemplateName: "flicko_plus",
		Data: models.EmailData{
			To:            payload.Data.CustomerEmail,
			Username:      username,
			AppName:       h.cfg.AppName,
			AppURL:        h.cfg.AppURL,
			TransactionID: payload.Data.ID,
			TotalAmount:   payload.GetAmountFormatted(),
			MemberSince:   time.Now().Format("January 02, 2006"),
			Year:          time.Now().Year(),
		},
		CreatedAt: time.Now(),
	}); err != nil {
		slog.Error("failed to enqueue Moonclerk receipt email",
			"error", err,
			"email", payload.Data.CustomerEmail,
			"tx_id", payload.Data.ID,
		)
		return
	}

	slog.Info("Moonclerk payment handled: welcome email queued",
		"email", payload.Data.CustomerEmail,
		"tx_id", payload.Data.ID,
	)
}
