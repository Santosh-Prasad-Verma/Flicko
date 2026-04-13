package metrics

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Metrics HTTP server
// ─────────────────────────────────────────────────────────────────────────────
//
// Exposes /metrics on a dedicated port, separate from the main API
// server. Standard practice:
//   - ws-gateway  → :9100
//   - msg-service → :9101
//
// The server automatically includes Go runtime metrics (goroutines,
// GC, memory) and process metrics (open FDs, CPU time) via the
// default Prometheus registry.

// StartMetricsServer starts an HTTP server that serves Prometheus
// metrics on the given port. It returns the *http.Server so the
// caller can shut it down gracefully.
//
// Usage:
//
//	srv := metrics.StartMetricsServer(9100, log)
//	defer srv.Shutdown(ctx)
//
// The server exposes:
//   - GET /metrics  — Prometheus scrape endpoint
//   - GET /healthz  — simple liveness probe (always 200)
func StartMetricsServer(port int, log *zap.Logger) *http.Server {
	mux := http.NewServeMux()

	// Prometheus scrape endpoint with the default handler.
	// This automatically includes:
	//   - All promauto-registered collectors (gateway/service metrics)
	//   - Go runtime metrics (go_goroutines, go_gc_*, go_memstats_*)
	//   - Process metrics (process_cpu_*, process_open_fds, process_resident_memory_*)
	mux.Handle("/metrics", promhttp.Handler())

	// Simple liveness check for load balancers and orchestrators.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	addr := fmt.Sprintf(":%d", port)
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second, // Prometheus scrapes can be slow
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Info("metrics server starting", zap.String("addr", addr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("metrics server failed", zap.Error(err))
		}
	}()

	return srv
}

// ShutdownMetricsServer gracefully drains the metrics server with a
// 5-second timeout. Safe to call with a nil server.
func ShutdownMetricsServer(srv *http.Server, log *zap.Logger) {
	if srv == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Warn("metrics server shutdown error", zap.Error(err))
	} else {
		log.Info("metrics server stopped")
	}
}
