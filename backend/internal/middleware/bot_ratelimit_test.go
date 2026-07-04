package middleware_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/gorilla/mux"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestExtractBucketKey(t *testing.T) {
	req := httptest.NewRequest("POST", "/channels/chan-1234/messages", nil)
	req = mux.SetURLVars(req, map[string]string{"channel_id": "chan-1234"})

	bucketHash, bucketKey, limit, window := middleware.ExtractBucketKey(req)

	assert.NotEmpty(t, bucketHash)
	assert.Equal(t, "bot_bucket:messages_create:chan:chan-1234", bucketKey)
	assert.Equal(t, int64(5), limit)
	assert.Equal(t, 5*time.Second, window)
}

func TestGetAuditLogReason(t *testing.T) {
	req := httptest.NewRequest("DELETE", "/servers/srv-1/members/usr-2", nil)
	req.Header.Set("X-Audit-Log-Reason", "Spamming in main channel")

	reason := middleware.GetAuditLogReason(req)
	assert.NotNil(t, reason)
	assert.Equal(t, "Spamming in main channel", *reason)

	reqEmpty := httptest.NewRequest("DELETE", "/servers/srv-1/members/usr-2", nil)
	assert.Nil(t, middleware.GetAuditLogReason(reqEmpty))
}

func TestBotRateLimiter_NoAuthContext(t *testing.T) {
	logger := zap.NewNop()
	limiter := middleware.NewBotRateLimiter(nil, logger)

	req := httptest.NewRequest("GET", "/bot-api/test", nil)
	rr := httptest.NewRecorder()

	nextCalled := false
	handler := limiter.Limit(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	// Since request is unauthenticated, limiter passes request through directly
	assert.True(t, nextCalled)
	assert.Equal(t, http.StatusOK, rr.Code)
}

func TestBotRateLimiter_WithAuthContextHeaders(t *testing.T) {
	logger := zap.NewNop()
	limiter := middleware.NewBotRateLimiter(nil, logger) // nil redis means passthrough after setting headers

	req := httptest.NewRequest("POST", "/channels/c123/messages", nil)
	req = mux.SetURLVars(req, map[string]string{"channel_id": "c123"})

	// Inject authenticated bot ID into context
	ctx := context.WithValue(req.Context(), middleware.GetUserIDKey(), "bot-user-uuid-99")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()

	handler := limiter.Limit(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.NotEmpty(t, rr.Header().Get("X-RateLimit-Bucket"))
	assert.Equal(t, "5", rr.Header().Get("X-RateLimit-Limit"))
	assert.NotEmpty(t, rr.Header().Get("X-RateLimit-Remaining"))
	assert.NotEmpty(t, rr.Header().Get("X-RateLimit-Reset"))
}
