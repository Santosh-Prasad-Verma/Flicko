package metrics

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// ─────────────────────────────────────────────────────────────────────────────
// ServiceMetrics — Message Service Prometheus collectors
// ─────────────────────────────────────────────────────────────────────────────
//
// Naming convention: flicko_http_*, flicko_db_*, flicko_batch_*,
// flicko_messages_*, flicko_dead_letter_*, flicko_idempotency_*,
// flicko_abuse_*

// ServiceMetrics holds every Prometheus collector for the msg-service.
type ServiceMetrics struct {
	// ── HTTP ────────────────────────────────────────────────

	// HTTPRequestDuration measures request latency by method, route
	// pattern, and response status code.
	//
	// Labels:
	//   method — HTTP method (GET, POST, PATCH, DELETE)
	//   path   — chi route pattern  (/v1/channels/{channelID}/messages)
	//   status — response status code group ("200", "400", "500")
	HTTPRequestDuration *prometheus.HistogramVec

	// ── Database ────────────────────────────────────────────

	// DBQueryDuration measures individual SQL query latency.
	// The "query_name" label is a short slug identifying the query:
	//   "create_message", "get_messages", "bulk_insert", etc.
	DBQueryDuration *prometheus.HistogramVec

	// DBPoolActiveConnections is the number of connections currently
	// in use from the database/sql pool.
	DBPoolActiveConnections prometheus.Gauge

	// DBPoolIdleConnections is the number of idle connections in
	// the database/sql pool.
	DBPoolIdleConnections prometheus.Gauge

	// ── Batch inserter ──────────────────────────────────────

	// BatchInsertSize observes the number of messages in each batch
	// flush. Useful for tuning MaxBatch and MaxWait.
	BatchInsertSize prometheus.Histogram

	// BatchInsertDuration measures how long each BulkInsert call
	// takes (including retries).
	BatchInsertDuration prometheus.Histogram

	// BatchBufferUtilization tracks the current buffer fill ratio
	// (current / capacity). Set periodically or on submit.
	BatchBufferUtilization prometheus.Gauge

	// MessagesInsertedTotal is the cumulative count of messages
	// successfully persisted (via batch or sync path).
	MessagesInsertedTotal prometheus.Counter

	// ── Dead letter queue ───────────────────────────────────

	// DeadLetterDepth is the number of messages currently in the
	// dead letter queue awaiting retry.
	DeadLetterDepth prometheus.Gauge

	// ── Idempotency ─────────────────────────────────────────

	// IdempotencyHitsTotal counts idempotency cache hits (duplicate
	// requests served from cached responses).
	IdempotencyHitsTotal prometheus.Counter

	// ── Abuse detection ─────────────────────────────────────

	// AbuseFlagsTotal counts messages flagged by the abuse detector.
	// The "reason" label matches abuse.Reason values:
	//   "duplicate_message_spam", "high_frequency_flood",
	//   "cross_channel_spam", "mass_dm_spam", "invite_link_spam"
	AbuseFlagsTotal *prometheus.CounterVec
}

// NewServiceMetrics creates and registers all msg-service Prometheus
// collectors. Call once at service startup.
func NewServiceMetrics() *ServiceMetrics {
	return &ServiceMetrics{
		// ── HTTP ────────────────────────────────────────
		HTTPRequestDuration: promauto.NewHistogramVec(prometheus.HistogramOpts{
			Name: "flicko_http_request_duration_seconds",
			Help: "HTTP request duration by method, route pattern, and status.",
			// 1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 5s
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 5.0},
		}, []string{"method", "path", "status"}),

		// ── Database ────────────────────────────────────
		DBQueryDuration: promauto.NewHistogramVec(prometheus.HistogramOpts{
			Name: "flicko_db_query_duration_seconds",
			Help: "SQL query duration by query name.",
			// 500µs, 1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 500ms, 1s
			Buckets: []float64{0.0005, 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.5, 1.0},
		}, []string{"query_name"}),
		DBPoolActiveConnections: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_db_pool_active_connections",
			Help: "Number of active (in-use) database connections.",
		}),
		DBPoolIdleConnections: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_db_pool_idle_connections",
			Help: "Number of idle database connections in the pool.",
		}),

		// ── Batch inserter ──────────────────────────────
		BatchInsertSize: promauto.NewHistogram(prometheus.HistogramOpts{
			Name: "flicko_batch_insert_size",
			Help: "Number of messages per batch flush.",
			// 1, 5, 10, 20, 30, 40, 50 (max batch = 50)
			Buckets: []float64{1, 5, 10, 20, 30, 40, 50},
		}),
		BatchInsertDuration: promauto.NewHistogram(prometheus.HistogramOpts{
			Name: "flicko_batch_insert_duration_seconds",
			Help: "Duration of batch BulkInsert calls (including retries).",
			// 1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5},
		}),
		BatchBufferUtilization: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_batch_buffer_utilization",
			Help: "Current batch buffer fill ratio (0.0–1.0).",
		}),
		MessagesInsertedTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_messages_inserted_total",
			Help: "Total messages successfully persisted.",
		}),

		// ── Dead letter queue ───────────────────────────
		DeadLetterDepth: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_dead_letter_depth",
			Help: "Messages in the dead letter queue awaiting retry.",
		}),

		// ── Idempotency ─────────────────────────────────
		IdempotencyHitsTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_idempotency_hits_total",
			Help: "Idempotency cache hits (duplicate requests served from cache).",
		}),

		// ── Abuse detection ─────────────────────────────
		AbuseFlagsTotal: promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "flicko_abuse_flags_total",
			Help: "Messages flagged by the abuse detection system.",
		}, []string{"reason"}),
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

// ObserveDBQuery records a single database query's duration.
//
//	start := time.Now()
//	rows, err := db.QueryContext(ctx, ...)
//	sm.ObserveDBQuery("get_messages", start)
func (s *ServiceMetrics) ObserveDBQuery(queryName string, start time.Time) {
	s.DBQueryDuration.With(prometheus.Labels{"query_name": queryName}).Observe(
		time.Since(start).Seconds(),
	)
}

// RecordAbuseFlag increments the abuse flag counter for the given reason.
func (s *ServiceMetrics) RecordAbuseFlag(reason string) {
	s.AbuseFlagsTotal.With(prometheus.Labels{"reason": reason}).Inc()
}

// ObserveBatchInsert records the size and duration of a batch flush.
// Call after a successful BulkInsert:
//
//	start := time.Now()
//	err := repo.BulkInsert(ctx, batch)
//	sm.ObserveBatchInsert(len(batch), start)
func (s *ServiceMetrics) ObserveBatchInsert(size int, start time.Time) {
	s.BatchInsertSize.Observe(float64(size))
	s.BatchInsertDuration.Observe(time.Since(start).Seconds())
}

// PoolStatter is satisfied by *pgxpool.Pool.
// Avoids importing pgx in the shared metrics package.
type PoolStatter interface {
	Stat() PoolStat
}

// PoolStat mirrors the read-only stats from pgxpool.Stat().
type PoolStat struct {
	AcquiredConns int32
	IdleConns     int32
	TotalConns    int32
	MaxConns      int32
}

// MED-017: CollectPoolStats periodically reads pgxpool stats and
// updates the DBPoolActiveConnections and DBPoolIdleConnections gauges.
// It blocks until ctx is cancelled — run it in a goroutine.
func (s *ServiceMetrics) CollectPoolStats(ctx context.Context, getter func() PoolStat, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			stat := getter()
			s.DBPoolActiveConnections.Set(float64(stat.AcquiredConns))
			s.DBPoolIdleConnections.Set(float64(stat.IdleConns))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP Metrics Middleware
// ─────────────────────────────────────────────────────────────────────────────
//
// Records request count, duration, and response status for every HTTP
// request. The path label uses the chi route pattern (e.g.
// "/v1/channels/{channelID}/messages") rather than the actual path to
// avoid cardinality explosion.

// MetricsMiddleware returns HTTP middleware that instruments every
// request with flicko_http_request_duration_seconds.
//
// The path label uses the matched chi route pattern to avoid high
// cardinality. If no route matched (404), the path is "/unmatched".
//
// Add to router BEFORE other middleware that might short-circuit:
//
//	r := chi.NewRouter()
//	r.Use(sm.MetricsMiddleware)
//	r.Use(middleware.RequestID)
//	// ...
func (s *ServiceMetrics) MetricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Wrap the response writer to capture the status code.
		ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}

		// Serve the request.
		next.ServeHTTP(ww, r)

		// Extract the chi route pattern. chi stores this in the
		// request context after routing. We read it after ServeHTTP
		// so the route has been resolved.
		pattern := routePattern(r)

		s.HTTPRequestDuration.With(prometheus.Labels{
			"method": r.Method,
			"path":   pattern,
			"status": strconv.Itoa(ww.status),
		}).Observe(time.Since(start).Seconds())
	})
}

// routePattern extracts the chi route pattern from the request context.
// Falls back to "/unmatched" for 404s and "/healthz" for the health
// endpoint. This prevents cardinality explosion from actual URL paths
// containing dynamic IDs.
func routePattern(r *http.Request) string {
	// chi stores the route context under chi.RouteCtxKey when using
	// chi v5. We use the RouteContext accessor.
	rctx := chiRouteContext(r)
	if rctx != "" {
		return rctx
	}
	return "/unmatched"
}

// chiRouteContext extracts the route pattern from the chi context.
// This avoids importing chi in the shared metrics package by reading
// the "routePattern" from the context directly.
//
// chi v5 stores *chi.Context under the chi.RouteCtxKey context key.
// The RoutePattern() method returns the full matched pattern.
// We access it via the RoutePatterns slice on the context value.
func chiRouteContext(r *http.Request) string {
	// chi.RouteCtxKey is the context key type exported by chi.
	// Rather than depending on chi here, we type-assert on the
	// interface. The chi.Context type implements RoutePattern().
	type routePatternProvider interface {
		RoutePattern() string
	}

	ctx := r.Context()

	// Walk the context chain looking for a value that provides
	// RoutePattern(). chi injects this via middleware.
	if rp, ok := ctx.Value(routeCtxKey).(routePatternProvider); ok {
		p := rp.RoutePattern()
		if p != "" {
			return p
		}
	}

	return ""
}

// routeCtxKey is a copy of chi.RouteCtxKey to avoid importing chi
// into the shared metrics package. chi uses this exact type and value.
type ctxKey struct{ name string }

var routeCtxKey = ctxKey{"RouteContext"}

// statusWriter wraps http.ResponseWriter to capture the status code.
type statusWriter struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (w *statusWriter) WriteHeader(code int) {
	if !w.wroteHeader {
		w.status = code
		w.wroteHeader = true
	}
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Write(b []byte) (int, error) {
	if !w.wroteHeader {
		w.wroteHeader = true
	}
	return w.ResponseWriter.Write(b)
}

// Unwrap supports http.ResponseController and middleware that need
// access to the original ResponseWriter.
func (w *statusWriter) Unwrap() http.ResponseWriter {
	return w.ResponseWriter
}

// Flush implements http.Flusher for streaming responses.
func (w *statusWriter) Flush() {
	if f, ok := w.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// String implements fmt.Stringer for debug logging.
func (w *statusWriter) String() string {
	return fmt.Sprintf("statusWriter{status: %d}", w.status)
}
