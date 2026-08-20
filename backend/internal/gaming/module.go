package gaming

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/url"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots"
	"github.com/flicko-org/flicko-backend/internal/handlers/centrifugo"
	"github.com/flicko-org/flicko-backend/internal/handlers/game"
	"github.com/flicko-org/flicko-backend/internal/repo"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/flicko-org/flicko-backend/internal/services/elo"
	gameSvc "github.com/flicko-org/flicko-backend/internal/services/game"
	"github.com/flicko-org/flicko-backend/internal/services/lock"
	"github.com/flicko-org/flicko-backend/internal/services/matchmaking"
	"github.com/flicko-org/flicko-backend/internal/services/ratelimit"
	"github.com/flicko-org/flicko-backend/internal/services/rng"
	"github.com/gorilla/mux"
	"github.com/hibiken/asynq"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

type Hub struct {
	gameRepo       repo.GameRepo
	stateService   gameSvc.StateService
	lockService    lock.LockService
	matchmakingSvc matchmaking.MatchmakingService
	ludoValidator  *gameSvc.LudoValidator
	ludoEngine     gameSvc.LudoEngine
	asynqCoord     *bots.AsynqBotCoordinator // CRIT-9: exposed for main.go worker registration
}

// BotCoordinatorAsynq returns the AsynqBotCoordinator if available (may be nil).
func (h *Hub) BotCoordinatorAsynq() *bots.AsynqBotCoordinator {
	return h.asynqCoord
}

// hubGameAccessValidator implements centrifugo.GameAccessValidator
type hubGameAccessValidator struct {
	stateService gameSvc.StateService
}

func (v *hubGameAccessValidator) GetGameStatusAndPlayers(ctx context.Context, gameID string) (string, string, string, error) {
	stateRaw, _, err := v.stateService.GetGameState(ctx, gameID)
	if err != nil {
		return "", "", "", err
	}
	var st struct {
		Status  string `json:"status"`
		PlayerA string `json:"playerA"`
		PlayerB string `json:"playerB"`
	}
	if err := json.Unmarshal(stateRaw, &st); err != nil {
		return "", "", "", err
	}
	return st.Status, st.PlayerA, st.PlayerB, nil
}

// hubStateReader adapts gameSvc.StateService to bots.StateReader.
type hubStateReader struct {
	stateService gameSvc.StateService
}

func (r *hubStateReader) GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error) {
	return r.stateService.GetGameState(ctx, gameID)
}

// Initialize bootstraps all gaming hub components, orchestrates dependency injection,
// and mounts the necessary API routes to the router.
//
// [publisher] is used to broadcast authoritative game events (dice rolls,
// moves, winners) on Centrifugo channels. Pass `centrifugoSvc.NopPublisher{}`
// in tests or environments without Centrifugo.
func Initialize(
	ctx context.Context,
	logger *zap.Logger,
	db *pgxpool.Pool,
	rc *redis.Client,
	r *mux.Router,
	publisher centrifugoSvc.Publisher,
	asynqRedisURL string,
) (*Hub, error) {
	logger.Info("initializing gaming hub module")

	if publisher == nil {
		publisher = centrifugoSvc.NopPublisher{}
	}

	// 1. Data Layer & Persistence
	// Buffer size 10,000; flushes every 100 records or 200ms using pgx.CopyFrom
	gameRepo := repo.NewGameRepo(db, logger, 10000, 100, 200*time.Millisecond)
	gameRepo.StartAsyncWriter(ctx)

	stateService := gameSvc.NewStateService(logger, rc, gameRepo)

	// 2. Foundation Services
	rngSvc := rng.NewRNGService()
	eloService := elo.NewELOService(32.0)
	lockService := lock.NewLockService(rc, logger)
	rateLimiter := ratelimit.NewTokenBucket(rc, logger)

	// 3. Matchmaking
	matchmakingSvc := matchmaking.NewMatchmakingService(rc, logger)

	// 4. Game Logic Validators (Ludo only — Chess has been removed)
	ludoValidator := gameSvc.NewLudoValidator(rngSvc)
	ludoEngine := gameSvc.NewLudoEngineWithPublisher(stateService, ludoValidator, lockService, rngSvc, publisher)

	// 5. Asynq-backed coordinator (Ludo bot tasks survive pod restart via Redis).
	// NOTE: asynq uses Lua EVAL scripts which are incompatible with Redis Cluster
	// (Azure Redis Enterprise). Use a separate standalone Redis URL for asynq.
	asynqRedisOpt, asynqErr := buildAsynqRedisOpt(asynqRedisURL, rc, logger)
	if asynqErr != nil {
		return nil, fmt.Errorf("failed to build asynq redis opts: %w", asynqErr)
	}
	asynqClient := asynq.NewClient(asynqRedisOpt)
	asynqCoord := bots.NewAsynqBotCoordinator(
		asynqClient,
		lockService,
		&hubStateReader{stateService: stateService},
		ludoEngine,
		logger,
	)

	// 6. Edge Handlers (API & Proxy)
	proxyHandler := centrifugo.NewCentrifugoProxyHandler(logger, &hubGameAccessValidator{stateService: stateService})
	rejoinHandler := game.NewRejoinHandler(logger, stateService)
	ludoHandler := game.NewLudoHandler(logger, ludoEngine)
	statsHandler := game.NewStatsHandler(db, logger)
	ludoScoreHandler := game.NewLudoScoreHandler(db, logger)

	// 7. Route Mounting
	api := r.PathPrefix("/api/v1/gaming").Subrouter()
	
	// API routes (e.g. rate-limited action endpoints)
	// Implement generic rate limiting middleware wrappers around these in a real setup
	_ = rateLimiter
	_ = eloService
	
	api.HandleFunc("/rejoin", rejoinHandler.HandleRejoin).Methods("POST")
	api.HandleFunc("/ludo/roll", ludoHandler.HandleRoll).Methods("POST")
	api.HandleFunc("/ludo/move", ludoHandler.HandleMove).Methods("POST")
	api.HandleFunc("/ludo/state/{gameId}", ludoHandler.HandleGetState).Methods("GET")
	api.HandleFunc("/ludo/score", ludoScoreHandler.HandleSubmitScore).Methods("POST")
	api.HandleFunc("/ludo/leaderboard", ludoScoreHandler.HandleLeaderboard).Methods("GET")
	api.HandleFunc("/stats", statsHandler.HandleGetStats).Methods("GET")
	
	// Centrifugo proxy hook endpoints
	centriRouter := r.PathPrefix("/centrifugo").Subrouter()
	centriRouter.HandleFunc("/subscribe", proxyHandler.HandleSubscribeProxy).Methods("POST")

	logger.Info("gaming hub initialized successfully")

	return &Hub{
		gameRepo:       gameRepo,
		stateService:   stateService,
		lockService:    lockService,
		matchmakingSvc: matchmakingSvc,
		ludoValidator:  ludoValidator,
		ludoEngine:     ludoEngine,
		asynqCoord:     asynqCoord,
	}, nil
}

// Shutdown gracefully stops all async processing and drains channels.
func (h *Hub) Shutdown() {
	if h.gameRepo != nil {
		h.gameRepo.StopAsyncWriter()
	}
}

// buildAsynqRedisOpt creates the asynq RedisClientOpt from a dedicated URL
// (typically a local standalone Redis) to avoid MOVED errors from Azure Redis
// Cluster. Falls back to main Redis client options if asynqURL is empty.
func buildAsynqRedisOpt(asynqURL string, rc *redis.Client, logger *zap.Logger) (asynq.RedisClientOpt, error) {
	if asynqURL == "" {
		logger.Info("asynq: no dedicated ASYNQ_REDIS_URL, using main Redis client options")
		return asynq.RedisClientOpt{
			Addr:      rc.Options().Addr,
			Password:  rc.Options().Password,
			DB:        rc.Options().DB,
			TLSConfig: rc.Options().TLSConfig,
		}, nil
	}

	parsed, err := url.Parse(asynqURL)
	if err != nil {
		return asynq.RedisClientOpt{}, fmt.Errorf("failed to parse ASYNQ_REDIS_URL: %w", err)
	}

	opt := asynq.RedisClientOpt{
		Addr: parsed.Host,
	}

	if parsed.User != nil {
		opt.Password, _ = parsed.User.Password()
	}

	if parsed.Scheme == "rediss" {
		opt.TLSConfig = &tls.Config{
			ServerName: parsed.Hostname(),
		}
	}

	logger.Info("asynq: using dedicated standalone Redis",
		zap.String("addr", opt.Addr),
		zap.Bool("tls", opt.TLSConfig != nil),
	)

	return opt, nil
}
