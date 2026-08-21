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

// testPayload builds a valid Supabase webhook payload for testing.
func testPayload(eventType, email string) map[string]interface{} {
	return map[string]interface{}{
		"type": eventType,
		"user": map[string]interface{}{
			"id":    "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
			"email": email,
		},
		"data": map[string]interface{}{
			"token":             "raw-test-token",
			"token_hash":        "hashed-test-token",
			"redirect_to":       "http://localhost:3000",
			"email_action_type": eventType,
			"site_url":          "http://localhost:3000",
		},
	}
}

// signPayload creates an HMAC-SHA256 signature for the given body using the secret.
func signPayload(body []byte, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

// testConfig returns a minimal config for testing with the given webhook secret.
func testConfig(webhookSecret string) *config.Config {
	return &config.Config{
		Port:          "8080",
		AppEnv:        "development",
		AppName:       "TestApp",
		AppURL:        "http://localhost:3000",
		WebhookSecret: webhookSecret,
		AuthURL:       "http://localhost:3000",
	}
}

// TestHandleEmail_ValidSignature tests that a properly signed webhook returns 200.
func TestHandleEmail_ValidSignature(t *testing.T) {
	secret := "test-webhook-secret-123"
	cfg := testConfig(secret)
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("signup", "user@example.com")
	body, _ := json.Marshal(payload)
	signature := signPayload(body, secret)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-supabase-signature", signature)

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Signup now queues both verification and welcome emails.
	if q.Pending() != 2 {
		t.Errorf("expected 2 pending jobs, got %d", q.Pending())
	}
}

// TestHandleEmail_InvalidSignature tests that a bad signature returns 401.
func TestHandleEmail_InvalidSignature(t *testing.T) {
	secret := "test-webhook-secret-123"
	cfg := testConfig(secret)
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("signup", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-supabase-signature", "invalid-signature-here")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

// TestHandleEmail_MissingSignature tests that a missing signature header returns 401.
func TestHandleEmail_MissingSignature(t *testing.T) {
	secret := "test-webhook-secret-123"
	cfg := testConfig(secret)
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("signup", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	// No x-supabase-signature header

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d: %s", rr.Code, rr.Body.String())
	}
}

// TestHandleEmail_BadPayload tests that malformed JSON returns 400.
func TestHandleEmail_BadPayload(t *testing.T) {
	cfg := testConfig("") // Empty secret — dev mode skips signature check
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	body := []byte(`{this is not valid json}`)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d: %s", rr.Code, rr.Body.String())
	}
}

// TestHandleEmail_MissingRequiredFields tests that an incomplete payload returns 400.
func TestHandleEmail_MissingRequiredFields(t *testing.T) {
	cfg := testConfig("") // Dev mode — skip signature
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	// Payload missing type and email
	payload := map[string]interface{}{
		"user": map[string]interface{}{"id": "123"},
		"data": map[string]interface{}{},
	}
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d: %s", rr.Code, rr.Body.String())
	}
}

// TestHandleEmail_SignupType tests that signup events are routed correctly.
func TestHandleEmail_SignupType(t *testing.T) {
	cfg := testConfig("")
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("signup", "newuser@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	if q.Pending() != 2 {
		t.Errorf("expected 2 pending jobs, got %d", q.Pending())
	}
}

// TestHandleEmail_RecoveryType tests that recovery events are routed correctly.
func TestHandleEmail_RecoveryType(t *testing.T) {
	cfg := testConfig("")
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("recovery", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
}

// TestHandleEmail_MagicLinkType tests that magiclink events are routed correctly.
func TestHandleEmail_MagicLinkType(t *testing.T) {
	cfg := testConfig("")
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("magiclink", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
}

// TestHandleEmail_UnknownType tests that unknown event types return 200 (skipped).
func TestHandleEmail_UnknownType(t *testing.T) {
	cfg := testConfig("")
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("unknown_type", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	// Unknown types should be gracefully skipped with 200
	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 for unknown type, got %d", rr.Code)
	}
	// Should NOT be enqueued
	if q.Pending() != 0 {
		t.Errorf("expected 0 pending jobs for unknown type, got %d", q.Pending())
	}
}

// TestHandleEmail_QueueFull tests that a full queue returns 503.
func TestHandleEmail_QueueFull(t *testing.T) {
	cfg := testConfig("")
	q := queue.NewEmailQueue(1) // Queue size of 1
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	// Fill the queue
	payload1 := testPayload("signup", "user1@example.com")
	body1, _ := json.Marshal(payload1)
	req1 := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body1))
	req1.Header.Set("Content-Type", "application/json")
	rr1 := httptest.NewRecorder()
	h.HandleEmail(rr1, req1)

	if rr1.Code != http.StatusOK {
		t.Fatalf("first request should succeed, got %d", rr1.Code)
	}

	// Second request should fail with 503 (queue full)
	payload2 := testPayload("signup", "user2@example.com")
	body2, _ := json.Marshal(payload2)
	req2 := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body2))
	req2.Header.Set("Content-Type", "application/json")
	rr2 := httptest.NewRecorder()
	h.HandleEmail(rr2, req2)

	if rr2.Code != http.StatusServiceUnavailable {
		t.Errorf("expected 503, got %d: %s", rr2.Code, rr2.Body.String())
	}
}

// TestHandleEmail_DevModeNoSecret tests that dev mode works without WEBHOOK_SECRET.
func TestHandleEmail_DevModeNoSecret(t *testing.T) {
	cfg := testConfig("") // No secret, development mode
	q := queue.NewEmailQueue(10)
	defer q.Close()
	h := handler.NewHookHandler(cfg, q)

	payload := testPayload("signup", "user@example.com")
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/hooks/email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	h.HandleEmail(rr, req)

	// Should succeed in dev mode without signature
	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 in dev mode, got %d: %s", rr.Code, rr.Body.String())
	}
}
