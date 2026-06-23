package bots

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/repo/cache"
	gameSvc "github.com/flicko-org/flicko-backend/internal/services/game"
	"github.com/hibiken/asynq"
	"go.uber.org/zap"
)

const (
	TypeLudoBotMove = "ludo_bot:move"
)

// LudoBotMovePayload represents the task payload for async bot moves (Ludo)
type LudoBotMovePayload struct {
	GameID   string `json:"game_id"`
	PlayerID string `json:"player_id"`
}

// LockService defines the distributed lock manager interface.
type LockService interface {
	AcquireLock(ctx context.Context, key, token string, ttl time.Duration) (bool, error)
	ReleaseLock(ctx context.Context, key, token string) error
}

// AsynqBotCoordinator enqueues bot moves via Asynq instead of in-memory goroutines.
// This guarantees execution even if the pod crashes mid-turn.
type AsynqBotCoordinator struct {
	client       *asynq.Client
	lockService  LockService
	stateService StateReader
	ludoEngine   gameSvc.LudoEngine
	logger       *zap.Logger
}

// StateReader reads game state for bot context
type StateReader interface {
	GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error)
}

// NewAsynqBotCoordinator creates a coordinator that dispatches bot moves as async tasks
func NewAsynqBotCoordinator(
	client *asynq.Client,
	lockSvc LockService,
	stateSvc StateReader,
	ludoEng gameSvc.LudoEngine,
	logger *zap.Logger,
) *AsynqBotCoordinator {
	return &AsynqBotCoordinator{
		client:       client,
		lockService:  lockSvc,
		stateService: stateSvc,
		ludoEngine:   ludoEng,
		logger:       logger,
	}
}

// EnqueueLudoBotMove schedules a delayed Asynq task for the ludo bot turn.
func (c *AsynqBotCoordinator) EnqueueLudoBotMove(ctx context.Context, gameID, playerID string) error {
	if c.client == nil {
		c.logger.Debug("asynq client is nil, skipping ludo bot move enqueue")
		return nil
	}

	payload, err := json.Marshal(LudoBotMovePayload{
		GameID:   gameID,
		PlayerID: playerID,
	})
	if err != nil {
		return err
	}

	// Random delay 800ms-2s for Ludo rolls/moves
	delay := 800*time.Millisecond + time.Duration(time.Now().UnixNano()%1200)*time.Millisecond

	task := asynq.NewTask(TypeLudoBotMove, payload)

	info, err := c.client.EnqueueContext(ctx, task,
		asynq.ProcessIn(delay),
		asynq.MaxRetry(3),
		asynq.Timeout(10*time.Second),
	)
	if err != nil {
		c.logger.Error("failed to enqueue ludo bot move task",
			zap.Error(err),
			zap.String("game_id", gameID),
		)
		return err
	}

	c.logger.Debug("ludo bot move task enqueued",
		zap.String("task_id", info.ID),
		zap.String("game_id", gameID),
	)
	return nil
}

// HandleLudoBotMoveTask processes the Ludo Bot dice roll or token move atomically.
func (c *AsynqBotCoordinator) HandleLudoBotMoveTask(ctx context.Context, t *asynq.Task) error {
	var payload LudoBotMovePayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		c.logger.Error("failed to unmarshal ludo bot payload", zap.Error(err))
		return fmt.Errorf("invalid payload: %w", err)
	}

	lockKey := cache.GenerateGameLockKey(payload.GameID)
	token := fmt.Sprintf("ludobot-%d", time.Now().UnixNano())

	acquired, err := c.lockService.AcquireLock(ctx, lockKey, token, 10*time.Second)
	if err != nil || !acquired {
		return nil // Lock held elsewhere
	}
	defer c.lockService.ReleaseLock(context.Background(), lockKey, token)

	// Fetch current Ludo game state
	state, err := c.ludoEngine.GetGameState(ctx, payload.GameID)
	if err != nil {
		c.logger.Error("failed to fetch ludo game state", zap.Error(err), zap.String("game_id", payload.GameID))
		return err
	}

	if state.Status != "active" {
		return nil // Match completed
	}

	activePlayerID := state.Players[state.ActivePlayerIndex]
	if activePlayerID != payload.PlayerID {
		return nil // Not this bot's turn
	}

	// 1. Roll dice if turn has not yet been rolled
	if state.Turn == nil || state.Turn.IsConsumed || state.Turn.DiceValue == 0 {
		c.logger.Debug("ludo bot rolling dice", zap.String("game_id", payload.GameID), zap.String("bot_id", payload.PlayerID))
		rolledState, err := c.ludoEngine.RollDice(ctx, payload.GameID, payload.PlayerID)
		if err != nil {
			return err
		}
		
		// If the roll resulted in NO legal moves, the engine automatically consumed
		// the roll and rotated the active player. We exit cleanly.
		if rolledState.Turn.IsConsumed || rolledState.ActivePlayerIndex != state.ActivePlayerIndex {
			c.logger.Debug("ludo bot roll auto-consumed (no legal moves)", zap.String("game_id", payload.GameID))
			return nil
		}
		state = rolledState
	}

	// 2. Select the optimal token to move using Probabilistic Priority Scoring
	roll := state.Turn.DiceValue
	bestTokenID := -1
	bestScore := -1

	for _, tok := range state.Tokens {
		if tok.PlayerID == payload.PlayerID {
			// Check if token can legally move
			isLegal := false
			if tok.ProgressionIndex == -1 {
				if roll == 6 {
					isLegal = true
				}
			} else {
				if tok.ProgressionIndex+roll <= 57 {
					isLegal = true
				}
			}

			if isLegal {
				score := c.evaluateLudoMovePriority(state, tok, roll)
				if score > bestScore {
					bestScore = score
					bestTokenID = tok.ID
				}
			}
		}
	}

	if bestTokenID == -1 {
		c.logger.Warn("ludo bot has no legal moves after roll", zap.String("game_id", payload.GameID), zap.Int("roll", roll))
		return nil
	}

	// 3. Execute the optimal token move
	c.logger.Info("ludo bot moving token", zap.String("game_id", payload.GameID), zap.Int("token_id", bestTokenID), zap.Int("roll", roll))
	newState, err := c.ludoEngine.MoveToken(ctx, payload.GameID, payload.PlayerID, bestTokenID)
	if err != nil {
		return err
	}

	// 4. If the bot gets to roll again (rolls a 6 or captures), self-schedule the next move!
	if newState.Status == "active" && newState.Players[newState.ActivePlayerIndex] == payload.PlayerID {
		c.logger.Debug("ludo bot earned extra turn, enqueuing next task", zap.String("game_id", payload.GameID))
		_ = c.EnqueueLudoBotMove(ctx, payload.GameID, payload.PlayerID)
	}

	return nil
}

// evaluateLudoMovePriority computes a priority score for moving a token
func (c *AsynqBotCoordinator) evaluateLudoMovePriority(state *gameSvc.LudoGameState, token *gameSvc.Token, roll int) int {
	score := 10 // Base priority

	// 1. Exit Base priority
	if token.ProgressionIndex == -1 {
		return 80 // Medium-High priority: always exit base if possible
	}

	newProgression := token.ProgressionIndex + roll

	// 2. Finish priority
	if newProgression == 57 {
		return 95 // Highest non-capture priority: finish the token!
	}

	// 3. Collision Capture evaluation
	physicalPos := (token.ColorOffset + newProgression) % 52
	isCapture := false
	for _, otherToken := range state.Tokens {
		if otherToken.PlayerID != token.PlayerID && otherToken.ProgressionIndex >= 0 && otherToken.ProgressionIndex <= 50 {
			otherPhysical := (otherToken.ColorOffset + otherToken.ProgressionIndex) % 52
			if physicalPos == otherPhysical {
				// Verify target spot is not safe
				if !gameSvc.SafeSquares[physicalPos] {
					isCapture = true
					break
				}
			}
		}
	}

	if isCapture {
		return 100 // Maximum priority: ALWAYS capture opponents!
	}

	// 4. Safe Square priority
	if gameSvc.SafeSquares[physicalPos] {
		score += 30 // Land on safe square
	}

	// 5. Prefer moving pieces that are further ahead
	score += token.ProgressionIndex

	return score
}
