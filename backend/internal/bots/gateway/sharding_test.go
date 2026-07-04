package gateway_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/bots/gateway"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestHandleGatewayBot(t *testing.T) {
	logger := zap.NewNop()
	coord := gateway.NewShardCoordinator(nil, nil, logger)

	req := httptest.NewRequest("GET", "/api/v1/gateway/bot", nil)
	req.Host = "localhost:8080"
	rr := httptest.NewRecorder()

	coord.HandleGatewayBot(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)

	var resp gateway.GatewayBotResponse
	err := json.Unmarshal(rr.Body.Bytes(), &resp)
	assert.NoError(t, err)

	assert.Equal(t, "ws://localhost:8080/api/v1/gateway", resp.URL)
	assert.Equal(t, 1, resp.Shards)
	assert.Equal(t, 1000, resp.SessionStartLimit.Total)
	assert.GreaterOrEqual(t, resp.SessionStartLimit.Remaining, 0)
	assert.Equal(t, 1, resp.SessionStartLimit.MaxConcurrency)
}
