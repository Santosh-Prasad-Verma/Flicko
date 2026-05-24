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
	"github.com/flicko-org/flicko-backend/internal/gaming"
	"github.com/flicko-org/flicko-backend/internal/handlers"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/flicko-org/flicko-backend/internal/telemetry"
	"github.com/gorilla/mux"
	"github.com/redis/go-redis/v9"
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

	// 1b. Initialize OpenTelemetry Tracer
	otelCtx, otelCancel := context.WithTimeout(context.Background(), 5*time.Second)
	otelShutdown, otelErr := telemetry.InitTracer(otelCtx, "flicko-backend", os.Getenv("OTEL_COLLECTOR_ENDPOINT"))
	otelCancel()
	if otelErr != nil {
		logger.Warn("failed to initialize OpenTelemetry tracer", zap.Error(otelErr))
	} else {
		logger.Info("OpenTelemetry tracer initialized successfully")
		defer func() {
			shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer shutdownCancel()
			if err := otelShutdown(shutdownCtx); err != nil {
				logger.Error("failed to shutdown OpenTelemetry tracer", zap.Error(err))
			}
		}()
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

	// Wire bot auth middleware with database connection
	handlers.SetBotAuthDB(db.Pool(), logger)
	handlers.SetBotMarketplaceDB(db.Pool(), logger)

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
	r.Use(middleware.Tracing)

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
	liveKitService := services.NewLiveKitService(cfg.LiveKitAPIKey, cfg.LiveKitAPISecret)
	videoHandler := handlers.NewVideoHandler(streamService, voiceService, permService, liveKitService, logger)
	// VideoHandler.RegisterRoutes uses absolute /api/v1/ paths with auth middleware
	videoRouter := r.PathPrefix("/").Subrouter()
	videoRouter.Use(middleware.RequestID, middleware.CORS, middleware.Auth)
	videoHandler.RegisterRoutes(videoRouter)

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
	protected.HandleFunc("/servers/discover/trending", discoveryHandler.GetTrendingServers).Methods("GET")

	// Activities lifecycle + catalog
	activityHandler := handlers.NewActivityHandler(db.Pool(), logger)
	mfaHandler := handlers.NewMFAHandler(db.Pool(), logger)
	authSecurityHandler := handlers.NewAuthSecurityHandler(db.Pool(), logger)
	privacyHandler := handlers.NewPrivacyHandler(db.Pool(), logger)
	reactionRoleHandler := handlers.NewReactionRoleHandler(db.Pool(), logger)
	screeningHandler := handlers.NewScreeningHandler(db.Pool(), logger)
	purgeHandler := handlers.NewPurgeHandler(db.Pool(), logger)
	moderationActionsHandler := handlers.NewModerationActionsHandler(db.Pool(), logger)
	stageHandler := handlers.NewStageHandler(db.Pool(), logger)
	voiceAdminHandler := handlers.NewVoiceAdminHandler(db.Pool(), logger)
	mailService := services.NewMailService(cfg.MailGatewayURL, cfg.InternalToken, logger)
	premiumHandler := handlers.NewPremiumHandler(db.Pool(), logger, mailService, cfg.RazorpayKeyID, cfg.RazorpayKeySecret)
	appInstallHandler := handlers.NewAppInstallHandler(db.Pool(), logger)
	interactionsHandler := handlers.NewInteractionsHandler(db.Pool(), logger)
	appDirectoryHandler := handlers.NewAppDirectoryHandler(db.Pool(), logger)
	forumHandler := handlers.NewForumHandler(db.Pool(), logger)
	insightsHandler := handlers.NewInsightsHandler(db.Pool(), logger)
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

	// ── Bot Marketplace Endpoints ───────────────────────────────────────────
	protected.HandleFunc("/bots", handlers.HandleRegisterBot).Methods("POST")
	protected.HandleFunc("/bots/{id}/keys", handlers.HandleGenerateAPIKey).Methods("POST")
	protected.HandleFunc("/bots/{id}/rotate-secret", handlers.HandleRotateBotSecret).Methods("POST")

	// ── Webhook / Bot API Endpoints (called *by* bots) ─────────────────────
	// These use the new BotAuthMiddleware requiring `flicko_bot_...` Authorization bearers
	botAPI := api.PathPrefix("/bot-api").Subrouter()
	botAPI.Use(apiLimiter.Limit)
	botAPI.Use(func(next http.Handler) http.Handler {
		// Use empty required scope for now or "messages.write" for specific targets
		return handlers.BotAuthMiddleware("", next)
	})

	botAPI.HandleFunc("/messages/{channelId}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status": "delivered"}`))
	}).Methods("POST")
	protected.HandleFunc("/auth/mfa/enroll", mfaHandler.Enroll).Methods("POST")
	protected.HandleFunc("/auth/mfa/verify", mfaHandler.Verify).Methods("POST")
	protected.HandleFunc("/auth/mfa/disable", mfaHandler.Disable).Methods("POST")
	protected.HandleFunc("/auth/devices", authSecurityHandler.ListTrustedDevices).Methods("GET")
	protected.HandleFunc("/auth/devices/{id}", authSecurityHandler.RevokeTrustedDevice).Methods("DELETE")
	protected.HandleFunc("/auth/login-events", authSecurityHandler.ListLoginEvents).Methods("GET")
	protected.HandleFunc("/privacy/export", privacyHandler.RequestExport).Methods("POST")
	protected.HandleFunc("/privacy/export/{jobId}", privacyHandler.GetExportStatus).Methods("GET")
	protected.HandleFunc("/privacy/delete-account", privacyHandler.RequestAccountDeletion).Methods("POST")
	protected.HandleFunc("/privacy/delete-account/{jobId}", privacyHandler.GetAccountDeletionStatus).Methods("GET")
	protected.HandleFunc("/servers/{id}/reaction-roles", reactionRoleHandler.CreateReactionRole).Methods("POST")
	protected.HandleFunc("/servers/{id}/reaction-roles/{mappingId}", reactionRoleHandler.DeleteReactionRole).Methods("DELETE")
	protected.HandleFunc("/servers/{id}/screening", screeningHandler.GetScreening).Methods("GET")
	protected.HandleFunc("/servers/{id}/screening/accept", screeningHandler.AcceptScreening).Methods("POST")
	protected.HandleFunc("/channels/{id}/messages/purge", purgeHandler.PurgeChannelMessages).Methods("POST")
	protected.HandleFunc("/servers/{id}/members/{userId}/timeout", moderationActionsHandler.TimeoutMember).Methods("POST")
	protected.HandleFunc("/servers/{id}/members/{userId}/ban", moderationActionsHandler.BanMember).Methods("POST")
	protected.HandleFunc("/stage/{channelId}/raise-hand", stageHandler.RaiseHand).Methods("POST")
	protected.HandleFunc("/stage/{channelId}/speaker/{userId}", stageHandler.PromoteSpeaker).Methods("POST")
	protected.HandleFunc("/voice/channels/{id}/move-user", voiceAdminHandler.MoveUser).Methods("POST")
	protected.HandleFunc("/voice/channels/{id}", voiceAdminHandler.PatchVoiceChannel).Methods("PATCH")
	protected.HandleFunc("/premium/gifts", premiumHandler.CreateGift).Methods("POST")
	protected.HandleFunc("/premium/redeem", premiumHandler.RedeemGift).Methods("POST")
	protected.HandleFunc("/premium/boost-credits", premiumHandler.GetBoostCredits).Methods("GET")
	protected.HandleFunc("/premium/boost-credits/apply", premiumHandler.ApplyBoostCredit).Methods("POST")
	protected.HandleFunc("/premium/cosmetics", premiumHandler.ListCosmetics).Methods("GET")
	protected.HandleFunc("/profile/cosmetics/apply", premiumHandler.ApplyCosmetic).Methods("POST")
	protected.HandleFunc("/premium/orders", premiumHandler.CreateOrder).Methods("POST")
	protected.HandleFunc("/premium/verify", premiumHandler.VerifyPayment).Methods("POST")
	protected.HandleFunc("/apps/{id}/oauth/authorize", appInstallHandler.AuthorizeApp).Methods("GET")
	protected.HandleFunc("/apps/{id}/install/callback", appInstallHandler.InstallCallback).Methods("POST")
	protected.HandleFunc("/apps/{id}/installs/{installId}/permissions", appInstallHandler.UpdateInstallPermissions).Methods("PATCH")
	protected.HandleFunc("/interactions/components", interactionsHandler.CreateComponentInteraction).Methods("POST")
	protected.HandleFunc("/interactions/modals", interactionsHandler.CreateModalInteraction).Methods("POST")
	protected.HandleFunc("/app-directory", appDirectoryHandler.ListAppDirectory).Methods("GET")
	protected.HandleFunc("/forum/posts/{id}/vote", forumHandler.VoteForumPost).Methods("POST")
	protected.HandleFunc("/servers/{id}/insights", insightsHandler.GetServerInsights).Methods("GET")

	// Parity status (internal delivery tracking)
	parityHandler := handlers.NewParityHandler(db.Pool(), logger)
	internalRouter := api.PathPrefix("/").Subrouter()
	internalRouter.Use(middleware.InternalAuth)
	internalRouter.HandleFunc("/parity/status", parityHandler.GetParityStatus).Methods("GET")

	// ── Gaming Hub Initialization ───────────────────────────────────────────
	hub, err := gaming.Initialize(context.Background(), logger, db.Pool(), redisCache.GetRedisClient().(*redis.Client), r)
	if err != nil {
		logger.Fatal("failed to initialize gaming hub", zap.Error(err))
	}

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


	// ── Creator Community Subsystem ──────────────────────────────────────────
	creatorSvc := services.NewCreatorService(db.Pool(), redisCache, cfg.SupabaseURL, cfg.SupabaseServiceKey)
	creatorHandler := handlers.NewCreatorHandler(creatorSvc, logger)

	// Rate limiters for creator subsystem
	createPostLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 5, logger, "creator:create")
	deletePostLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 20, logger, "creator:delete")
	engagementLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 30, logger, "creator:engagement")
	followLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 60, logger, "creator:follow")
	acceptAnswerLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 10, logger, "creator:accept_answer")
	mediaUploadLimiter := middleware.NewDistributedRateLimiter(redisCache.GetRedisClient(), 10, logger, "creator:upload")

	// Protected routes under /api/v1/creator/...
	// state-changing and customized rate-limited routes
	protected.Handle("/creator/posts", createPostLimiter.Limit(http.HandlerFunc(creatorHandler.CreatePost))).Methods("POST")
	protected.Handle("/creator/posts/{id}", deletePostLimiter.Limit(http.HandlerFunc(creatorHandler.DeletePost))).Methods("DELETE")
	protected.Handle("/creator/posts/{id}/like", engagementLimiter.Limit(http.HandlerFunc(creatorHandler.ToggleLike))).Methods("POST")
	protected.Handle("/creator/posts/{id}/repost", engagementLimiter.Limit(http.HandlerFunc(creatorHandler.ToggleRepost))).Methods("POST")
	protected.Handle("/creator/posts/{id}/accept-answer", acceptAnswerLimiter.Limit(http.HandlerFunc(creatorHandler.MarkAcceptedAnswer))).Methods("POST")
	protected.Handle("/creator/users/{id}/follow", followLimiter.Limit(http.HandlerFunc(creatorHandler.ToggleFollow))).Methods("POST")
	protected.Handle("/creator/media/upload-url", mediaUploadLimiter.Limit(http.HandlerFunc(creatorHandler.GenerateUploadPresignedURL))).Methods("POST")

	// Query/fetch routes (General 50 req/s IP limit already on 'protected')
	protected.HandleFunc("/creator/feed", creatorHandler.GetFeed).Methods("GET")
	protected.HandleFunc("/creator/search", creatorHandler.SearchPosts).Methods("GET")
	protected.HandleFunc("/creator/profile/{id}", creatorHandler.GetUserProfile).Methods("GET")
	protected.HandleFunc("/creator/posts/{id}", creatorHandler.GetPost).Methods("GET")
	protected.HandleFunc("/creator/posts/{id}/replies", creatorHandler.GetReplies).Methods("GET")
	protected.HandleFunc("/creator/users/{id}/posts", creatorHandler.GetUserPosts).Methods("GET")
	protected.HandleFunc("/creator/users/{id}/followers", creatorHandler.GetFollowers).Methods("GET")
	protected.HandleFunc("/creator/users/{id}/following", creatorHandler.GetFollowing).Methods("GET")

	// ── E2EE Direct Messages ─────────────────────────────────────────────────
	e2eeHandler := handlers.NewE2EEHandler(db.Pool(), logger)
	protected.HandleFunc("/e2ee/identity", e2eeHandler.UpsertIdentity).Methods("PUT")
	protected.HandleFunc("/e2ee/identity/{userId}", e2eeHandler.GetIdentity).Methods("GET")
	protected.HandleFunc("/e2ee/signed-prekey", e2eeHandler.UpsertSignedPrekey).Methods("PUT")
	protected.HandleFunc("/e2ee/one-time-prekeys", e2eeHandler.PutOneTimePrekeys).Methods("PUT")
	protected.HandleFunc("/e2ee/one-time-prekeys/count", e2eeHandler.CountOneTimePrekeys).Methods("GET")
	protected.HandleFunc("/e2ee/bundle/{userId}", e2eeHandler.FetchBundle).Methods("GET")
	protected.HandleFunc("/e2ee/conversations/{otherUserId}/enable", e2eeHandler.EnableConversation).Methods("POST")
	protected.HandleFunc("/e2ee/conversations/{otherUserId}/state", e2eeHandler.GetConversationState).Methods("GET")
	protected.HandleFunc("/e2ee/envelopes", e2eeHandler.PushEnvelope).Methods("POST")
	protected.HandleFunc("/e2ee/envelopes/pull", e2eeHandler.PullEnvelopes).Methods("POST")
	protected.HandleFunc("/e2ee/backup", e2eeHandler.PutBackupChunk).Methods("PUT")
	protected.HandleFunc("/e2ee/backup/{index}", e2eeHandler.FetchBackupChunk).Methods("GET")
	protected.HandleFunc("/e2ee/backup-manifest", e2eeHandler.BackupManifest).Methods("GET")
	protected.HandleFunc("/e2ee/backup", e2eeHandler.DeleteBackup).Methods("DELETE")
	protected.HandleFunc("/e2ee/escrow-policy", e2eeHandler.GetEscrowPolicy).Methods("GET")
	protected.HandleFunc("/e2ee/audit", e2eeHandler.AppendAuditLog).Methods("POST")
	protected.HandleFunc("/e2ee/audit/{subjectId}", e2eeHandler.ListAuditLogs).Methods("GET")
	protected.HandleFunc("/e2ee/handoff", e2eeHandler.CreateHandoff).Methods("POST")
	protected.HandleFunc("/e2ee/handoff/{requestId}/approve", e2eeHandler.ApproveHandoff).Methods("POST")

	// Per-user feature flags (E2EE v2 rollout)
	flagsHandler := handlers.NewFeatureFlagsHandler(logger, cfg.E2EEV2Enabled, cfg.E2EEV2RolloutPercent)
	protected.HandleFunc("/users/@me/config", flagsHandler.GetConfig).Methods("GET")



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
	
	// Shutdown gaming hub
	hub.Shutdown()
	
	logger.Info("bots and gaming hub shut down")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Fatal("server forced to shutdown", zap.Error(err))
	}

	logger.Info("server exited cleanly")
}
