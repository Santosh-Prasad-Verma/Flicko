package handler

import (
"context"
"encoding/json"
"fmt"
"net/http"
"time"

goredis "github.com/redis/go-redis/v9"
"go.uber.org/zap"

"github.com/flicko-org/flicko/services/ws-gateway/internal/conn"
)

// HealthHandler returns a /healthz endpoint that checks Redis
// connectivity and reports the active connection count.
type HealthHandler struct {
rdb     *goredis.Client
manager *conn.Manager
log     *zap.Logger
}

// NewHealthHandler creates a HealthHandler.
func NewHealthHandler(rdb *goredis.Client, mgr *conn.Manager, log *zap.Logger) *HealthHandler {
return &HealthHandler{rdb: rdb, manager: mgr, log: log}
}

// healthResponse is the JSON body returned by /healthz.
type healthResponse struct {
Status      string `json:"status"`
Redis       string `json:"redis"`
Connections int64  `json:"connections"`
Uptime      string `json:"uptime"`
}

// startTime is used to compute uptime.
var startTime = time.Now()

// ServeHTTP handles GET /healthz.
func (h *HealthHandler) ServeHTTP(w http.ResponseWriter, _ *http.Request) {
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()

redisStatus := "ok"
overallStatus := "ok"

if err := h.rdb.Ping(ctx).Err(); err != nil {
redisStatus = fmt.Sprintf("error: %v", err)
overallStatus = "degraded"
h.log.Warn("healthz: redis ping failed", zap.Error(err))
}

resp := healthResponse{
Status:      overallStatus,
Redis:       redisStatus,
Connections: h.manager.ActiveConnections(),
Uptime:      time.Since(startTime).Truncate(time.Second).String(),
}

w.Header().Set("Content-Type", "application/json")
if overallStatus != "ok" {
w.WriteHeader(http.StatusServiceUnavailable)
} else {
w.WriteHeader(http.StatusOK)
}
json.NewEncoder(w).Encode(resp) //nolint:errcheck
}
