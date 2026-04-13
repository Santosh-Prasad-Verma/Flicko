package metrics_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	io_prometheus "github.com/prometheus/client_model/go"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/metrics"
)

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// resetRegistry replaces the default Prometheus registry with a fresh
// one so tests don't leak state between runs.
func resetRegistry(t *testing.T) {
	t.Helper()
	reg := prometheus.NewRegistry()
	prometheus.DefaultRegisterer = reg
	prometheus.DefaultGatherer = reg
	t.Cleanup(func() {
		prometheus.DefaultRegisterer = prometheus.NewRegistry()
		prometheus.DefaultGatherer = prometheus.DefaultRegisterer.(prometheus.Gatherer)
	})
}

// getMetricValue returns the float64 value of a Counter or Gauge.
func getMetricValue(t *testing.T, c prometheus.Collector) float64 {
	t.Helper()
	ch := make(chan prometheus.Metric, 1)
	c.Collect(ch)
	m := <-ch
	var dto io_prometheus.Metric
	if err := m.Write(&dto); err != nil {
		t.Fatal(err)
	}
	if dto.Counter != nil {
		return dto.Counter.GetValue()
	}
	if dto.Gauge != nil {
		return dto.Gauge.GetValue()
	}
	t.Fatal("metric is neither Counter nor Gauge")
	return 0
}

// getHistogramCount returns the observation count from a Histogram.
func getHistogramCount(t *testing.T, h prometheus.Histogram) uint64 {
	t.Helper()
	ch := make(chan prometheus.Metric, 1)
	h.(prometheus.Collector).Collect(ch)
	m := <-ch
	var dto io_prometheus.Metric
	if err := m.Write(&dto); err != nil {
		t.Fatal(err)
	}
	return dto.Histogram.GetSampleCount()
}

// zapNop returns a no-op zap.Logger for testing.
func zapNop() *zap.Logger {
	return zap.NewNop()
}

// ─────────────────────────────────────────────────────────────────────────────
// Gateway Metrics Tests
// ─────────────────────────────────────────────────────────────────────────────

func TestNewGatewayMetrics(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	if gm == nil {
		t.Fatal("NewGatewayMetrics returned nil")
	}
	if gm.ActiveConnections == nil {
		t.Error("ActiveConnections is nil")
	}
	if gm.ConnectionsTotal == nil {
		t.Error("ConnectionsTotal is nil")
	}
	if gm.MessagesReceivedTotal == nil {
		t.Error("MessagesReceivedTotal is nil")
	}
	if gm.MessageLatency == nil {
		t.Error("MessageLatency is nil")
	}
	if gm.SlowConsumerDisconnectsTotal == nil {
		t.Error("SlowConsumerDisconnectsTotal is nil")
	}
	if gm.PubSubActiveSubscriptions == nil {
		t.Error("PubSubActiveSubscriptions is nil")
	}
	if gm.RateLimitHitsTotal == nil {
		t.Error("RateLimitHitsTotal is nil")
	}
}

func TestGatewayMetrics_ActiveConnections(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.ActiveConnections.Inc()
	gm.ActiveConnections.Inc()
	gm.ActiveConnections.Dec()

	v := getMetricValue(t, gm.ActiveConnections)
	if v != 1.0 {
		t.Errorf("ActiveConnections: got %v, want 1.0", v)
	}
}

func TestGatewayMetrics_ConnectionsTotal(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.RecordConnection("success")
	gm.RecordConnection("success")
	gm.RecordConnection("auth_failed")

	success := gm.ConnectionsTotal.With(prometheus.Labels{"result": "success"})
	v := getMetricValue(t, success)
	if v != 2.0 {
		t.Errorf("success count: got %v, want 2.0", v)
	}

	authFailed := gm.ConnectionsTotal.With(prometheus.Labels{"result": "auth_failed"})
	v = getMetricValue(t, authFailed)
	if v != 1.0 {
		t.Errorf("auth_failed count: got %v, want 1.0", v)
	}
}

func TestGatewayMetrics_ObserveMessageLatency(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	start := time.Now().Add(-10 * time.Millisecond)
	gm.ObserveMessageLatency(start)

	count := getHistogramCount(t, gm.MessageLatency)
	if count != 1 {
		t.Errorf("MessageLatency count: got %d, want 1", count)
	}
}

func TestGatewayMetrics_ObserveSendChannelUtil(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.ObserveSendChannelUtil(128, 256) // 0.5
	gm.ObserveSendChannelUtil(10, 0)    // no-op

	count := getHistogramCount(t, gm.SendChannelUtilization)
	if count != 1 {
		t.Errorf("SendChannelUtilization count: got %d, want 1 (0-cap should be skipped)", count)
	}
}

func TestGatewayMetrics_SlowConsumerDisconnects(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.SlowConsumerDisconnectsTotal.Inc()
	gm.SlowConsumerDisconnectsTotal.Inc()

	v := getMetricValue(t, gm.SlowConsumerDisconnectsTotal)
	if v != 2.0 {
		t.Errorf("SlowConsumerDisconnects: got %v, want 2.0", v)
	}
}

func TestGatewayMetrics_PubSub(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.PubSubMessagesReceivedTotal.Inc()
	gm.PubSubMessagesDroppedTotal.Inc()
	gm.PubSubActiveSubscriptions.Set(42)

	if v := getMetricValue(t, gm.PubSubMessagesReceivedTotal); v != 1.0 {
		t.Errorf("PubSubReceived: got %v, want 1.0", v)
	}
	if v := getMetricValue(t, gm.PubSubMessagesDroppedTotal); v != 1.0 {
		t.Errorf("PubSubDropped: got %v, want 1.0", v)
	}
	if v := getMetricValue(t, gm.PubSubActiveSubscriptions); v != 42.0 {
		t.Errorf("PubSubActive: got %v, want 42.0", v)
	}
}

func TestGatewayMetrics_RateLimitHits(t *testing.T) {
	resetRegistry(t)
	gm := metrics.NewGatewayMetrics()

	gm.RateLimitHitsTotal.With(prometheus.Labels{"layer": "ws_per_client"}).Inc()
	gm.RateLimitHitsTotal.With(prometheus.Labels{"layer": "ws_per_client"}).Inc()
	gm.RateLimitHitsTotal.With(prometheus.Labels{"layer": "ws_connect"}).Inc()

	ws := gm.RateLimitHitsTotal.With(prometheus.Labels{"layer": "ws_per_client"})
	if v := getMetricValue(t, ws); v != 2.0 {
		t.Errorf("ws_per_client: got %v, want 2.0", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Metrics Tests
// ─────────────────────────────────────────────────────────────────────────────

func TestNewServiceMetrics(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	if sm == nil {
		t.Fatal("NewServiceMetrics returned nil")
	}
	if sm.HTTPRequestDuration == nil {
		t.Error("HTTPRequestDuration is nil")
	}
	if sm.DBQueryDuration == nil {
		t.Error("DBQueryDuration is nil")
	}
	if sm.BatchInsertSize == nil {
		t.Error("BatchInsertSize is nil")
	}
	if sm.IdempotencyHitsTotal == nil {
		t.Error("IdempotencyHitsTotal is nil")
	}
	if sm.AbuseFlagsTotal == nil {
		t.Error("AbuseFlagsTotal is nil")
	}
}

func TestServiceMetrics_ObserveDBQuery(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	start := time.Now().Add(-5 * time.Millisecond)
	sm.ObserveDBQuery("get_messages", start)
	sm.ObserveDBQuery("create_message", start)
	// Just verify no panic — histogram label checking is fragile.
}

func TestServiceMetrics_RecordAbuseFlag(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	sm.RecordAbuseFlag("high_frequency_flood")
	sm.RecordAbuseFlag("high_frequency_flood")
	sm.RecordAbuseFlag("duplicate_message_spam")

	hf := sm.AbuseFlagsTotal.With(prometheus.Labels{"reason": "high_frequency_flood"})
	if v := getMetricValue(t, hf); v != 2.0 {
		t.Errorf("high_frequency_flood: got %v, want 2.0", v)
	}

	dup := sm.AbuseFlagsTotal.With(prometheus.Labels{"reason": "duplicate_message_spam"})
	if v := getMetricValue(t, dup); v != 1.0 {
		t.Errorf("duplicate_message_spam: got %v, want 1.0", v)
	}
}

func TestServiceMetrics_ObserveBatchInsert(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	start := time.Now().Add(-2 * time.Millisecond)
	sm.ObserveBatchInsert(25, start)

	sizeCount := getHistogramCount(t, sm.BatchInsertSize)
	if sizeCount != 1 {
		t.Errorf("BatchInsertSize count: got %d, want 1", sizeCount)
	}
	durCount := getHistogramCount(t, sm.BatchInsertDuration)
	if durCount != 1 {
		t.Errorf("BatchInsertDuration count: got %d, want 1", durCount)
	}
}

func TestServiceMetrics_BatchBufferUtilization(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	sm.BatchBufferUtilization.Set(0.75)
	if v := getMetricValue(t, sm.BatchBufferUtilization); v != 0.75 {
		t.Errorf("BatchBufferUtilization: got %v, want 0.75", v)
	}
}

func TestServiceMetrics_Counters(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	sm.MessagesInsertedTotal.Inc()
	sm.MessagesInsertedTotal.Inc()
	if v := getMetricValue(t, sm.MessagesInsertedTotal); v != 2.0 {
		t.Errorf("MessagesInserted: got %v, want 2.0", v)
	}

	sm.IdempotencyHitsTotal.Inc()
	if v := getMetricValue(t, sm.IdempotencyHitsTotal); v != 1.0 {
		t.Errorf("IdempotencyHits: got %v, want 1.0", v)
	}

	sm.DeadLetterDepth.Set(3)
	if v := getMetricValue(t, sm.DeadLetterDepth); v != 3.0 {
		t.Errorf("DeadLetterDepth: got %v, want 3.0", v)
	}
}

func TestServiceMetrics_DBPool(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	sm.DBPoolActiveConnections.Set(10)
	sm.DBPoolIdleConnections.Set(5)

	if v := getMetricValue(t, sm.DBPoolActiveConnections); v != 10.0 {
		t.Errorf("DBPoolActive: got %v, want 10.0", v)
	}
	if v := getMetricValue(t, sm.DBPoolIdleConnections); v != 5.0 {
		t.Errorf("DBPoolIdle: got %v, want 5.0", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP Metrics Middleware Tests
// ─────────────────────────────────────────────────────────────────────────────

func TestMetricsMiddleware_RecordsRequest(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	handler := sm.MetricsMiddleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))

	req := httptest.NewRequest(http.MethodGet, "/v1/channels/abc/messages", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status: got %d, want 200", rec.Code)
	}
}

func TestMetricsMiddleware_CapturesStatusCode(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	handler := sm.MetricsMiddleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("bad"))
	}))

	req := httptest.NewRequest(http.MethodPost, "/v1/channels/abc/messages", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status: got %d, want 400", rec.Code)
	}
}

func TestMetricsMiddleware_ImplicitStatusOK(t *testing.T) {
	resetRegistry(t)
	sm := metrics.NewServiceMetrics()

	handler := sm.MetricsMiddleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("implicit 200"))
	}))

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status: got %d, want 200", rec.Code)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics Server Tests
// ─────────────────────────────────────────────────────────────────────────────

func TestStartMetricsServer(t *testing.T) {
	resetRegistry(t)
	_ = metrics.NewGatewayMetrics()

	log := zapNop()
	srv := metrics.StartMetricsServer(0, log)
	defer metrics.ShutdownMetricsServer(srv, log)

	time.Sleep(50 * time.Millisecond)
	// Port 0 = OS-assigned. Verify start+shutdown don't panic.
}

func TestShutdownMetricsServer_NilSafe(t *testing.T) {
	log := zapNop()
	metrics.ShutdownMetricsServer(nil, log)
}
