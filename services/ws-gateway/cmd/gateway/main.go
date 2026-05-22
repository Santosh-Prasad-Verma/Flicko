// Command gateway starts the Flicko WebSocket Gateway service.
//
// The gateway manages persistent WebSocket connections, authenticates
// clients via JWT (OpIdentify), rate-limits inbound frames, and fans
// out messages received from Redis Pub/Sub to local connections.
//
// Ports:
//
//	:8080  — WebSocket upgrade + /healthz
//	:9100  — Prometheus /metrics
//
// Every goroutine has a clean exit path. Graceful shutdown:
//  1. Signal → cancel ctx → Manager.Run exits (closes all clients)
//  2. PubSub.Stop → close all Redis subscriptions + workers
//  3. HTTP servers drain with 15 s timeout
//  4. Redis client closed
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/auth"
	"github.com/flicko-org/flicko/services/shared/config"
	"github.com/flicko-org/flicko/services/shared/id"
	"github.com/flicko-org/flicko/services/shared/logger"
	sharedredis "github.com/flicko-org/flicko/services/shared/redis"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/conn"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/forwarder"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/handler"
	"github.com/flicko-org/flicko/services/ws-gateway/internal/pubsub"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// ── Config ──────────────────────────────────────────────
	cfg, err := config.LoadGatewayConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config: %v\n", err)
		os.Exit(1)
	}

	// ── Logger ──────────────────────────────────────────────
	log := logger.New(!cfg.IsProd())
	defer log.Sync() //nolint:errcheck

	log.Info("ws-gateway starting",
		zap.String("env", cfg.Environment),
		zap.Int("ws_port", cfg.WSPort),
		zap.Int("max_conns", cfg.MaxConnections),
	)

	// ── Graceful-shutdown context ───────────────────────────
	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	// ── Redis ───────────────────────────────────────────────
	rdb, err := sharedredis.NewClient(cfg.RedisURL, log)
	if err != nil {
		log.Fatal("redis connect", zap.Error(err))
	}
	defer rdb.Close()

	// ── JWT Key Set ─────────────────────────────────────────
	pubKey, err := auth.LoadPublicKey(cfg.JWTPublicKeyPath)
	if err != nil {
		log.Fatal("load jwt public key", zap.Error(err))
	}
	keySet := auth.NewKeySet(pubKey)
	log.Info("jwt key loaded", zap.String("path", cfg.JWTPublicKeyPath))

	// ── Presence Manager ────────────────────────────────────
	presence := sharedredis.NewPresenceManager(rdb, log)

	// ── Gateway ID (unique per instance) ────────────────────
	gatewayID := cfg.InstanceID
	if gatewayID == "" {
		gatewayID = id.New()
	}

	// ── Connection Manager ──────────────────────────────────
	// We wire the pubsub Publisher and PresenceUpdater after
	// creating the pubsub, using a delayed-init adapter.
	var ps *pubsub.RedisPubSub

	// publishAdapter wraps the pubsub.RedisPubSub to satisfy conn.Publisher.
	publishAdapter := &pubAdapter{ps: &ps}
	presenceAdapter := &presAdapter{pm: presence, gw: gatewayID}

	mgr := conn.NewManager(publishAdapter, presenceAdapter, gatewayID, log)
	go mgr.Run(ctx)

	// ── Message Forwarder (persist-before-publish) ──────────
	gatewayToken := os.Getenv("INTERNAL_GATEWAY_TOKEN")
	fwd := forwarder.NewHTTPForwarder(cfg.MsgServiceURL, "", gatewayToken, log)
	mgr.SetForwarder(fwd)
	log.Info("message forwarder configured",
		zap.String("msg_service_url", cfg.MsgServiceURL),
		zap.Bool("has_gateway_token", gatewayToken != ""),
	)

	// ── PubSub ──────────────────────────────────────────────
	numWorkers := runtime.NumCPU()
	if numWorkers < 4 {
		numWorkers = 4
	}
	ps = pubsub.NewRedisPubSub(rdb, mgr.FanoutToChannel, numWorkers, log)
	if err := ps.Start(ctx); err != nil {
		log.Fatal("pubsub start", zap.Error(err))
	}
	defer ps.Stop() //nolint:errcheck

	// Wire the circular dependency: manager → pubsub for Subscribe/Unsubscribe.
	mgr.SetSubscriber(ps)

	// ── HTTP mux (WS + health) ──────────────────────────────
	wsHandler := handler.NewWSHandler(
		mgr,
		keySet,
		cfg.RateLimitMsgPerSec,
		cfg.RateLimitBurst,
		int64(cfg.MaxConnections),
		cfg.ReadBufferSize,
		cfg.WriteBufferSize,
		cfg.CORSOrigins,
		log,
	)
	healthHandler := handler.NewHealthHandler(rdb, mgr, log)

	mux := http.NewServeMux()
	mux.Handle("/ws", wsHandler)
	mux.Handle("/healthz", healthHandler)

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.WSPort),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// ── Metrics server ──────────────────────────────────────
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promhttp.Handler())

	metricsSrv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.MetricsPort),
		Handler:           metricsMux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// ── Presence heartbeat loop ─────────────────────────────
	// Every 20 s, refresh the TTL of every connected user's presence
	// key in Redis. PresenceTTL is 60 s so this keeps users "online"
	// while they are connected without a full SetPresence call.
	go func() {
		ticker := time.NewTicker(20 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				mgr.RangeClients(func(userID string) {
					if err := presence.RefreshPresence(ctx, userID, gatewayID); err != nil {
						log.Warn("presence refresh failed",
							zap.String("user_id", userID),
							zap.Error(err),
						)
					}
				})
			case <-ctx.Done():
				return
			}
		}
	}()

	// ── Start listeners ─────────────────────────────────────
	errCh := make(chan error, 2)
	go func() { errCh <- srv.ListenAndServe() }()
	go func() { errCh <- metricsSrv.ListenAndServe() }()

	log.Info("ws-gateway ready",
		zap.String("ws", fmt.Sprintf(":%d", cfg.WSPort)),
		zap.String("metrics", fmt.Sprintf(":%d", cfg.MetricsPort)),
		zap.String("gateway_id", gatewayID),
	)

	// ── Wait for shutdown signal or fatal error ─────────────
	select {
	case <-ctx.Done():
		log.Info("shutdown signal received")
	case err := <-errCh:
		log.Error("server error", zap.Error(err))
	}

	// ── Drain ───────────────────────────────────────────────
	drainCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := srv.Shutdown(drainCtx); err != nil {
		log.Error("ws server shutdown error", zap.Error(err))
	}
	if err := metricsSrv.Shutdown(drainCtx); err != nil {
		log.Error("metrics server shutdown error", zap.Error(err))
	}

	log.Info("ws-gateway stopped")
}

// ── Adapters (satisfy conn.Publisher / conn.PresenceUpdater) ────────

// pubAdapter wraps *pubsub.RedisPubSub to satisfy conn.Publisher.
// It holds a pointer-to-pointer so the actual RedisPubSub can be
// initialized after the Manager (circular dependency resolution).
type pubAdapter struct {
	ps **pubsub.RedisPubSub
}

func (a *pubAdapter) Publish(ctx context.Context, channelID string, message []byte) error {
	if *a.ps == nil {
		return nil // PubSub not yet initialised.
	}
	return (*a.ps).Publish(ctx, channelID, message)
}

func (a *pubAdapter) PublishTyping(ctx context.Context, channelID string, payload []byte) error {
	if *a.ps == nil {
		return nil // PubSub not yet initialised.
	}
	return (*a.ps).PublishTyping(ctx, channelID, payload)
}

// presAdapter wraps shared/redis.PresenceManager to satisfy conn.PresenceUpdater.
type presAdapter struct {
	pm *sharedredis.PresenceManager
	gw string
}

func (a *presAdapter) SetPresence(ctx context.Context, userID, status, _ string) error {
	return a.pm.SetPresence(ctx, userID, status, a.gw)
}

func (a *presAdapter) SetTyping(ctx context.Context, channelID, userID string) error {
	return a.pm.SetTyping(ctx, channelID, userID)
}

func (a *presAdapter) RefreshPresence(ctx context.Context, userID, gatewayID string) error {
	return a.pm.RefreshPresence(ctx, userID, gatewayID)
}
