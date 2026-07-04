package gateway_test

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/flicko-org/flicko-backend/internal/bots/gateway"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
	"golang.org/x/net/websocket"
)

func TestGateway_HelloAndIdentifyLifecycle(t *testing.T) {
	jwtSecret := "test-secret-32-bytes-super-safe!"
	logger := zap.NewNop()

	gwServer := gateway.NewServer(nil, nil, jwtSecret, logger)
	ts := httptest.NewServer(gwServer.HandleWebSocket())
	defer ts.Close()

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http")

	ws, err := websocket.Dial(wsURL, "", "http://localhost/")
	assert.NoError(t, err)
	defer ws.Close()

	// 1. Expect Op 10 Hello
	var helloPayload gateway.GatewayPayload
	err = websocket.JSON.Receive(ws, &helloPayload)
	assert.NoError(t, err)
	assert.Equal(t, gateway.OpHello, helloPayload.Op)

	var helloData gateway.HelloData
	err = json.Unmarshal(helloPayload.D, &helloData)
	assert.NoError(t, err)
	assert.Equal(t, 41250, helloData.HeartbeatInterval)

	// 2. Send Op 2 Identify
	testBotID := "bot-uuid-1234"
	token, err := auth.GenerateToken(testBotID, "v1", []byte(jwtSecret))
	assert.NoError(t, err)

	identifyData := gateway.IdentifyData{
		Token:   token,
		Intents: 513,
	}
	identifyBytes, _ := json.Marshal(identifyData)

	identifyPayload := gateway.GatewayPayload{
		Op: gateway.OpIdentify,
		D:  json.RawMessage(identifyBytes),
	}
	err = websocket.JSON.Send(ws, identifyPayload)
	assert.NoError(t, err)

	// 3. Expect Op 0 READY
	var readyPayload gateway.GatewayPayload
	err = websocket.JSON.Receive(ws, &readyPayload)
	assert.NoError(t, err)
	assert.Equal(t, gateway.OpDispatch, readyPayload.Op)
	assert.Equal(t, "READY", readyPayload.T)

	var readyData gateway.ReadyData
	err = json.Unmarshal(readyPayload.D, &readyData)
	assert.NoError(t, err)
	assert.Equal(t, testBotID, readyData.User.ID)
	assert.NotEmpty(t, readyData.SessionID)

	// 4. Send Op 1 Heartbeat
	heartbeatPayload := gateway.GatewayPayload{
		Op: gateway.OpHeartbeat,
	}
	err = websocket.JSON.Send(ws, heartbeatPayload)
	assert.NoError(t, err)

	// 5. Expect Op 11 Heartbeat ACK
	var ackPayload gateway.GatewayPayload
	err = websocket.JSON.Receive(ws, &ackPayload)
	assert.NoError(t, err)
	assert.Equal(t, gateway.OpHeartbeatACK, ackPayload.Op)
}
