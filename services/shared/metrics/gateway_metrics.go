// Package metrics provides Prometheus instrumentation for Flicko's
// Go services. It is split into two collector sets:
//
//   - GatewayMetrics  — WebSocket gateway (connections, messages, pub/sub)
//   - ServiceMetrics  — Message service  (HTTP requests, DB, batching)
//
// All collectors use promauto so they self-register with the default
// Prometheus registry. Call StartMetricsServer to expose /metrics.
//
// Usage (gateway):
//
//	gm := metrics.NewGatewayMetrics()
//	gm.ActiveConnections.Inc()
//	gm.ObserveMessageLatency(start)
//
// Usage (msg-service):
//
//	sm := metrics.NewServiceMetrics()
//	router.Use(sm.MetricsMiddleware)
//	sm.ObserveDBQuery("get_messages", start)
package metrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// ─────────────────────────────────────────────────────────────────────────────
// GatewayMetrics — WebSocket Gateway Prometheus collectors
// ─────────────────────────────────────────────────────────────────────────────
//
// Naming convention: flicko_ws_*, flicko_pubsub_*, flicko_rate_limit_*
// All metrics are registered with promauto (default registry).

// GatewayMetrics holds every Prometheus collector for the WS gateway.
type GatewayMetrics struct {
	// ── Connections ──────────────────────────────────────────

	// ActiveConnections is the number of currently connected WebSocket
	// clients. Incremented on register, decremented on unregister.
	ActiveConnections prometheus.Gauge

	// ConnectionsTotal is the cumulative count of connection attempts.
	// The "result" label distinguishes outcomes:
	//   - "success"           — authenticated and registered
	//   - "auth_failed"       — JWT validation failed
	//   - "rate_limited"      — connection-level rate limit hit
	//   - "upgrade_failed"    — HTTP → WS upgrade failed
	ConnectionsTotal *prometheus.CounterVec

	// ── Messages ────────────────────────────────────────────

	// MessagesReceivedTotal is the number of WebSocket frames read from
	// clients (after rate-limit pass, before dispatch).
	MessagesReceivedTotal prometheus.Counter

	// MessagesDeliveredTotal is the number of messages successfully
	// written to client send channels via FanoutToChannel.
	MessagesDeliveredTotal prometheus.Counter

	// MessageLatency measures end-to-end latency from when a message
	// is received from a client to when it is fanned out to subscribers.
	// Buckets chosen for real-time messaging: 5ms → 1s.
	MessageLatency prometheus.Histogram

	// ── Slow consumers ──────────────────────────────────────

	// SlowConsumerDisconnectsTotal is the count of clients forcibly
	// disconnected because their send channel was full.
	SlowConsumerDisconnectsTotal prometheus.Counter

	// SendChannelUtilization observes the ratio (current / capacity)
	// of client send channels at the time of a fanout write. High
	// values indicate clients approaching slow-consumer thresholds.
	SendChannelUtilization prometheus.Histogram

	// ── Pub/Sub ─────────────────────────────────────────────

	// PubSubMessagesReceivedTotal is the number of messages received
	// from Redis Pub/Sub (before fanout to local clients).
	PubSubMessagesReceivedTotal prometheus.Counter

	// PubSubMessagesDroppedTotal is the number of Pub/Sub messages
	// that could not be delivered (worker queue full, decode error).
	PubSubMessagesDroppedTotal prometheus.Counter

	// PubSubActiveSubscriptions is the number of Redis Pub/Sub
	// channels this gateway instance is currently subscribed to.
	PubSubActiveSubscriptions prometheus.Gauge

	// ── Rate limiting ───────────────────────────────────────

	// RateLimitHitsTotal counts rate-limit rejections by layer.
	// The "layer" label distinguishes:
	//   - "ws_per_client"   — per-connection message rate limit
	//   - "ws_connect"      — connection-level rate limit
	//   - "api_general"     — HTTP API general tier (msg-service)
	//   - "api_per_route"   — HTTP API per-route tier (msg-service)
	RateLimitHitsTotal *prometheus.CounterVec
}

// NewGatewayMetrics creates and registers all WS gateway Prometheus
// collectors. Call once at gateway startup.
func NewGatewayMetrics() *GatewayMetrics {
	return &GatewayMetrics{
		// ── Connections ──────────────────────────────────
		ActiveConnections: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_ws_active_connections",
			Help: "Number of currently connected WebSocket clients.",
		}),
		ConnectionsTotal: promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "flicko_ws_connections_total",
			Help: "Cumulative WebSocket connection attempts by result.",
		}, []string{"result"}),

		// ── Messages ────────────────────────────────────
		MessagesReceivedTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_ws_messages_received_total",
			Help: "Total WebSocket frames received from clients.",
		}),
		MessagesDeliveredTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_ws_messages_delivered_total",
			Help: "Total messages delivered to client send channels.",
		}),
		MessageLatency: promauto.NewHistogram(prometheus.HistogramOpts{
			Name: "flicko_ws_message_latency_seconds",
			Help: "End-to-end message latency from receive to fanout.",
			// 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s
			Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0},
		}),

		// ── Slow consumers ──────────────────────────────
		SlowConsumerDisconnectsTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_ws_slow_consumer_disconnects_total",
			Help: "Clients forcibly disconnected due to full send channel.",
		}),
		SendChannelUtilization: promauto.NewHistogram(prometheus.HistogramOpts{
			Name: "flicko_ws_send_channel_utilization",
			Help: "Send channel utilization ratio (0.0–1.0) at fanout time.",
			// 10%, 25%, 50%, 75%, 90%, 95%, 100%
			Buckets: []float64{0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 1.0},
		}),

		// ── Pub/Sub ─────────────────────────────────────
		PubSubMessagesReceivedTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_pubsub_messages_received_total",
			Help: "Messages received from Redis Pub/Sub.",
		}),
		PubSubMessagesDroppedTotal: promauto.NewCounter(prometheus.CounterOpts{
			Name: "flicko_pubsub_messages_dropped_total",
			Help: "Pub/Sub messages dropped (queue full or decode error).",
		}),
		PubSubActiveSubscriptions: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "flicko_pubsub_active_subscriptions",
			Help: "Redis Pub/Sub channels this gateway is subscribed to.",
		}),

		// ── Rate limiting ───────────────────────────────
		RateLimitHitsTotal: promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "flicko_rate_limit_hits_total",
			Help: "Rate-limit rejections by layer.",
		}, []string{"layer"}),
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

// ObserveMessageLatency records the duration since start as a message
// latency observation. Intended to be called as:
//
//	start := time.Now()
//	// ... process + fanout ...
//	gm.ObserveMessageLatency(start)
func (g *GatewayMetrics) ObserveMessageLatency(start time.Time) {
	g.MessageLatency.Observe(time.Since(start).Seconds())
}

// ObserveSendChannelUtil records the current utilization ratio of a
// client's send channel. Call this in FanoutToChannel after a
// successful (non-blocking) send:
//
//	gm.ObserveSendChannelUtil(len(client.Send), cap(client.Send))
func (g *GatewayMetrics) ObserveSendChannelUtil(current, capacity int) {
	if capacity <= 0 {
		return
	}
	g.SendChannelUtilization.Observe(float64(current) / float64(capacity))
}

// RecordConnection increments the connection counter with the given
// result label. Standard result values:
//
//	"success", "auth_failed", "rate_limited", "upgrade_failed"
func (g *GatewayMetrics) RecordConnection(result string) {
	g.ConnectionsTotal.With(prometheus.Labels{"result": result}).Inc()
}
