package bots

import (
	"context"
        "encoding/json"

	"github.com/flicko-org/flicko-backend/internal/repo/cache"
	"github.com/hibiken/asynq"
	"go.uber.org/zap"
)

const (
	TypeBotMove = "bot:move"
)

// BotMovePayload represents the task payload for async bot moves
type BotMovePayload struct {
	GameID     string `json:"game_id"`
	PlayerID   string `json:"player_id"`
	FEN        string `json:"fen"`
	Difficulty int    `json:"difficulty"`
}

// AsynqBotCoordinator enqueues bot moves via Asynq instead of in-memory goroutines.
// This guarantees execution even if the pod crashes mid-turn.
type AsynqBotCoordinator struct {
	client       asynq.Client
	stockfish    StockfishPool
	gameService  GameService
	lockService  LockService
	stateService StateReader
	logger       *zap.Logger
}

// StateReader reads game state for bot context
type StateReader interface {
	GetGameState(ctx context.Context, gameID string) ([]byte, int, error)
}

// NewAsynqBotCoordinator creates a coordinator that dispatches bot moves as async tasks
func NewAsynqBotCoordinator(
	client asynq.Client,
	pool StockfishPool,
	gameSvc GameService,
	lockSvc LockService,
	stateSvc StateReader,
	logger *zap.Logger,
) *AsynqBotCoordinator {
	return &AsynqBotCoordinator{
		client:       client,
		stockfish:    pool,
		gameService:  gameSvc,
		lockService:  lockSvc,
		stateService: stateSvc,
		logger:       logger,
	}
}

// EnqueueBotMove schedules a delayed Asynq task for the bot turn.
// The delay simulates realistic "thinking time" and prevents instant moves.
func (c *AsynqBotCoordinator) EnqueueBotMove(ctx context.Context, gameID, playerID, fen string, difficulty int) error {
	payload, err := json.Marshal(BotMovePayload{
		GameID:     gameID,
		PlayerID:   playerID,
		FEN:        fen,
		Difficulty: difficulty,
	})
	if err != nil {
		return err
	}

	// Random delay 500ms-2s for realistic feel
	delay := 500*time.Millisecond + time.Duration(time.Now().UnixNano()%1500)*time.Millisecond

	task := asynq.NewTask(TypeBotMove, payload)

	info, err := c.client.EnqueueContext(ctx, task,
		asynq.ProcessIn(delay),
		asynq.MaxRetry(3),
		asynq.Timeout(10*time.Second),
	)
	if err != nil {
		c.logger.Error("failed to enqueue bot move task",
			zap.Error(err),
			zap.String("game_id", gameID),
		)
		return err
	}

	c.logger.Debug("bot move task enqueued",
		zap.String("task_id", info.ID),
		zap.String("game_id", gameID),
	)
	return nil
}

// HandleBotMoveTask is the Asynq handler that processes bot moves.
// It acquires a lock, queries Stockfish, and processes the move.
func (c *AsynqBotCoordinator) HandleBotMoveTask(ctx context.Context, t *asynq.Task) error {
	var payload BotMovePayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		c.logger.Error("failed to unmarshal bot move payload", zap.Error(err))
		return fmt.Errorf("invalid payload: %w", err)
	}

	// Check for abandonment before proceeding
        _ = cache.GenerateAbandonmentKey(payload.GameID, payload.PlayerID)
	// For now, we proceed if we can acquire the lock

	lockKey := cache.GenerateGameLockKey(payload.GameID)
	token := fmt.Sprintf("bot-%d", time.Now().UnixNano())

	acquired, err := c.lockService.AcquireLock(ctx, lockKey, token, 10*time.Second)
	if err != nil || !acquired {
		c.logger.Debug("bot failed to acquire lock (another pod handling)",
			zap.String("game_id", payload.GameID),
		)
		return nil // Not an error - another worker is handling it
	}
	defer c.lockService.ReleaseLock(context.Background(), lockKey, token)

	// Query Stockfish for best move
	move, err := c.stockfish.GetNextMove(ctx, payload.FEN, payload.Difficulty)
	if err != nil {
		c.logger.Error("stockfish failed to generate move",
			zap.Error(err),
			zap.String("game_id", payload.GameID),
		)
		return fmt.Errorf("stockfish error: %w", err)
	}

	// Process the move through game service
	if err := c.gameService.ProcessMove(ctx, payload.GameID, payload.PlayerID, move); err != nil {
		c.logger.Error("bot failed to process move",
			zap.Error(err),
			zap.String("game_id", payload.GameID),
			zap.String("move", move),
		)
		return err
	}

	c.logger.Info("bot move processed successfully",
		zap.String("game_id", payload.GameID),
		zap.String("move", move),
	)
	return nil
}
