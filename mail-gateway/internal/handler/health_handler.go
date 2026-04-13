package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/flicko-org/mail-gateway/internal/queue"
)

// HealthHandler provides system health check information for uptime monitors.
type HealthHandler struct {
	queue     *queue.EmailQueue
	workers   int
	startTime time.Time
	version   string
}

// NewHealthHandler creates a health check handler with references to system components.
func NewHealthHandler(q *queue.EmailQueue, workers int) *HealthHandler {
	return &HealthHandler{
		queue:     q,
		workers:   workers,
		startTime: time.Now(),
		version:   "1.0.0",
	}
}

// HealthResponse is the JSON structure returned by the health endpoint.
type HealthResponse struct {
	Status  string      `json:"status"`
	Version string      `json:"version"`
	Queue   QueueHealth `json:"queue"`
	Workers int         `json:"workers"`
	Uptime  string      `json:"uptime"`
}

// QueueHealth contains queue-specific health metrics.
type QueueHealth struct {
	Size    int  `json:"size"`
	Pending int  `json:"pending"`
	Closed  bool `json:"closed"`
}

// HandleHealth returns the current system health as JSON.
// GET /health — no authentication required.
func (h *HealthHandler) HandleHealth(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(h.startTime).Round(time.Second)

	response := HealthResponse{
		Status:  "ok",
		Version: h.version,
		Queue: QueueHealth{
			Size:    h.queue.Capacity(),
			Pending: h.queue.Pending(),
			Closed:  h.queue.IsClosed(),
		},
		Workers: h.workers,
		Uptime:  uptime.String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(response); err != nil {
		slog.Error("failed to encode health response", "error", err)
	}
}
