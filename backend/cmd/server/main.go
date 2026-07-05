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

	"github.com/flicko-org/flicko-backend/internal/activities/watchtogether"
	"github.com/flicko-org/flicko-backend/internal/bots"
	"github.com/flicko-org/flicko-backend/internal/bots/gateway"
	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/flicko-org/flicko-backend/internal/gaming"
	"github.com/flicko-org/flicko-backend/internal/handlers"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/flicko-org/flicko-backend/internal/services/ai/llm"
	"github.com/flicko-org/flicko-backend/internal/services/ai/message_summary"
	"github.com/flicko-org/flicko-backend/internal/services/ai/moderation"
	"github.com/flicko-org/flicko-backend/internal/services/ai/translate"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/flicko-org/flicko-backend/internal/telemetry"
	"github.com/gorilla/mux"
	"github.com/hibiken/asynq"
	"github.com/prometheus/client_golang/prometheus/promhttp"
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

	// Wire bot auth middleware with database connection and redis caching
	handlers.SetBotAuthDB(db.Pool(), cfg.JWTSecret, redisCache.GetRedisClient(), logger)
	handlers.SetBotMarketplaceDB(db.Pool(), logger)

	// Start background tickers for bots (minute/hour events).
	//
	// HIGH-2 fix: in a multi-pod deployment, every pod's ticker would fire
	// simultaneously and bot handlers (e.g. punishment expiry) would run
	// N× in parallel. We acquire a short Redis lease keyed on the tick
	// boundary; only the pod that wins publishes. The lease TTL is shorter
	// than the tick interval so the next tick gets a fresh contest.
	tickerCtx, tickerCancel := context.WithCancel(context.Background())
	go func() {
		minuteTicker := time.NewTicker(1 * time.Minute)
		hourTicker := time.NewTicker(1 * time.Hour)
		defer minuteTicker.Stop()
		defer hourTicker.Stop()

		rdb := redisCache.GetRedisClient()

		tryPublish := func(t events.EventType, period time.Duration) {
			// Bucket the current time to the period boundary so all pods
			// race for the same key.
			bucket := time.Now().Truncate(period).Unix()
			key := fmt.Sprintf("flicko:tick:%s:%d", string(t), bucket)
			leaseTTL := period - 5*time.Second
			if leaseTTL < 5*time.Second {
				leaseTTL = 5 * time.Second
			}
			ok, err := rdb.SetNX(tickerCtx, key, "1", leaseTTL).Result()
			if err != nil {
				logger.Debug("ticker SetNX error (publishing locally)", zap.Error(err))
				ok = true // fail-open for single-Redis dev environments
			}
			if !ok {
				return
			}
			eventBus.Publish(events.Event{
				Type:      t,
				Timestamp: time.Now(),
			})
		}

		for {
			select {
			case <-tickerCtx.Done():
				return
			case <-minuteTicker.C:
				tryPublish(events.TickerMinute, time.Minute)
			case <-hourTicker.C:
				tryPublish(events.TickerHour, time.Hour)
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

	protected := api.PathPrefix("/").Subrouter()
	protected.Use(apiLimiter.Limit)
	protected.Use(middleware.Auth)
	protected.Use(middleware.ValidationMiddleware)

	// Initialize caching and throttling middlewares
	cacheMiddleware := middleware.NewCacheMiddleware(redisCache.GetRedisClient(), logger)
	throttler := middleware.NewThrottler(redisCache.GetRedisClient(), logger)

	// MED-007 & HIGH-008: Enhanced health check with comprehensive dependency checks
	healthChecker := handlers.NewHealthChecker(db, redisCache.GetRedisClient(), logger)

	api.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.Handler().ServeHTTP(w, r)
	}).Methods("GET")

	// Liveness probe (for Kubernetes)
	api.HandleFunc("/healthz/live", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.LivenessProbe().ServeHTTP(w, r)
	}).Methods("GET")

	// Readiness probe (for Kubernetes)
	api.HandleFunc("/healthz/ready", func(w http.ResponseWriter, r *http.Request) {
		healthChecker.ReadinessProbe().ServeHTTP(w, r)
	}).Methods("GET")

	// Prometheus metrics endpoint
	api.Handle("/metrics", promhttp.Handler()).Methods("GET")

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
	botHandler := handlers.NewBotHandler(db, eventBus, cmdRouter, redisCache, logger)

	// Start event bridge to sync internal events to Supabase Realtime
	eventBridge := events.NewBridge(db, eventBus, logger)
	eventBridge.Start()

	// CRIT-7: Start Postgres LISTEN/NOTIFY bridge so bots react to real
	// activity (messages, member joins, reactions) written by mobile/web
	// clients directly via Supabase.
	pgListener := events.NewPgListener(db.Pool(), eventBus, logger)
	go pgListener.Start(tickerCtx)

	// Slash commands
	protected.HandleFunc("/commands", botHandler.ListCommands).Methods("GET")
	protected.HandleFunc("/commands/invoke", botHandler.InvokeCommand).Methods("POST")
	protected.HandleFunc("/commands/{serverId}", botHandler.ListServerCommands).Methods("GET")

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
	protected.Handle("/servers/discover", cacheMiddleware.Cache(middleware.CacheMedium)(http.HandlerFunc(discoveryHandler.DiscoverServers))).Methods("GET")
	protected.Handle("/servers/discover/trending", cacheMiddleware.Cache(middleware.CacheMedium)(http.HandlerFunc(discoveryHandler.GetTrendingServers))).Methods("GET")

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

	// AI Catch-Me-Up summary
	llmClient := llm.New(llm.Config{
		GroqAPIKey:    cfg.GroqAPIKey,
		GroqBaseURL:   cfg.GroqBaseURL,
		GroqModel:     cfg.GroqModel,
		OllamaBaseURL: cfg.OllamaBaseURL,
		OllamaModel:   cfg.OllamaModel,
		HTTPTimeout:   cfg.AIRequestTimeout,
	}, logger)
	summaryRepo := repo.NewAISummaryRepo(db)
	summaryCache := message_summary.NewCacheStore(redisCache)
	summaryRL := message_summary.NewRateLimit(redisCache)
	summaryCfg := message_summary.DefaultConfig()
	if cfg.GroqAPIKey != "" {
		summaryCfg.ModelName = "groq:" + cfg.GroqModel
	} else {
		summaryCfg.ModelName = "ollama:" + cfg.OllamaModel
	}
	summarySvc := message_summary.New(db, summaryRepo, summaryCache, summaryRL, llmClient, summaryCfg, logger)
	aiSummaryHandler := handlers.NewAISummaryHandler(summarySvc, logger)
	if cfg.AIMessageSummaryEnabled {
		aiSummaryHandler.RegisterRoutes(protected)
	}

	// AI Auto-Translate
	translator := translate.New(translate.Config{
		LibreBaseURL: cfg.LibreTranslateBaseURL,
		LibreAPIKey:  cfg.LibreTranslateAPIKey,
		DeepLAPIKey:  cfg.DeepLAPIKey,
		HTTPTimeout:  cfg.AIRequestTimeout,
	}, logger)
	translateSvc := translate.NewService(translator, redisCache, db, logger)
	translateHandler := handlers.NewAITranslateHandler(translateSvc, logger)
	if cfg.AIAutoTranslateEnabled {
		translateHandler.RegisterRoutes(protected)
	}

	// AI Moderation (Llama-Guard via Groq + Ollama fallback). Reuses the
	// shared LLM client since it speaks OpenAI-compatible chat completions.
	moderationSvc := moderation.New(db, redisCache, llmClient, moderation.DefaultConfig(), logger)
	moderationHandler := handlers.NewAIModerationHandler(moderationSvc, logger)
	if cfg.AIModerationEnabled {
		moderationHandler.RegisterRoutes(protected)
	}
	protected.Handle("/activities/catalog", cacheMiddleware.Cache(middleware.CacheLong)(http.HandlerFunc(activityHandler.GetCatalog))).Methods("GET")
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

	// ── Developer Portal Applications Endpoints ──────────────────────────────
	appHandler := handlers.NewApplicationHandler(db.Pool(), cfg.JWTSecret, logger)
	protected.HandleFunc("/applications", appHandler.Create).Methods("POST")
	protected.HandleFunc("/applications", appHandler.List).Methods("GET")
	protected.HandleFunc("/applications/{id}", appHandler.Get).Methods("GET")
	protected.HandleFunc("/applications/{id}", appHandler.Update).Methods("PATCH")
	protected.HandleFunc("/applications/{id}", appHandler.Delete).Methods("DELETE")
	protected.HandleFunc("/applications/{id}/bot/reset-token", appHandler.ResetToken).Methods("POST")

	// ── OAuth2 Bot Authorize Endpoints ─────────────────────────────────────
	oauth2Handler := handlers.NewOAuth2Handler(db.Pool(), logger)
	api.HandleFunc("/oauth2/authorize", oauth2Handler.GetAuthorizeInfo).Methods("GET")
	protected.HandleFunc("/oauth2/authorize", oauth2Handler.AuthorizeBot).Methods("POST")

	// ── Interactions & Webhook Handlers ─────────────────────────────────────
	interactionHandler := handlers.NewInteractionHandler(db.Pool(), logger)
	api.HandleFunc("/interactions", interactionHandler.HandleInteraction).Methods("POST")

	// ── Gateway WebSocket Protocol & Sharding Endpoints ─────────────────────
	gwServer := gateway.NewServer(db.Pool(), redisCache.GetRedisClient(), cfg.JWTSecret, logger)
	shardCoord := gateway.NewShardCoordinator(db.Pool(), redisCache.GetRedisClient(), logger)
	api.Handle("/gateway", gwServer.HandleWebSocket())
	api.HandleFunc("/gateway/bot", shardCoord.HandleGatewayBot).Methods("GET")


	// ── Webhook / Bot API Endpoints (called *by* bots) ─────────────────────
	botRateLimiter := middleware.NewBotRateLimiter(redisCache.GetRedisClient(), logger)
	botAPI := api.PathPrefix("/bot-api").Subrouter()
	botAPI.Use(func(next http.Handler) http.Handler {
		return handlers.BotAuthMiddleware("", next)
	})
	botAPI.Use(botRateLimiter.Limit)

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
	protected.Handle("/premium/cosmetics", cacheMiddleware.Cache(middleware.CacheLong)(http.HandlerFunc(premiumHandler.ListCosmetics))).Methods("GET")
	protected.HandleFunc("/profile/cosmetics/apply", premiumHandler.ApplyCosmetic).Methods("POST")
	protected.HandleFunc("/premium/orders", premiumHandler.CreateOrder).Methods("POST")
	protected.HandleFunc("/premium/verify", premiumHandler.VerifyPayment).Methods("POST")
	protected.HandleFunc("/apps/{id}/oauth/authorize", appInstallHandler.AuthorizeApp).Methods("GET")
	protected.HandleFunc("/apps/{id}/install/callback", appInstallHandler.InstallCallback).Methods("POST")
	protected.HandleFunc("/apps/{id}/installs/{installId}/permissions", appInstallHandler.UpdateInstallPermissions).Methods("PATCH")
	protected.HandleFunc("/interactions/components", interactionsHandler.CreateComponentInteraction).Methods("POST")
	protected.HandleFunc("/interactions/modals", interactionsHandler.CreateModalInteraction).Methods("POST")
	protected.Handle("/app-directory", cacheMiddleware.Cache(middleware.CacheMedium)(http.HandlerFunc(appDirectoryHandler.ListAppDirectory))).Methods("GET")
	protected.HandleFunc("/forum/posts/{id}/vote", forumHandler.VoteForumPost).Methods("POST")
	protected.HandleFunc("/servers/{id}/insights", insightsHandler.GetServerInsights).Methods("GET")

	// Parity status (internal delivery tracking)
	parityHandler := handlers.NewParityHandler(db.Pool(), logger)
	internalRouter := api.PathPrefix("/").Subrouter()
	internalRouter.Use(middleware.InternalAuth)
	internalRouter.HandleFunc("/parity/status", parityHandler.GetParityStatus).Methods("GET")

	// ── Gaming Hub Initialization ───────────────────────────────────────────
	gamingPublisher := centrifugoSvc.NewHTTPPublisher(cfg.CentrifugoAPIURL, cfg.CentrifugoAPIKey, logger)
	hub, err := gaming.Initialize(context.Background(), logger, db.Pool(), redisCache.GetRedisClient().(*redis.Client), r, gamingPublisher)
	if err != nil {
		logger.Fatal("failed to initialize gaming hub", zap.Error(err))
	}

	// ── Watch Together Module Initialization ─────────────────────────────────
	if cfg.ActivitiesWatchTogetherEnabled {
		_, err := watchtogether.Initialize(
			context.Background(),
			logger,
			db.Pool(),
			redisCache,
			liveKitService,
			protected,
			gamingPublisher,
		)
		if err != nil {
			logger.Fatal("failed to initialize watch together module", zap.Error(err))
		}
	}


	// CRIT-9: Register Asynq worker server for ludo_bot:move tasks.
	if coord := hub.BotCoordinatorAsynq(); coord != nil {
		rdb := redisCache.GetRedisClient().(*redis.Client)
		asynqRedisOpt := asynq.RedisClientOpt{
			Addr:      rdb.Options().Addr,
			Password:  rdb.Options().Password,
			DB:        rdb.Options().DB,
			TLSConfig: rdb.Options().TLSConfig,
		}
		asynqSrv := asynq.NewServer(asynqRedisOpt, asynq.Config{
			Concurrency: 8,
			Queues:      map[string]int{"default": 1},
		})
		asynqMux := asynq.NewServeMux()
		asynqMux.HandleFunc(bots.TypeLudoBotMove, coord.HandleLudoBotMoveTask)
		go func() {
			if err := asynqSrv.Run(asynqMux); err != nil {
				logger.Error("asynq server error", zap.Error(err))
			}
		}()
		logger.Info("asynq bot worker registered",
			zap.String("tasks", "ludo_bot:move"),
		)
	} else {
		logger.Warn("asynq bot worker NOT started — hub.BotCoordinatorAsynq() is nil (ludo bot will use in-memory fallback)")
	}

	// Custom Emojis
	emojiHandler := handlers.NewEmojiHandler(db.Pool(), logger)
	protected.HandleFunc("/servers/{serverId}/emojis", emojiHandler.GetServerEmojis).Methods("GET")
	protected.HandleFunc("/servers/{serverId}/emojis", emojiHandler.CreateEmoji).Methods("POST")

	// Music Bot State
	musicHandler := handlers.NewMusicHandler(db.Pool(), logger)
	protected.HandleFunc("/servers/{serverId}/music/state", musicHandler.GetMusicState).Methods("GET")

	// Message creation (for timeouts, silent, mentions, idempotency)
	msgHandler := handlers.NewMessageHandler(db.Pool(), logger).WithRedis(redisCache.GetRedisClient())
	// Inject AI moderation so every send runs Llama-Guard before insert.
	// Gated by the same flag — when off the handler skips the classifier.
	if cfg.AIModerationEnabled {
		msgHandler.WithModeration(moderationSvc)
	}
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

	protected.Handle("/channels/{channelId}/messages/{messageId}/read", throttler.Throttle(1*time.Second)(http.HandlerFunc(readStateHandler.MarkAsRead))).Methods("POST")
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
	protected.HandleFunc("/e2ee/identity/attestation", e2eeHandler.PutIdentityAttestation).Methods("POST")
	protected.HandleFunc("/e2ee/identity/attestation/{userId}", e2eeHandler.GetIdentityAttestation).Methods("GET")
	protected.HandleFunc("/e2ee/devices/{userId}", e2eeHandler.ListDevices).Methods("GET")
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
	protected.Handle("/users/@me/config", cacheMiddleware.Cache(middleware.CacheShort)(http.HandlerFunc(flagsHandler.GetConfig))).Methods("GET")



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
