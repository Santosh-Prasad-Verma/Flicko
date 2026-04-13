package handler

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// HealthHandler serves liveness and readiness probes.
type HealthHandler struct {
	db    *pgxpool.Pool
	redis *goredis.Client
	log   *zap.Logger
}

// NewHealthHandler creates a HealthHandler.
func NewHealthHandler(db *pgxpool.Pool, redis *goredis.Client, log *zap.Logger) *HealthHandler {
	return &HealthHandler{db: db, redis: redis, log: log}
}

// Healthz checks Redis + DB connectivity.
// GET /healthz
func (h *HealthHandler) Healthz(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	checks := map[string]string{}
	healthy := true

	if err := h.checkDB(ctx); err != nil {
		checks["database"] = err.Error()
		healthy = false
	} else {
		checks["database"] = "ok"
	}

	if err := h.checkRedis(ctx); err != nil {
		checks["redis"] = err.Error()
		healthy = false
	} else {
		checks["redis"] = "ok"
	}

	status := http.StatusOK
	if !healthy {
		status = http.StatusServiceUnavailable
	}

	JSON(w, status, checks)
}

func (h *HealthHandler) checkDB(ctx context.Context) error {
	return h.db.Ping(ctx)
}

func (h *HealthHandler) checkRedis(ctx context.Context) error {
	return h.redis.Ping(ctx).Err()
}
