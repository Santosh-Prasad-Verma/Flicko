package middleware

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

type mockRedis struct {
	redis.Cmdable
	setNXFunc func(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd
}

func (m *mockRedis) SetNX(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd {
	return m.setNXFunc(ctx, key, value, expiration)
}

func createSignature(body []byte, timestamp, nonce, secret string) string {
	var payload []byte
	payload = append(payload, body...)
	payload = append(payload, []byte(timestamp)...)
	payload = append(payload, []byte(nonce)...)

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	return hex.EncodeToString(mac.Sum(nil))
}

func TestHMACSigningMiddleware(t *testing.T) {
	logger := zap.NewNop()
	secret := "test_secret_key"

	nextHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("success"))
	})

	t.Run("Valid request", func(t *testing.T) {
		body := []byte(`{"amount": 100, "user_id": "test-user"}`)
		timestamp := strconv.FormatInt(time.Now().Unix(), 10)
		nonce := "unique-nonce-1"
		signature := createSignature(body, timestamp, nonce, secret)

		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(body))
		req.Header.Set("X-Signature", signature)
		req.Header.Set("X-Timestamp", timestamp)
		req.Header.Set("X-Nonce", nonce)

		// Mock redis client that returns SetNX true
		mockRDB := &mockRedis{
			setNXFunc: func(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd {
				cmd := redis.NewBoolCmd(ctx)
				cmd.SetVal(true)
				return cmd
			},
		}

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(mockRDB, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "success", w.Body.String())
	})

	t.Run("Missing headers", func(t *testing.T) {
		body := []byte(`{"amount": 100}`)
		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(body))

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(nil, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "HMAC_SIGNATURE_MISSING")
	})

	t.Run("Replay attack - expired timestamp", func(t *testing.T) {
		body := []byte(`{"amount": 100}`)
		// 6 minutes old timestamp
		timestamp := strconv.FormatInt(time.Now().Add(-6*time.Minute).Unix(), 10)
		nonce := "unique-nonce-2"
		signature := createSignature(body, timestamp, nonce, secret)

		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(body))
		req.Header.Set("X-Signature", signature)
		req.Header.Set("X-Timestamp", timestamp)
		req.Header.Set("X-Nonce", nonce)

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(nil, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "HMAC_TIMESTAMP_OUT_OF_RANGE")
	})

	t.Run("Replay attack - duplicate nonce", func(t *testing.T) {
		body := []byte(`{"amount": 100}`)
		timestamp := strconv.FormatInt(time.Now().Unix(), 10)
		nonce := "duplicate-nonce"
		signature := createSignature(body, timestamp, nonce, secret)

		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(body))
		req.Header.Set("X-Signature", signature)
		req.Header.Set("X-Timestamp", timestamp)
		req.Header.Set("X-Nonce", nonce)

		// Mock redis client that returns SetNX false (duplicate nonce)
		mockRDB := &mockRedis{
			setNXFunc: func(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd {
				cmd := redis.NewBoolCmd(ctx)
				cmd.SetVal(false)
				return cmd
			},
		}

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(mockRDB, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "HMAC_DUPLICATE_NONCE")
	})

	t.Run("Payload tampered", func(t *testing.T) {
		body := []byte(`{"amount": 100}`)
		timestamp := strconv.FormatInt(time.Now().Unix(), 10)
		nonce := "unique-nonce-3"
		signature := createSignature(body, timestamp, nonce, secret)

		// Tampered body
		tamperedBody := []byte(`{"amount": 1000000}`)
		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(tamperedBody))
		req.Header.Set("X-Signature", signature)
		req.Header.Set("X-Timestamp", timestamp)
		req.Header.Set("X-Nonce", nonce)

		mockRDB := &mockRedis{
			setNXFunc: func(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd {
				cmd := redis.NewBoolCmd(ctx)
				cmd.SetVal(true)
				return cmd
			},
		}

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(mockRDB, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "HMAC_SIGNATURE_MISMATCH")
	})

	t.Run("Redis error resilience", func(t *testing.T) {
		body := []byte(`{"amount": 100}`)
		timestamp := strconv.FormatInt(time.Now().Unix(), 10)
		nonce := "unique-nonce-4"
		signature := createSignature(body, timestamp, nonce, secret)

		req := httptest.NewRequest("POST", "/v1/purchases", bytes.NewBuffer(body))
		req.Header.Set("X-Signature", signature)
		req.Header.Set("X-Timestamp", timestamp)
		req.Header.Set("X-Nonce", nonce)

		// Mock redis client that returns an error
		mockRDB := &mockRedis{
			setNXFunc: func(ctx context.Context, key string, value interface{}, expiration time.Duration) *redis.BoolCmd {
				cmd := redis.NewBoolCmd(ctx)
				cmd.SetErr(errors.New("redis connection refused"))
				return cmd
			},
		}

		w := httptest.NewRecorder()
		middleware := HMACSigningMiddleware(mockRDB, logger, secret)
		middleware(nextHandler).ServeHTTP(w, req)

		// Should bypass Redis nonce checks and still succeed because signature is valid
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "success", w.Body.String())
	})
}
