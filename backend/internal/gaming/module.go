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
	"github.com/flicko-org/flicko-backend/internal/services/elo"
	gameSvc "github.com/flicko-org/flicko-backend/internal/services/game"
	"github.com/flicko-org/flicko-backend/internal/services/lock"
	"github.com/flicko-org/flicko-backend/internal/services/matchmaking"
	"github.com/flicko-org/flicko-backend/internal/services/ratelimit"
	"github.com/flicko-org/flicko-backend/internal/services/rng"
	"github.com/gorilla/mux"
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
func Initialize(ctx context.Context, logger *zap.Logger, db *pgxpool.Pool, rc *redis.Client, r *mux.Router) (*Hub, error) {
	logger.Info("initializing gaming hub module")

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
	ludoEngine := gameSvc.NewLudoEngine(stateService, ludoValidator, lockService, rngSvc)

	// 5. Bot Intelligence
	// Creates a bounded pool of 10 persistent stockfish engines
	stockfishPool, err := chess.NewStockfishPool(10, logger)
	if err != nil {
		return nil, err
	}
	
	botCoordinator := bots.NewBotCoordinator(stockfishPool, &hubGameService{stateService: stateService, chessValidator: chessValidator}, lockService, logger)

	// 6. Edge Handlers (API & Proxy)
	proxyHandler := centrifugo.NewCentrifugoProxyHandler(logger, &hubGameAccessValidator{stateService: stateService})
	rejoinHandler := game.NewRejoinHandler(logger, stateService)
	ludoHandler := game.NewLudoHandler(logger, ludoEngine)

	// 7. Route Mounting
	api := r.PathPrefix("/api/v1/gaming").Subrouter()
	
	// API routes (e.g. rate-limited action endpoints)
	// Implement generic rate limiting middleware wrappers around these in a real setup
	_ = rateLimiter
	_ = eloService
	
	api.HandleFunc("/rejoin", rejoinHandler.HandleRejoin).Methods("POST")
	api.HandleFunc("/ludo/roll", ludoHandler.HandleRoll).Methods("POST")
	api.HandleFunc("/ludo/move", ludoHandler.HandleMove).Methods("POST")
	
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
