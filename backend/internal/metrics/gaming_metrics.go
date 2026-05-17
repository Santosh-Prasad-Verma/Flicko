package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// Gaming Hub Prometheus Metrics
var (
	// StockfishMetrics tracks chess bot performance
	StockfishTimeouts = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_stockfish_timeouts_total",
			Help: "Total number of Stockfish engine timeouts",
		},
		[]string{"game_id"},
	)

	StockfishMoveLatency = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "flicko_stockfish_move_latency_seconds",
			Help:    "Latency of Stockfish move generation",
			Buckets: []float64{0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0},
		},
	)

	StockfishPoolSize = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "flicko_stockfish_pool_size",
			Help: "Current size of the Stockfish worker pool",
		},
	)

	StockfishPoolExhausted = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "flicko_stockfish_pool_exhausted_total",
			Help: "Total times the Stockfish pool was exhausted",
		},
	)

	// MatchmakingMetrics tracks queue performance
	MatchmakingQueueSize = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "flicko_matchmaking_queue_size",
			Help: "Current size of matchmaking queues",
		},
		[]string{"game_type"},
	)

	MatchmakingWaitTime = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "flicko_matchmaking_wait_time_seconds",
			Help:    "Time players wait in matchmaking queue",
			Buckets: []float64{1, 5, 10, 30, 60, 120, 300, 600},
		},
		[]string{"game_type"},
	)

	MatchmakingMatchesCreated = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_matchmaking_matches_created_total",
			Help: "Total matches created through matchmaking",
		},
		[]string{"game_type"},
	)

	// GameStateMetrics tracks game persistence
	DBFlushLatency = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "flicko_db_flush_latency_seconds",
			Help:    "Latency of pgx.CopyFrom batch flushes",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0},
		},
		[]string{"status"},
	)

	DBFlushBatchSize = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "flicko_db_flush_batch_size",
			Help:    "Number of records per batch flush",
			Buckets: []float64{1, 5, 10, 25, 50, 100, 250, 500, 1000},
		},
	)

	DBBufferCapacity = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "flicko_db_buffer_capacity",
			Help: "Current capacity of the game state buffer channel",
		},
	)

	// RateLimitMetrics tracks throttling
	RateLimitHits = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_rate_limit_hits_total",
			Help: "Total rate limit rejections",
		},
		[]string{"limiter_name", "endpoint"},
	)

	RateLimitCheckLatency = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "flicko_rate_limit_check_latency_seconds",
			Help:    "Latency of rate limit checks (Redis)",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1},
		},
	)

	// LockMetrics tracks distributed lock performance
	LockAcquisitionTime = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "flicko_lock_acquisition_seconds",
			Help:    "Time to acquire distributed locks",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25},
		},
	)

	LockContentions = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "flicko_lock_contentions_total",
			Help: "Total lock acquisition failures due to contention",
		},
	)

	// GameMetrics tracks gameplay statistics
	GamesStarted = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_games_started_total",
			Help: "Total games started",
		},
		[]string{"game_type"},
	)

	GamesCompleted = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_games_completed_total",
			Help: "Total games completed",
		},
		[]string{"game_type", "reason"},
	)

	ActiveGames = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "flicko_active_games",
			Help: "Current number of active games",
		},
	)

	MovesProcessed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_moves_processed_total",
			Help: "Total moves processed",
		},
		[]string{"game_type"},
	)

	MoveValidationErrors = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_move_validation_errors_total",
			Help: "Total invalid move attempts",
		},
		[]string{"game_type", "error_type"},
	)

	// AbandonmentMetrics tracks player disconnections
	AbandonmentMarkers = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "flicko_abandonment_markers_current",
			Help: "Current number of active abandonment markers",
		},
	)

	GamesForfeited = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "flicko_games_forfeited_abandonment_total",
			Help: "Total games forfeited due to abandonment",
		},
	)

	// ELOMetrics tracks rating changes
	ELOUpdates = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "flicko_elo_updates_total",
			Help: "Total ELO rating updates",
		},
	)

	// RNGMetrics tracks dice rolls
	DiceRolls = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_dice_rolls_total",
			Help: "Total dice rolls (Ludo)",
		},
		[]string{"sides"},
	)

	// BotMetrics tracks AI performance
	BotMovesQueued = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_bot_moves_queued_total",
			Help: "Total bot moves queued via Asynq",
		},
		[]string{"game_type"},
	)

	BotMovesProcessed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_bot_moves_processed_total",
			Help: "Total bot moves successfully processed",
		},
		[]string{"game_type"},
	)

	BotMoveErrors = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_bot_move_errors_total",
			Help: "Total bot move processing errors",
		},
		[]string{"game_type", "error_type"},
	)

	// WebSocketMetrics tracks Centrifugo performance
	WebSocketConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "flicko_websocket_connections_current",
			Help: "Current WebSocket connections to gaming hub",
		},
	)

	WebSocketMessagesPublished = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "flicko_websocket_messages_published_total",
			Help: "Total messages published via Centrifugo",
		},
		[]string{"channel_type"},
	)

	WebSocketSubscriptionRejected = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "flicko_websocket_subscriptions_rejected_total",
			Help: "Total rejected subscription attempts",
		},
	)
)

// RecordStockfishTimeout increments the timeout counter for a game
func RecordStockfishTimeout(gameID string) {
	StockfishTimeouts.WithLabelValues(gameID).Inc()
}

// RecordMatchmakingMatch increments match counter
func RecordMatchmakingMatch(gameType string) {
	MatchmakingMatchesCreated.WithLabelValues(gameType).Inc()
}

// RecordGameStart increments game start counter
func RecordGameStart(gameType string) {
	GamesStarted.WithLabelValues(gameType).Inc()
}

// RecordGameCompletion increments game completion counter
func RecordGameCompletion(gameType, reason string) {
	GamesCompleted.WithLabelValues(gameType, reason).Inc()
}

// RecordMoveProcessed increments move counter
func RecordMoveProcessed(gameType string) {
	MovesProcessed.WithLabelValues(gameType).Inc()
}

// RecordMoveValidationError increments error counter
func RecordMoveValidationError(gameType, errorType string) {
	MoveValidationErrors.WithLabelValues(gameType, errorType).Inc()
}

// RecordBotMoveQueued increments bot queue counter
func RecordBotMoveQueued(gameType string) {
	BotMovesQueued.WithLabelValues(gameType).Inc()
}

// RecordBotMoveProcessed increments bot success counter
func RecordBotMoveProcessed(gameType string) {
	BotMovesProcessed.WithLabelValues(gameType).Inc()
}

// RecordBotMoveError increments bot error counter
func RecordBotMoveError(gameType, errorType string) {
	BotMoveErrors.WithLabelValues(gameType, errorType).Inc()
}

// ObserveStockfishLatency records move generation time
func ObserveStockfishLatency(seconds float64) {
	StockfishMoveLatency.Observe(seconds)
}

// ObserveMatchmakingWaitTime records queue wait time
func ObserveMatchmakingWaitTime(gameType string, seconds float64) {
	MatchmakingWaitTime.WithLabelValues(gameType).Observe(seconds)
}

// ObserveDBFlush records batch flush metrics
func ObserveDBFlush(status string, latencySeconds float64, batchSize int) {
	DBFlushLatency.WithLabelValues(status).Observe(latencySeconds)
	DBFlushBatchSize.Observe(float64(batchSize))
}

// ObserveLockAcquisition records lock acquisition time
func ObserveLockAcquisition(seconds float64) {
	LockAcquisitionTime.Observe(seconds)
}

// ObserveRateLimitCheck records rate limit check time
func ObserveRateLimitCheck(seconds float64) {
	RateLimitCheckLatency.Observe(seconds)
}
