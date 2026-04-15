package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots"
	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/flicko-org/flicko-backend/internal/handlers"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// initLogger creates a structured zap logger based on the environment.
func initLogger() (*zap.Logger, error) {
	var cfg zap.Config
	if os.Getenv("ENVIRONMENT") == "development" {
		cfg = zap.NewDevelopmentConfig()
	} else {
		cfg = zap.NewProductionConfig()
	}
	cfg.EncoderConfig.TimeKey = "timestamp"
	cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	return cfg.Build()
}

var startTime = time.Now()

func main() {
	// 0. Initialize structured logger
	logger, err := initLogger()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	logger.Info("initializing Flicko backend",
		zap.String("version", "1.0.0"),
		zap.String("environment", os.Getenv("ENVIRONMENT")),
	)

	// 1. Load config
	cfg, err := config.Load()
	if err != nil {
		logger.Fatal("failed to load configuration", zap.Error(err))
	}

	// 2. Setup Database
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	db, err := database.NewDatabaseClient(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Fatal("database connection failed", zap.Error(err))
	}
	defer db.Close()
	logger.Info("database connection established")

	// 3. Setup Redis
	redisCache, err := cache.NewRedisCache(cfg.RedisURL)
	if err != nil {
		logger.Fatal("redis connection failed", zap.Error(err))
	}
	defer redisCache.Close()
	logger.Info("redis connection established")

	// 3a. Setup Cloudinary signing handler (replaces B2)
	cloudinaryHandler := handlers.NewCloudinaryHandler(
		cfg.CloudinaryCloudName,
		cfg.CloudinaryAPIKey,
		cfg.CloudinaryAPISecret,
		cfg.CloudinaryPreset,
		logger,
	)
	logger.Info("cloudinary signing configured",
		zap.String("cloud_name", cfg.CloudinaryCloudName),
	)

	// 3c. Setup Bot System (Event Bus, Command Router, Bot Registry)
	eventBus := events.NewEventBus(logger)
	eventBus.Use(events.RecoveryMiddleware(logger))
	eventBus.Use(events.LoggingMiddleware(logger))

	cmdRouter := commands.NewRouter(logger)

	botCtx := bots.BotContext{
		DB:       db,
		EventBus: eventBus,
		Logger:   logger,
	}
	registry := bots.NewRegistry(botCtx)
	registry.Add(bots.NewModerationBot(cmdRouter))
	registry.Add(bots.NewAutoModBot(cmdRouter))
	registry.Add(bots.NewWelcomeBot(cmdRouter))
	registry.Add(bots.NewLevelingBot(cmdRouter))
	registry.Add(bots.NewMusicBot(cmdRouter))
	registry.Add(bots.NewTicketBot(cmdRouter))
	registry.Add(bots.NewPollBot(cmdRouter))
	registry.Add(bots.NewStarboardBot(cmdRouter))

	if err := registry.StartAll(); err != nil {
		logger.Fatal("failed to start bots", zap.Error(err))
	}
	logger.Info("bot system initialized", zap.Int("bot_count", 8))

	// Start background tickers for bots (minute/hour events)
	tickerCtx, tickerCancel := context.WithCancel(context.Background())
	go func() {
		minuteTicker := time.NewTicker(1 * time.Minute)
		hourTicker := time.NewTicker(1 * time.Hour)
		defer minuteTicker.Stop()
		defer hourTicker.Stop()
		for {
			select {
			case <-tickerCtx.Done():
				return
			case <-minuteTicker.C:
				eventBus.Publish(events.Event{
					Type:      events.TickerMinute,
					Timestamp: time.Now(),
				})
			case <-hourTicker.C:
				eventBus.Publish(events.Event{
					Type:      events.TickerHour,
					Timestamp: time.Now(),
				})
			}
		}
	}()

	// 3b. Setup Auth Service and wire into middleware
	// CRIT-001: Auth middleware now uses real JWT validation
	// Supabase fallback handles ES256 tokens after key rotation
	authService := services.NewAuthService(db, cfg.JWTSecret,
		services.WithSupabase(cfg.SupabaseURL, cfg.SupabaseServiceKey),
	)
	middleware.SetAuthService(authService)

	// 4. Setup Router
	r := mux.NewRouter()

	// Apply request ID middleware before all other middleware
	r.Use(middleware.RequestID)

	api := r.PathPrefix("/api/v1").Subrouter()

	// Apply Middlewares
	api.Use(middleware.CORS)

	// CRIT-012: Add timeout middleware to protect against slowloris attacks
	api.Use(middleware.TimeoutMiddleware(30 * time.Second))

	// HIGH-006: Request body size limit (10MB)
	api.Use(middleware.RequestBodyLimitMiddleware(10*1024*1024, logger))

	// HIGH-007: Input sanitization to prevent XSS
	api.Use(middleware.InputSanitizationMiddleware(logger))

	// HIGH-002: CSRF protection for state-changing requests
	api.Use(middleware.CSRFMiddleware(logger))

	// MED-007: Filter sensitive data from logs
	api.Use(middleware.RequestFilterMiddleware(logger))

	// CRIT-002: Replace memory-based rate limiter with distributed Redis-backed limiter
	apiLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 50, logger, "api")
	// 50 requests per second per IP for general API endpoints

	// Protected routes with auth middleware and general API limiter
	// This separates them from auth routes so limiters don't stack incorrectly.
	protected := api.PathPrefix("/").Subrouter()
	protected.Use(apiLimiter.Limit)
	protected.Use(middleware.Auth)

	// General API routes (unprotected but limited)
	generalUnprotected := api.PathPrefix("/").Subrouter()
	generalUnprotected.Use(apiLimiter.Limit)

	// MED-007 & HIGH-008: Enhanced health check with comprehensive dependency checks
	healthChecker := handlers.NewHealthChecker(db, redisCache.GetRedisClient(), logger)

	generalUnprotected.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.Handler().ServeHTTP(w, r)
	}).Methods("GET")

	// Liveness probe (for Kubernetes)
	generalUnprotected.HandleFunc("/healthz/live", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.LivenessProbe().ServeHTTP(w, r)
	}).Methods("GET")

	// Readiness probe (for Kubernetes)
	generalUnprotected.HandleFunc("/healthz/ready", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.ReadinessProbe().ServeHTTP(w, r)
	}).Methods("GET")

	// Old health check code removed - now using HealthChecker above

	// Protected routes with auth middleware are already initialized above
	// protected := api.PathPrefix("/").Subrouter()
	// protected.Use(middleware.Auth)

	// ── Video/Streaming endpoints ───────────────────────────────────────────
	permService := services.NewPermissionService(db.Pool(), redisCache)
	voiceService := services.NewVoiceService(db.Pool(), permService)
	streamService := services.NewStreamService(db.Pool(), permService, voiceService)
	videoHandler := handlers.NewVideoHandler(streamService, voiceService, permService, logger)
	// VideoHandler.RegisterRoutes uses absolute /api/v1/ paths with auth middleware
	videoRouter := r.PathPrefix("/").Subrouter()
	videoRouter.Use(middleware.RequestID, middleware.CORS, middleware.Auth)
	videoHandler.RegisterRoutes(videoRouter)

	// ── Cloudinary signing endpoint ─────────────────────────────────────────
	// Mobile clients call this to get a signed upload params, then upload
	// directly to Cloudinary. No file data passes through this server.
	protected.HandleFunc("/cloudinary/sign", cloudinaryHandler.Sign).Methods("GET")

	// ── Bot API routes ──────────────────────────────────────────────────────
	botHandler := handlers.NewBotHandler(db, eventBus, cmdRouter, logger)

	// Start event bridge to sync internal events to Supabase Realtime
	eventBridge := events.NewBridge(db, eventBus, logger)
	eventBridge.Start()

	// Slash commands
	protected.HandleFunc("/commands", botHandler.ListCommands).Methods("GET")
	protected.HandleFunc("/commands/{serverId}", botHandler.ListServerCommands).Methods("GET")
	protected.HandleFunc("/commands/invoke", botHandler.InvokeCommand).Methods("POST")

	// Bot settings
	protected.HandleFunc("/servers/{serverId}/bots/{botName}/settings", botHandler.GetBotSettings).Methods("GET")
	protected.HandleFunc("/servers/{serverId}/bots/{botName}/settings", botHandler.UpdateBotSettings).Methods("PUT")

	// Leaderboard / XP
	protected.HandleFunc("/servers/{serverId}/leaderboard", botHandler.GetLeaderboard).Methods("GET")
	protected.HandleFunc("/servers/{serverId}/rank/{userId}", botHandler.GetUserRank).Methods("GET")

	// Tickets
	protected.HandleFunc("/servers/{serverId}/tickets", botHandler.GetServerTickets).Methods("GET")

	// Polls
	protected.HandleFunc("/servers/{serverId}/polls", botHandler.GetActivePolls).Methods("GET")
	protected.HandleFunc("/polls/vote", botHandler.VotePoll).Methods("POST")

	// Starboard
	protected.HandleFunc("/servers/{serverId}/starboard", botHandler.GetStarboardEntries).Methods("GET")

	// Server Discovery
	discoveryHandler := handlers.NewDiscoveryHandler(db.Pool(), logger)
	protected.HandleFunc("/servers/discover", discoveryHandler.DiscoverServers).Methods("GET")

	// Activities lifecycle + catalog
	activityHandler := handlers.NewActivityHandler(db.Pool(), logger)
	mfaHandler := handlers.NewMFAHandler(db.Pool(), logger)
	authSecurityHandler := handlers.NewAuthSecurityHandler(db.Pool(), logger)
	privacyHandler := handlers.NewPrivacyHandler(db.Pool(), logger)
	protected.HandleFunc("/activities/catalog", activityHandler.GetCatalog).Methods("GET")
	protected.HandleFunc("/activities/catalog/{id}/validate", activityHandler.ValidateCatalogActivity).Methods("POST")
	protected.HandleFunc("/activities/providers/register", activityHandler.RegisterProvider).Methods("POST")
	protected.HandleFunc("/activities/providers/{id}/publish", activityHandler.PublishProvider).Methods("POST")
	protected.HandleFunc("/activities/launch", activityHandler.Launch).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/join", activityHandler.Join).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/leave", activityHandler.Leave).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/end", activityHandler.End).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}", activityHandler.GetSession).Methods("GET")
	protected.HandleFunc("/activities/{sessionId}/state", activityHandler.UpdateState).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/sync/play", activityHandler.SyncPlay).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/sync/pause", activityHandler.SyncPause).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/sync/seek", activityHandler.SyncSeek).Methods("POST")
	protected.HandleFunc("/activities/{sessionId}/participants", activityHandler.GetParticipants).Methods("GET")
	protected.HandleFunc("/users/{id}/active-activity", activityHandler.GetUserActiveActivity).Methods("GET")
	protected.HandleFunc("/channels/{id}/active-activity", activityHandler.GetChannelActiveActivity).Methods("GET")
	protected.HandleFunc("/auth/mfa/enroll", mfaHandler.Enroll).Methods("POST")
	protected.HandleFunc("/auth/mfa/verify", mfaHandler.Verify).Methods("POST")
	protected.HandleFunc("/auth/mfa/disable", mfaHandler.Disable).Methods("POST")
	protected.HandleFunc("/auth/devices", authSecurityHandler.ListTrustedDevices).Methods("GET")
	protected.HandleFunc("/auth/devices/{id}", authSecurityHandler.RevokeTrustedDevice).Methods("DELETE")
	protected.HandleFunc("/auth/login-events", authSecurityHandler.ListLoginEvents).Methods("GET")
	protected.HandleFunc("/privacy/export", privacyHandler.RequestExport).Methods("POST")
	protected.HandleFunc("/privacy/export/{jobId}", privacyHandler.GetExportStatus).Methods("GET")

	// Parity status (internal delivery tracking)
	parityHandler := handlers.NewParityHandler(db.Pool(), logger)
	protected.HandleFunc("/parity/status", parityHandler.GetParityStatus).Methods("GET")

	// Custom Emojis
	emojiHandler := handlers.NewEmojiHandler(db.Pool(), logger)
	protected.HandleFunc("/servers/{serverId}/emojis", emojiHandler.GetServerEmojis).Methods("GET")
	protected.HandleFunc("/servers/{serverId}/emojis", emojiHandler.CreateEmoji).Methods("POST")

	// Music Bot State
	musicHandler := handlers.NewMusicHandler(db.Pool(), logger)
	protected.HandleFunc("/servers/{serverId}/music/state", musicHandler.GetMusicState).Methods("GET")

	// Message creation (for timeouts, silent, mentions)
	msgHandler := handlers.NewMessageHandler(db.Pool(), logger)
	protected.HandleFunc("/channels/{channelId}/messages", msgHandler.CreateMessage).Methods("POST")

	// Member join notification (triggers welcome bot)
	protected.HandleFunc("/servers/{serverId}/members/join-notify", botHandler.NotifyMemberJoin).Methods("POST")

	// Member leave notification (triggers welcome bot goodbye)
	protected.HandleFunc("/servers/{serverId}/members/leave-notify", botHandler.NotifyMemberLeave).Methods("POST")

	// Message create notification (triggers automod + leveling bots)
	protected.HandleFunc("/messages/notify", botHandler.NotifyMessageCreate).Methods("POST")

	// Reaction notifications (triggers starboard bot)
	protected.HandleFunc("/reactions/add-notify", botHandler.NotifyReactionAdd).Methods("POST")
	protected.HandleFunc("/reactions/remove-notify", botHandler.NotifyReactionRemove).Methods("POST")

	// ── Read Receipts API setup ──────────────────────────────────────────────
	readStateSvc := services.NewReadStateService(db.Pool())
	readStateHandler := handlers.NewReadStateHandler(readStateSvc, logger)

	protected.HandleFunc("/channels/{channelId}/messages/{messageId}/read", readStateHandler.MarkAsRead).Methods("POST")
	protected.HandleFunc("/users/@me/read_states", readStateHandler.GetUserReadStates).Methods("GET")

	// User endpoint - uses actual auth context
	protected.HandleFunc("/users/@me", func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.GetUserIDKey())
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"id": userID,
		})
	}).Methods("GET")

	// 5. HTTP Server definition (CRIT-012: Updated timeouts)
	srv := &http.Server{
		Addr:              ":" + cfg.PortHTTP,
		Handler:           r,
		ReadTimeout:       10 * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1 MB
	}

	// 6. Graceful Shutdown hook
	go func() {
		logger.Info("server starting", zap.String("port", cfg.PortHTTP))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("listen and serve error", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	logger.Info("shutting down gracefully...")

	// Stop background goroutines before shutting down bots
	tickerCancel()

	// Shutdown bots first
	registry.ShutdownAll()
	logger.Info("bots shut down")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Fatal("server forced to shutdown", zap.Error(err))
	}

	logger.Info("server exited cleanly")
}
