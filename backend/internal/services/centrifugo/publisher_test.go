package centrifugo

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestNopPublisher_PublishIsNoOp(t *testing.T) {
	err := (NopPublisher{}).Publish(context.Background(), "game:abc", map[string]int{"x": 1})
	assert.NoError(t, err)
}

func TestHTTPPublisher_NoOpWhenURLEmpty(t *testing.T) {
	p := NewHTTPPublisher("", "key", zap.NewNop())
	err := p.Publish(context.Background(), "game:abc", map[string]string{"k": "v"})
	assert.NoError(t, err, "empty URL should swallow the publish (dev/test mode)")
}

func TestHTTPPublisher_PostsCorrectShape(t *testing.T) {
	type captured struct {
		Method   string
		Path     string
		APIKey   string
		BodyJSON map[string]any
	}
	var seen captured

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen.Method = r.Method
		seen.Path = r.URL.Path
		seen.APIKey = r.Header.Get("X-API-Key")
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &seen.BodyJSON)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"result":{}}`))
	}))
	defer srv.Close()

	p := NewHTTPPublisher(srv.URL+"/api", "secret-key", zap.NewNop())
	payload := map[string]any{
		"type":        "dice",
		"playerIndex": 1,
		"value":       4,
	}

	err := p.Publish(context.Background(), "game:42", payload)
	assert.NoError(t, err)

	assert.Equal(t, http.MethodPost, seen.Method)
	assert.Equal(t, "/api", seen.Path)
	assert.Equal(t, "secret-key", seen.APIKey)
	assert.Equal(t, "publish", seen.BodyJSON["method"])

	params := seen.BodyJSON["params"].(map[string]any)
	assert.Equal(t, "game:42", params["channel"])

	// `data` is sent as a raw JSON value; assert it round-trips.
	dataRaw, _ := json.Marshal(params["data"])
	var got map[string]any
	_ = json.Unmarshal(dataRaw, &got)
	assert.Equal(t, "dice", got["type"])
	assert.Equal(t, float64(1), got["playerIndex"])
	assert.Equal(t, float64(4), got["value"])
}

func TestHTTPPublisher_SwallowsServerErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	defer srv.Close()

	p := NewHTTPPublisher(srv.URL, "", zap.NewNop())
	err := p.Publish(context.Background(), "game:42", map[string]int{"x": 1})
	assert.NoError(t, err, "server errors must be swallowed so game actions never fail")
}

func TestHTTPPublisher_SwallowsConnectionErrors(t *testing.T) {
	// Point at a closed port. The publish should not return an error.
	p := NewHTTPPublisher("http://127.0.0.1:1/api", "", zap.NewNop())
	err := p.Publish(context.Background(), "game:42", map[string]int{"x": 1})
	assert.NoError(t, err)
}

func TestHTTPPublisher_LogsAPIError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"error":{"code":109,"message":"namespace not found"}}`))
	}))
	defer srv.Close()

	p := NewHTTPPublisher(srv.URL, "", zap.NewNop())
	err := p.Publish(context.Background(), "game:42", map[string]int{"x": 1})
	// API errors are logged but never surfaced — game actions must keep working.
	assert.NoError(t, err)
}
