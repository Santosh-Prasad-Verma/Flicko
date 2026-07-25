package unit

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/handler"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

// razorpaySignature computes the HMAC-SHA256 signature Razorpay expects:
// hex(HMAC_SHA256(order_id + "|" + payment_id, key_secret)).
func razorpaySignature(orderID, paymentID, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(orderID + "|" + paymentID))
	return hex.EncodeToString(mac.Sum(nil))
}

// paymentTestConfig returns a config with a known Razorpay secret for signing.
func paymentTestConfig(razorpaySecret string) *config.Config {
	return &config.Config{
		Port:              "8080",
		AppEnv:            "development",
		AppName:           "TestApp",
		AppURL:            "http://localhost:3000",
		RazorpayKeyID:     "rzp_test_key",
		RazorpayKeySecret: razorpaySecret,
	}
}

// doVerify posts a verify-payment body and returns the recorder.
func doVerify(t *testing.T, cfg *config.Config, q *queue.EmailQueue, body map[string]interface{}) *httptest.ResponseRecorder {
	t.Helper()
	h := handler.NewPaymentHandler(cfg, q)
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal body: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/api/payments/razorpay/verify", bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.HandleVerifyPayment(rec, req)
	return rec
}

// TestVerifyPayment_ValidSignature asserts a correctly signed payment is accepted (200).
func TestVerifyPayment_ValidSignature(t *testing.T) {
	secret := "rzp_secret_valid_case"
	cfg := paymentTestConfig(secret)
	q := queue.NewEmailQueue(10)
	defer q.Close()

	orderID, paymentID := "order_ABC123", "pay_XYZ789"
	rec := doVerify(t, cfg, q, map[string]interface{}{
		"razorpay_order_id":   orderID,
		"razorpay_payment_id": paymentID,
		"razorpay_signature":  razorpaySignature(orderID, paymentID, secret),
		// no email -> no enqueue side effect, keeps this test focused on signature acceptance
	})

	if rec.Code != http.StatusOK {
		t.Fatalf("valid signature should be accepted: got status %d, body %s", rec.Code, rec.Body.String())
	}
}

// TestVerifyPayment_ForgedSignature is the critical security assertion: a forged
// signature (attacker-chosen string) MUST be rejected with 401. A regression that
// drops or inverts the check would grant paid entitlements to unsigned requests.
func TestVerifyPayment_ForgedSignature(t *testing.T) {
	cfg := paymentTestConfig("rzp_secret_real")
	q := queue.NewEmailQueue(10)
	defer q.Close()

	rec := doVerify(t, cfg, q, map[string]interface{}{
		"razorpay_order_id":   "order_ABC123",
		"razorpay_payment_id": "pay_XYZ789",
		"razorpay_signature":  "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
	})

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("forged signature MUST be rejected with 401, got %d (body %s) — payment verification bypass!", rec.Code, rec.Body.String())
	}
}

// TestVerifyPayment_SignatureFromWrongSecret asserts a signature that is validly
// computed but with the WRONG secret (e.g. attacker guessing / a leaked test key)
// is rejected. Guards against the server trusting any well-formed HMAC.
func TestVerifyPayment_SignatureFromWrongSecret(t *testing.T) {
	cfg := paymentTestConfig("rzp_secret_real")
	q := queue.NewEmailQueue(10)
	defer q.Close()

	orderID, paymentID := "order_ABC123", "pay_XYZ789"
	rec := doVerify(t, cfg, q, map[string]interface{}{
		"razorpay_order_id":   orderID,
		"razorpay_payment_id": paymentID,
		"razorpay_signature":  razorpaySignature(orderID, paymentID, "attacker_secret"),
	})

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("signature signed with wrong secret MUST be rejected with 401, got %d", rec.Code)
	}
}

// TestVerifyPayment_TamperedOrderID asserts that if the order_id is swapped after
// signing (signature was valid for a different order), verification fails. This is
// the "replay a signature onto a different order" attack.
func TestVerifyPayment_TamperedOrderID(t *testing.T) {
	secret := "rzp_secret_real"
	cfg := paymentTestConfig(secret)
	q := queue.NewEmailQueue(10)
	defer q.Close()

	// Sign for the original order, then submit a different order_id with that signature.
	sig := razorpaySignature("order_ORIGINAL", "pay_XYZ789", secret)
	rec := doVerify(t, cfg, q, map[string]interface{}{
		"razorpay_order_id":   "order_TAMPERED",
		"razorpay_payment_id": "pay_XYZ789",
		"razorpay_signature":  sig,
	})

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("signature bound to a different order_id MUST be rejected with 401, got %d", rec.Code)
	}
}

// TestVerifyPayment_EmptySignature asserts a missing signature field is rejected,
// not treated as a match against an empty/nil comparison.
func TestVerifyPayment_EmptySignature(t *testing.T) {
	cfg := paymentTestConfig("rzp_secret_real")
	q := queue.NewEmailQueue(10)
	defer q.Close()

	rec := doVerify(t, cfg, q, map[string]interface{}{
		"razorpay_order_id":   "order_ABC123",
		"razorpay_payment_id": "pay_XYZ789",
		"razorpay_signature":  "",
	})

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("empty signature MUST be rejected with 401, got %d", rec.Code)
	}
}
