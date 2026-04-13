// HIGH-008: Health Check Endpoints
// Provides comprehensive health status for liveness and readiness probes
package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/database"
)

// HealthStatus represents overall service health
type HealthStatus string

const (
	StatusHealthy   HealthStatus = "healthy"
	StatusDegraded  HealthStatus = "degraded"
	StatusUnhealthy HealthStatus = "unhealthy"
)

// HealthCheckResponse is the API response for health checks
type HealthCheckResponse struct {
	Status       HealthStatus                `json:"status"`
	Timestamp    time.Time                   `json:"timestamp"`
	Uptime       int64                       `json:"uptime_seconds"`
	Version      string                      `json:"version"`
	Dependencies map[string]DependencyHealth `json:"dependencies"`
	Metrics      map[string]interface{}      `json:"metrics,omitempty"`
}

// DependencyHealth represents health of a single dependency
type DependencyHealth struct {
	Status       string    `json:"status"` // "healthy", "unhealthy", "timeout"
	LastCheck    time.Time `json:"last_check"`
	ResponseTime int64     `json:"response_time_ms"`
	Error        string    `json:"error,omitempty"`
}

// HealthChecker provides health check functionality
type HealthChecker struct {
	db              database.DatabaseClient
	redis           redis.Cmdable
	logger          *zap.Logger
	startTime       time.Time
	checkTimeout    time.Duration
	cacheTTL        time.Duration
	lastCheckResult *HealthCheckResponse
	mu              sync.RWMutex
}

// NewHealthChecker creates a new health checker
func NewHealthChecker(
	db database.DatabaseClient,
	redisClient redis.Cmdable,
	logger *zap.Logger,
) *HealthChecker {
	return &HealthChecker{
		db:           db,
		redis:        redisClient,
		logger:       logger,
		startTime:    time.Now(),
		checkTimeout: 5 * time.Second,
		cacheTTL:     30 * time.Second,
	}
}

// Check performs a comprehensive health check
func (hc *HealthChecker) Check(ctx context.Context) *HealthCheckResponse {
	return hc.performHealthCheck(ctx)
}

// Handler is the HTTP handler for health checks
func (hc *HealthChecker) Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), hc.checkTimeout)
		defer cancel()

		health := hc.performHealthCheck(ctx)

		// Set status code based on health status
		status := http.StatusOK
		if health.Status == StatusDegraded {
			status = http.StatusOK // Still OK, but inform client
		} else if health.Status == StatusUnhealthy {
			status = http.StatusServiceUnavailable
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		json.NewEncoder(w).Encode(health)
	})
}

// performHealthCheck runs all health checks
func (hc *HealthChecker) performHealthCheck(ctx context.Context) *HealthCheckResponse {
	hc.mu.Lock()
	defer hc.mu.Unlock()

	response := &HealthCheckResponse{
		Status:       StatusHealthy,
		Timestamp:    time.Now(),
		Uptime:       int64(time.Since(hc.startTime).Seconds()),
		Version:      "1.0.0",
		Dependencies: make(map[string]DependencyHealth),
		Metrics:      make(map[string]interface{}),
	}

	// Check database
	dbHealth := hc.checkDatabase(ctx)
	response.Dependencies["database"] = dbHealth
	if dbHealth.Status == "unhealthy" {
		response.Status = StatusUnhealthy
	} else if dbHealth.Status == "timeout" && response.Status == StatusHealthy {
		response.Status = StatusDegraded
	}

	// Check Redis
	redisHealth := hc.checkRedis(ctx)
	response.Dependencies["redis"] = redisHealth
	if redisHealth.Status == "unhealthy" {
		response.Status = StatusDegraded // Redis is not critical
	}

	// Check database connection pool health
	poolHealth := hc.checkDatabasePool()
	response.Metrics["database_pool"] = poolHealth

	// Check system metrics
	response.Metrics["goroutines"] = getRuntimeMetrics()

	hc.lastCheckResult = response
	return response
}

// checkDatabase pings the database and measures response time
func (hc *HealthChecker) checkDatabase(ctx context.Context) DependencyHealth {
	health := DependencyHealth{
		Status:    "healthy",
		LastCheck: time.Now(),
	}

	start := time.Now()
	err := hc.db.Ping(ctx)
	health.ResponseTime = time.Since(start).Milliseconds()

	if err != nil && err == context.DeadlineExceeded {
		health.Status = "timeout"
		health.Error = "Database ping timeout"
	} else if err != nil {
		health.Status = "unhealthy"
		health.Error = err.Error()
		hc.logger.Error("database health check failed", zap.Error(err))
	}

	if health.ResponseTime > 1000 {
		hc.logger.Warn("slow database response",
			zap.Int64("response_time_ms", health.ResponseTime),
		)
	}

	return health
}

// checkRedis pings Redis and measures response time
func (hc *HealthChecker) checkRedis(ctx context.Context) DependencyHealth {
	health := DependencyHealth{
		Status:    "healthy",
		LastCheck: time.Now(),
	}

	start := time.Now()
	err := hc.redis.Ping(ctx).Err()
	health.ResponseTime = time.Since(start).Milliseconds()

	if err != nil && err == context.DeadlineExceeded {
		health.Status = "timeout"
		health.Error = "Redis ping timeout"
	} else if err != nil {
		health.Status = "unhealthy"
		health.Error = err.Error()
		hc.logger.Error("redis health check failed", zap.Error(err))
	}

	return health
}

// checkDatabasePool returns connection pool statistics
func (hc *HealthChecker) checkDatabasePool() map[string]interface{} {
	pool := hc.db.Pool()
	if pool == nil {
		return nil
	}

	stats := pool.Stat()
	percentUsed := float64(stats.AcquiredConns()) / float64(stats.MaxConns()) * 100

	status := "healthy"
	if percentUsed > 80 {
		status = "warning"
	}
	if percentUsed > 95 {
		status = "critical"
	}

	return map[string]interface{}{
		"status":               status,
		"max_connections":      stats.MaxConns(),
		"acquired_connections": stats.AcquiredConns(),
		"idle_connections":     stats.IdleConns(),
		"percent_used":         fmt.Sprintf("%.2f%%", percentUsed),
	}
}

// getRuntimeMetrics returns current goroutine count
func getRuntimeMetrics() map[string]interface{} {
	return map[string]interface{}{
		"count": getRuntimeGoroutines(),
	}
}

// getRuntimeGoroutines returns current goroutine count
func getRuntimeGoroutines() int {
	// import "runtime"
	// return runtime.NumGoroutine()
	// For now, return placeholder
	return 0
}

// Liveness probe - returns 200 if service is running
func (hc *HealthChecker) LivenessProbe() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "alive"})
	})
}

// Readiness probe - returns 200 only if ready to serve traffic
func (hc *HealthChecker) ReadinessProbe() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		health := hc.performHealthCheck(ctx)

		status := http.StatusOK
		if health.Status != StatusHealthy {
			status = http.StatusServiceUnavailable
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"ready":  health.Status == StatusHealthy,
			"status": health.Status,
		})
	})
}
