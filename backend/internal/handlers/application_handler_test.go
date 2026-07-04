package handlers_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/flicko-org/flicko-backend/internal/handlers"
	"go.uber.org/zap"
)

func TestBotAuthMiddleware_NoHeader(t *testing.T) {
	logger := zap.NewNop()
	handlers.SetBotAuthDB(nil, "my-jwt-secret-key-12345", nil, logger)

	req := httptest.NewRequest("GET", "/bot-api/whoami", nil)
	rr := httptest.NewRecorder()

	handler := handlers.BotAuthMiddleware("", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", rr.Code)
	}

	body := strings.TrimSpace(rr.Body.String())
	if body != "missing Authorization header" {
		t.Errorf("expected missing header error message, got %q", body)
	}
}

func TestBotAuthMiddleware_InvalidFormat(t *testing.T) {
	logger := zap.NewNop()
	handlers.SetBotAuthDB(nil, "my-jwt-secret-key-12345", nil, logger)

	req := httptest.NewRequest("GET", "/bot-api/whoami", nil)
	req.Header.Set("Authorization", "InvalidHeader abc.123.xyz")
	rr := httptest.NewRecorder()

	handler := handlers.BotAuthMiddleware("", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", rr.Code)
	}

	body := strings.TrimSpace(rr.Body.String())
	if body != "invalid Authorization header format" {
		t.Errorf("expected invalid format error message, got %q", body)
	}
}

func TestBotAuthMiddleware_MalformedToken(t *testing.T) {
	logger := zap.NewNop()
	handlers.SetBotAuthDB(nil, "my-jwt-secret-key-12345", nil, logger)

	req := httptest.NewRequest("GET", "/bot-api/whoami", nil)
	req.Header.Set("Authorization", "Bot malformed.token.here")
	rr := httptest.NewRecorder()

	handler := handlers.BotAuthMiddleware("", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", rr.Code)
	}

	body := strings.TrimSpace(rr.Body.String())
	if !strings.Contains(body, "invalid token signature") {
		t.Errorf("expected token signature error, got %q", body)
	}
}

func TestBotAuthMiddleware_SignatureMismatch(t *testing.T) {
	logger := zap.NewNop()
	handlers.SetBotAuthDB(nil, "my-jwt-secret-key-12345", nil, logger)

	// Generate a token with a different secret
	wrongSecret := []byte("wrong-secret-key-12345-wrong-wrong-wrong")
	token, err := auth.GenerateToken("bot-id-123", "v1", wrongSecret)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	req := httptest.NewRequest("GET", "/bot-api/whoami", nil)
	req.Header.Set("Authorization", "Bot "+token)
	rr := httptest.NewRecorder()

	handler := handlers.BotAuthMiddleware("", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", rr.Code)
	}

	body := strings.TrimSpace(rr.Body.String())
	if !strings.Contains(body, "invalid token signature") {
		t.Errorf("expected token signature error, got %q", body)
	}
}

func TestBotAuthMiddleware_DbNotConfigured(t *testing.T) {
	logger := zap.NewNop()
	secret := []byte("my-jwt-secret-key-12345")
	handlers.SetBotAuthDB(nil, string(secret), nil, logger)

	token, err := auth.GenerateToken("bot-id-123", "v1", secret)
	if err != nil {
		t.Fatalf("failed to generate token: %v", err)
	}

	req := httptest.NewRequest("GET", "/bot-api/whoami", nil)
	req.Header.Set("Authorization", "Bot "+token)
	rr := httptest.NewRecorder()

	handler := handlers.BotAuthMiddleware("", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	handler.ServeHTTP(rr, req)

	// DB is nil, so it should return 500 internal service error
	if rr.Code != http.StatusInternalServerError {
		t.Errorf("expected 500 Internal Server Error, got %d", rr.Code)
	}

	body := strings.TrimSpace(rr.Body.String())
	if body != "internal service error" {
		t.Errorf("expected internal service error, got %q", body)
	}
}

func TestBotIDFromContext_Success(t *testing.T) {
	ctx := context.WithValue(context.Background(), handlers.BotIDContextKey, "my-bot-uuid")
	botID, err := handlers.BotIDFromContext(ctx)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if botID != "my-bot-uuid" {
		t.Errorf("expected bot ID %q, got %q", "my-bot-uuid", botID)
	}
}

func TestBotIDFromContext_Missing(t *testing.T) {
	ctx := context.Background()
	_, err := handlers.BotIDFromContext(ctx)
	if err == nil {
		t.Error("expected error for missing bot ID, got nil")
	}
}
