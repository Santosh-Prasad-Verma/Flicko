package handlers_test

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/handlers"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestVerifyEd25519Signature_Valid(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	assert.NoError(t, err)

	pubHex := hex.EncodeToString(pub)
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	body := []byte(`{"type":1}`)

	msg := append([]byte(timestamp), body...)
	sig := ed25519.Sign(priv, msg)
	sigHex := hex.EncodeToString(sig)

	valid := handlers.VerifyEd25519Signature(pubHex, sigHex, timestamp, body)
	assert.True(t, valid)
}

func TestVerifyEd25519Signature_StaleTimestamp(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	assert.NoError(t, err)

	pubHex := hex.EncodeToString(pub)
	// Timestamp 10 minutes ago
	staleTimestamp := strconv.FormatInt(time.Now().Add(-10*time.Minute).Unix(), 10)
	body := []byte(`{"type":1}`)

	msg := append([]byte(staleTimestamp), body...)
	sig := ed25519.Sign(priv, msg)
	sigHex := hex.EncodeToString(sig)

	valid := handlers.VerifyEd25519Signature(pubHex, sigHex, staleTimestamp, body)
	assert.False(t, valid)
}

func TestInteractionHandler_PingPong(t *testing.T) {
	logger := zap.NewNop()
	interactionHandler := handlers.NewInteractionHandler(nil, logger)

	bodyBytes, _ := json.Marshal(map[string]interface{}{
		"id":   "int-123",
		"type": handlers.InteractionTypePing,
	})

	timestamp := strconv.FormatInt(time.Now().Unix(), 10)

	req := httptest.NewRequest("POST", "/interactions", bytes.NewBuffer(bodyBytes))
	req.Header.Set("X-Signature-Ed25519", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
	req.Header.Set("X-Signature-Timestamp", timestamp)

	rr := httptest.NewRecorder()

	interactionHandler.HandleInteraction(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)

	var resp handlers.InteractionResponse
	err := json.Unmarshal(rr.Body.Bytes(), &resp)
	assert.NoError(t, err)
	assert.Equal(t, handlers.ResponseTypePong, resp.Type)
}
