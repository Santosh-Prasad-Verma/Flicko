// Command server starts the Flicko Message Service (REST API).
//
// The message service is stateless and handles all CRUD operations:
// messages, channels, guilds, media presigned URLs, and serves as the
// REST fallback when clients need to fetch missed messages.
//
// Ports:
//
//	:8081  — HTTP REST API + /healthz
//	:9101  — Prometheus /metrics
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/abuse"
	"github.com/flicko-org/flicko/services/msg-service/internal/batcher"
	"github.com/flicko-org/flicko/services/msg-service/internal/handler"
	"github.com/flicko-org/flicko/services/msg-service/internal/pubsub"
	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
	"github.com/flicko-org/flicko/services/shared/config"
	"github.com/flicko-org/flicko/services/shared/logger"
	"github.com/flicko-org/flicko/services/shared/metrics"
	"github.com/flicko-org/flicko/services/shared/ratelimit"
	flickoredis "github.com/flicko-org/flicko/services/shared/redis"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// ── Logger ──────────────────────────────────────────────
	log := logger.New(envOr("ENVIRONMENT", "development") != "production")
	defer log.Sync() //nolint:errcheck

	if err := run(log); err != nil {
		log.Fatal("msg-service failed", zap.Error(err))
	}
}

func run(log *zap.Logger) error {
	log.Info("msg-service starting")

	// ── Config ──────────────────────────────────────────────
	cfg, err := config.LoadMsgServiceConfig()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	log.Info("config loaded",
		zap.Int("http_port", cfg.HTTPPort),
		zap.String("environment", cfg.Environment),
	)

	// ── Graceful-shutdown context ───────────────────────────
	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	// ── Database ────────────────────────────────────────────
	poolCfg := repository.DefaultPoolConfig()
	poolCfg.MaxConns = int32(cfg.DatabasePoolMax)
	poolCfg.MinConns = int32(cfg.DatabasePoolMin)
	dbPool, err := repository.NewPool(ctx, cfg.DatabaseURL, poolCfg, log)
	if err != nil {
		return fmt.Errorf("database pool: %w", err)
	}
	defer dbPool.Close()

	// ── Metrics ─────────────────────────────────────────────
	sm := metrics.NewServiceMetrics()

	// MED-017: Periodically export pgxpool stats to Prometheus.
	go sm.CollectPoolStats(ctx, func() metrics.PoolStat {
		s := dbPool.Stat()
		return metrics.PoolStat{
			AcquiredConns: s.AcquiredConns(),
			IdleConns:     s.IdleConns(),
			TotalConns:    s.TotalConns(),
			MaxConns:      s.MaxConns(),
		}
	}, 15*time.Second)

	// ── Redis ───────────────────────────────────────────────
	rdb, err := flickoredis.NewClient(cfg.RedisURL, log)
	if err != nil {
		return fmt.Errorf("redis client: %w", err)
	}
	defer flickoredis.Close(rdb) //nolint:errcheck

	// ── JWT KeySet ──────────────────────────────────────────
	pubKey, err := auth.LoadPublicKey(cfg.JWTPublicKeyPath)
	if err != nil {
		return fmt.Errorf("load JWT public key: %w", err)
	}
	keySet := auth.NewKeySet(pubKey)
	log.Info("JWT keyset loaded", zap.Int("keys", 1))

	// ── Repositories ────────────────────────────────────────
	messageRepo := repository.NewMessageRepository(dbPool, log)
	channelRepo := repository.NewChannelRepository(dbPool, log)
	guildRepo := repository.NewGuildRepository(dbPool, log)

	// ── Redis stores ────────────────────────────────────────
	idempotencyStore := flickoredis.NewIdempotencyStore(rdb)
	cache := flickoredis.NewCache(rdb)

	// ── Rate limiter (composite: Redis + local fallback) ────
	sw, err := ratelimit.NewSlidingWindow(ctx, rdb, log)
	if err != nil {
		return fmt.Errorf("sliding window: %w", err)
	}
	buckets := ratelimit.NewBucketStore()
	defer buckets.Stop()
	rateLimiter := ratelimit.NewComposite(sw, buckets, log)

	// ── Message Batcher ─────────────────────────────────────
	dlqDir := envOr("DLQ_DIR", "/data/dead_letter")
	dlq := batcher.NewDeadLetterQueue(dlqDir, messageRepo, log)
	dlq.Start(ctx)

	msgBatcher := batcher.NewMessageBatcher(
		messageRepo, dlq, batcher.DefaultConfig(), log,
	)

	// Run the batcher event loop in a separate goroutine.
	// It will drain gracefully when ctx is cancelled.
	batcherCtx, batcherCancel := context.WithCancel(ctx)
	batcherDone := make(chan struct{})
	go func() {
		msgBatcher.Run(batcherCtx)
		close(batcherDone)
	}()

	// ── Abuse detection ────────────────────────────────────────
	abuseDetector := abuse.NewDetector(rdb, abuse.DefaultThresholds(), log)
	abuseEnforcer := abuse.NewEnforcer(rdb, nil, log) // nil logger: admin log via zap only for now

	// ── Pub/Sub Publisher (realtime fanout after DB write) ──
	eventPublisher := pubsub.NewPublisher(rdb, log)

	// ── Services ────────────────────────────────────────────
	messageSvc := service.NewMessageService(messageRepo, channelRepo, msgBatcher, idempotencyStore, cache, abuseDetector, abuseEnforcer, eventPublisher, log)
	channelSvc := service.NewChannelService(channelRepo, guildRepo, log)
	guildSvc := service.NewGuildService(guildRepo, log)

	// Media service - Cloudinary credentials are configured via environment variables
	// The MediaService will use Cloudinary for presigned uploads
	// Note: You may need to implement a Cloudinary-specific presigner or use existing MediaService
	// For now, commenting out until Cloudinary presigner is implemented
	// mediaSvc := service.NewMediaService(cloudinaryPresigner, "flicko-attachments", log)
	var mediaSvc *service.MediaService // Placeholder until Cloudinary presigner is implemented

	// ── Handlers ────────────────────────────────────────────
	messageH := handler.NewMessageHandler(messageSvc, log)
	channelH := handler.NewChannelHandler(channelSvc, log)
	guildH := handler.NewGuildHandler(guildSvc, log)
	uploadH := handler.NewUploadHandler(mediaSvc, log)
	healthH := handler.NewHealthHandler(dbPool, rdb, log)

	// ── Router ──────────────────────────────────────────────
	router := handler.NewRouter(handler.RouterDeps{
		Message:        messageH,
		Channel:        channelH,
		Guild:          guildH,
		Upload:         uploadH,
		Health:         healthH,
		KeySet:         keySet,
		RateLimiter:    rateLimiter,
		Idempotency:    idempotencyStore,
		IdempotencyTTL: cfg.IdempotencyTTL,
		Log:            log,
	})

	// ── HTTP server ─────────────────────────────────────────
	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.HTTPPort),
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	// ── Metrics server ──────────────────────────────────────
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promhttp.Handler())

	// Silence linter: sm is used by CollectPoolStats goroutine + middleware.
	_ = sm

	metricsSrv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.MetricsPort),
		Handler:           metricsMux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// ── Start listeners ─────────────────────────────────────
	errCh := make(chan error, 2)
	go func() { errCh <- srv.ListenAndServe() }()
	go func() { errCh <- metricsSrv.ListenAndServe() }()

	log.Info("msg-service ready",
		zap.Int("http", cfg.HTTPPort),
		zap.Int("metrics", cfg.MetricsPort),
	)

	// ── Wait for shutdown signal or fatal error ─────────────
	select {
	case <-ctx.Done():
		log.Info("shutdown signal received")
	case err := <-errCh:
		log.Error("server error", zap.Error(err))
	}

	// ── Drain ───────────────────────────────────────────────
	drainCtx, drainCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer drainCancel()

	if err := srv.Shutdown(drainCtx); err != nil {
		log.Error("http server shutdown error", zap.Error(err))
	}
	if err := metricsSrv.Shutdown(drainCtx); err != nil {
		log.Error("metrics server shutdown error", zap.Error(err))
	}

	// Wait for batcher to drain all buffered messages.
	batcherCancel()
	select {
	case <-batcherDone:
		log.Info("batcher drained")
	case <-time.After(10 * time.Second):
		log.Warn("batcher drain timed out")
	}
	dlq.Stop()

	log.Info("msg-service stopped")
	return nil
}

// envOr returns the value of the environment variable named key,
// or fallback if the variable is unset or empty.
func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
