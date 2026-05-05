package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// StockfishTimeouts tracks how often the bot engine fails to return a move in time
	StockfishTimeouts = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gaming_hub_stockfish_timeouts_total",
			Help: "Total number of Stockfish engine timeouts forcing a random move fallback",
		},
		[]string{"game_type"},
	)

	// DBFlushLatency tracks the latency of the pgx.CopyFrom bulk insert worker
	DBFlushLatency = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "gaming_hub_db_flush_latency_seconds",
			Help:    "Latency of game state bulk inserts to PostgreSQL via pgx.CopyFrom",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"status"},
	)

	// RateLimitHits tracks how often users hit the Token Bucket rate limit
	RateLimitHits = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gaming_hub_rate_limit_hits_total",
			Help: "Total number of requests rejected by the distributed Lua rate limiter",
		},
		[]string{"endpoint"},
	)

	// MovesProcessed tracks the throughput of the validation engine
	MovesProcessed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "gaming_hub_moves_processed_total",
			Help: "Total number of game moves processed",
		},
		[]string{"game_type", "status"}, // status: "accepted", "rejected"
	)
)
