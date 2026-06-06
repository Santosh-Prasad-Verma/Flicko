package gaming

import (
	"context"
	"encoding/json"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots"
	"github.com/flicko-org/flicko-backend/internal/bots/chess"
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
	chessValidator *gameSvc.ChessValidator
	ludoValidator  *gameSvc.LudoValidator
	ludoEngine     gameSvc.LudoEngine
	stockfishPool  chess.StockfishPool
	botCoordinator bots.BotCoordinator
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

// hubGameService implements bots.GameService
type hubGameService struct {
	stateService   gameSvc.StateService
	chessValidator *gameSvc.ChessValidator
}

// hubStateReader adapts gameSvc.StateService to bots.StateReader.
type hubStateReader struct {
	stateService gameSvc.StateService
}

func (r *hubStateReader) GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error) {
	return r.stateService.GetGameState(ctx, gameID)
}

func (s *hubGameService) ProcessMove(ctx context.Context, gameID, playerID, move string) error {
	stateRaw, moveNum, err := s.stateService.GetGameState(ctx, gameID)
	if err != nil {
		return err
	}
	var st struct {
		Fen string `json:"fen"`
	}
	if err := json.Unmarshal(stateRaw, &st); err != nil {
		return err
	}
	
	newGame, reason, err := s.chessValidator.ProcessMove(ctx, gameID, playerID, st.Fen, move)
	if err != nil {
		return err
	}
	_ = reason
	
	// Create new state
	newState := struct {
		Fen string `json:"fen"`
	}{
		Fen: newGame.FEN(),
	}
	
	newStateBytes, _ := json.Marshal(newState)
	return s.stateService.SaveState(ctx, gameID, newStateBytes, moveNum+1)
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

	// 4. Game Logic Validators
	chessValidator := gameSvc.NewChessValidator(lockService)
	ludoValidator := gameSvc.NewLudoValidator(rngSvc)
	ludoEngine := gameSvc.NewLudoEngineWithPublisher(stateService, ludoValidator, lockService, rngSvc, publisher)

	// 5. Bot Intelligence
	// Creates a bounded pool of 10 persistent stockfish engines
	stockfishPool, err := chess.NewStockfishPool(10, logger)
	if err != nil {
		return nil, err
	}

	gameSvcAdapter := &hubGameService{stateService: stateService, chessValidator: chessValidator}
	botCoordinator := bots.NewBotCoordinator(stockfishPool, gameSvcAdapter, lockService, logger)

	// 5b. Asynq-backed coordinator (HIGH-15 + CRIT-9 wiring).
	// Survives pod restart since tasks live in Redis.
	asynqClient := asynq.NewClient(asynq.RedisClientOpt{
		Addr:      rc.Options().Addr,
		Password:  rc.Options().Password,
		DB:        rc.Options().DB,
		TLSConfig: rc.Options().TLSConfig,
	})
	asynqCoord := bots.NewAsynqBotCoordinator(
		asynqClient,
		stockfishPool,
		gameSvcAdapter,
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
		chessValidator: chessValidator,
		ludoValidator:  ludoValidator,
		ludoEngine:     ludoEngine,
		stockfishPool:  stockfishPool,
		botCoordinator: botCoordinator,
		asynqCoord:     asynqCoord,
	}, nil
}

// Shutdown gracefully stops all async processing, drains channels, and kills OS processes.
func (h *Hub) Shutdown() {
	if h.gameRepo != nil {
		h.gameRepo.StopAsyncWriter()
	}
	if h.stockfishPool != nil {
		h.stockfishPool.Close()
	}
}
