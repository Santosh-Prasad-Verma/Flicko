package handler

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

type PaymentHandler struct {
	cfg        *config.Config
	emailQueue *queue.EmailQueue
}

func NewPaymentHandler(cfg *config.Config, emailQueue *queue.EmailQueue) *PaymentHandler {
	return &PaymentHandler{
		cfg:        cfg,
		emailQueue: emailQueue,
	}
}

// HandleCreateOrder handles the creation of a Razorpay order.
func (h *PaymentHandler) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Plan         string `json:"plan"`
		BillingCycle string `json:"billing_cycle"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.respondError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Calculate amount based on plan
	// Example: Plus = 499 INR, Basic = 199 INR
	amount := 49900 // in paise
	if body.Plan == "basic" {
		amount = 19900
	}

	// Create order in Razorpay
	orderData := map[string]interface{}{
		"amount":   amount,
		"currency": "INR",
		"receipt":  fmt.Sprintf("receipt_%d", amount),
	}

	jsonOrder, _ := json.Marshal(orderData)

	req, _ := http.NewRequest("POST", "https://api.razorpay.com/v1/orders", bytes.NewBuffer(jsonOrder))
	req.SetBasicAuth(h.cfg.RazorpayKeyID, h.cfg.RazorpayKeySecret)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		slog.Error("failed to create Razorpay order", "error", err)
		h.respondError(w, "failed to create payment order", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		slog.Error("Razorpay API error", "status", resp.StatusCode, "body", string(body))
		h.respondError(w, "razorpay api error", http.StatusInternalServerError)
		return
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		slog.Error("failed to decode Razorpay order response", "error", err)
		h.respondError(w, "razorpay returned invalid response", http.StatusBadGateway)
		return
	}

	h.respondJSON(w, result, http.StatusOK)
}

// HandleVerifyPayment handles payment verification and triggers the receipt email.
func (h *PaymentHandler) HandleVerifyPayment(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RazorpayOrderID   string `json:"razorpay_order_id"`
		RazorpayPaymentID string `json:"razorpay_payment_id"`
		RazorpaySignature string `json:"razorpay_signature"`
		Email             string `json:"email"`
		Username          string `json:"username"`
		PlanName          string `json:"plan_name"`
		Amount            string `json:"amount"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.respondError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Verify signature
	payload := body.RazorpayOrderID + "|" + body.RazorpayPaymentID
	mac := hmac.New(sha256.New, []byte(h.cfg.RazorpayKeySecret))
	mac.Write([]byte(payload))
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(expectedSignature), []byte(body.RazorpaySignature)) {
		slog.Warn("invalid payment signature", "order_id", body.RazorpayOrderID)
		h.respondError(w, "invalid payment signature", http.StatusUnauthorized)
		return
	}

	// Signature is valid!
	slog.Info("payment verified successfully", 
		"order_id", body.RazorpayOrderID, 
		"payment_id", body.RazorpayPaymentID,
		"email", body.Email,
	)

	// Trigger Receipt & Welcome Email
	if body.Email != "" {
		err := h.emailQueue.Enqueue(models.EmailJob{
			To:           body.Email,
			Subject:      "Welcome to Flicko Plus! ✨",
			TemplateName: "flicko_plus",
			Data: models.EmailData{
				To:            body.Email,
				Username:      body.Username,
				AppName:       h.cfg.AppName,
				AppURL:        h.cfg.AppURL,
				TransactionID: body.RazorpayPaymentID,
				TotalAmount:   body.Amount,
				MemberSince:   time.Now().Format("January 02, 2006"),
				Year:          time.Now().Year(),
			},
			CreatedAt: time.Now(),
		})
		if err != nil {
			slog.Error("failed to enqueue Flicko Plus receipt email",
				"error", err,
				"email", body.Email,
				"payment_id", body.RazorpayPaymentID,
			)
		}
	}

	h.respondJSON(w, map[string]string{"status": "success"}, http.StatusOK)
}

func (h *PaymentHandler) respondJSON(w http.ResponseWriter, data interface{}, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *PaymentHandler) respondError(w http.ResponseWriter, message string, status int) {
	h.respondJSON(w, map[string]string{"error": message}, status)
}
