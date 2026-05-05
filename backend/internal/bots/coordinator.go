package bots

import (
	"context"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

// BotCoordinator listens to game updates and executes bot turns.
type BotCoordinator interface {
	AfterMoveHook(ctx context.Context, gameID string, nextPlayerID string, isBot bool, fen string, botDiff int)
}

type botCoordinator struct {
	stockfishPool StockfishPool
	gameService   GameService
	lockService   LockService
	logger        *zap.Logger
}

type GameService interface {
	ProcessMove(ctx context.Context, gameID, playerID, move string) error
}

type LockService interface {
	AcquireLock(ctx context.Context, key, token string, ttl time.Duration) (bool, error)
	ReleaseLock(ctx context.Context, key, token string) error
}

// Interface for stockfish pool to allow clean dependency injection
type StockfishPool interface {
	GetNextMove(ctx context.Context, fen string, difficulty int) (string, error)
}

func NewBotCoordinator(
	pool StockfishPool,
	gameSvc GameService,
	lockSvc LockService,
	logger *zap.Logger,
) BotCoordinator {
	return &botCoordinator{
		stockfishPool: pool,
		gameService:   gameSvc,
		lockService:   lockSvc,
		logger:        logger,
	}
}

// AfterMoveHook is triggered async after any move is processed.
func (c *botCoordinator) AfterMoveHook(ctx context.Context, gameID string, nextPlayerID string, isBot bool, fen string, botDiff int) {
	if !isBot {
		return
	}

	// Run bot turn asynchronously to prevent blocking the HTTP/WebSocket request
	go func() {
		// Realistic delay so the bot doesn't instantly move
		// Wait 500ms to 2s
		delay := 500*time.Millisecond + time.Duration(time.Now().UnixNano()%1500)*time.Millisecond
		time.Sleep(delay)

		// Create a separate background context for the bot execution
		botCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		lockKey := "game:" + gameID + ":lock"
		token := uuid.New().String()

		// Attempt to acquire game lock to ensure atomic turns.
		// If another instance acquired it, we simply abort (only one worker processes the move).
		acquired, err := c.lockService.AcquireLock(botCtx, lockKey, token, 10*time.Second)
		if err != nil || !acquired {
			c.logger.Debug("bot failed to acquire lock (likely another pod picked it up)", zap.String("game", gameID))
			return
		}

		defer c.lockService.ReleaseLock(context.Background(), lockKey, token)

		// Query Stockfish
		move, err := c.stockfishPool.GetNextMove(botCtx, fen, botDiff)
		if err != nil {
			c.logger.Error("bot failed to generate move", zap.Error(err), zap.String("game", gameID))
			return
		}

		// Process move
		err = c.gameService.ProcessMove(botCtx, gameID, nextPlayerID, move)
		if err != nil {
			c.logger.Error("bot failed to process move", zap.Error(err), zap.String("game", gameID))
		}
	}()
}
