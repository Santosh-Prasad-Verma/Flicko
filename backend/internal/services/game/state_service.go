package game

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"time"

	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/flicko-org/flicko-backend/internal/repo/cache"
	"github.com/jackc/pgx/v5"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

var (
	ErrGameNotFound = errors.New("game state not found")
)

type StateService interface {
	SaveState(ctx context.Context, gameID string, state json.RawMessage, moveNum int) error
	GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error)
	GetAuthoritativeMoveNum(ctx context.Context, gameID string) (int, string, error)
}

type stateService struct {
	logger   *zap.Logger
	redis    *redis.Client
	gameRepo repo.GameRepo
}

func NewStateService(logger *zap.Logger, redisClient *redis.Client, gameRepo repo.GameRepo) StateService {
	return &stateService{
		logger:   logger,
		redis:    redisClient,
		gameRepo: gameRepo,
	}
}

// SaveState performs the write-behind caching.
// It sets the state in Redis synchronously, then non-blockingly pushes to the PGX CopyFrom worker.
func (s *stateService) SaveState(ctx context.Context, gameID string, state json.RawMessage, moveNum int) error {
	stateKey := cache.GenerateGameStateKey(gameID)
	moveNumKey := cache.GenerateGameMoveNumKey(gameID)

	// Pipeline the Redis writes to minimize RTT
	pipe := s.redis.Pipeline()
	pipe.Set(ctx, stateKey, state, 2*time.Hour)
	pipe.Set(ctx, moveNumKey, moveNum, 2*time.Hour)
	
	if _, err := pipe.Exec(ctx); err != nil {
		s.logger.Error("failed to sync state to redis", zap.Error(err), zap.String("game_id", gameID))
		return err
	}

	// Push to async buffered channel for PostgreSQL bulk insert via CopyFrom
	s.gameRepo.QueueStateSave(repo.GameStateRecord{
		GameID:    gameID,
		State:     state,
		MoveNum:   moveNum,
		CreatedAt: time.Now().UTC(),
	})

	return nil
}

// GetGameState fetches the state, recovering from Redis Pod crashes by checking the version sequence
func (s *stateService) GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error) {
	stateKey := cache.GenerateGameStateKey(gameID)
	moveNumKey := cache.GenerateGameMoveNumKey(gameID)

	stateStr, err := s.redis.Get(ctx, stateKey).Result()
	if err == nil {
		// Cache hit! Verify integrity by checking atomic move_num
		moveNumStr, errNum := s.redis.Get(ctx, moveNumKey).Result()
		if errNum == nil {
			cachedMoveNum, _ := strconv.Atoi(moveNumStr)
			
			// Compare the cache's embedded moveNum with the atomic move_num counter
			// This prevents returning a stale state object if partial Redis evictions occur
			var stateObj struct {
				MoveNum int `json:"moveNum"` // Alternatively, we could just compare to cachedMoveNum directly
			}
			if errDecode := json.Unmarshal([]byte(stateStr), &stateObj); errDecode == nil {
				// If the state's moveNum strictly equals the authoritative moveNum tracker, cache is valid
				if stateObj.MoveNum == cachedMoveNum {
					return json.RawMessage(stateStr), cachedMoveNum, nil
				}
			}
			s.logger.Warn("redis cache version mismatch, falling back to postgres", zap.String("game_id", gameID))
		}
	} else if err != redis.Nil {
		s.logger.Error("redis error fetching game state", zap.Error(err), zap.String("game_id", gameID))
	}

	// Fallback to absolute truth in PostgreSQL
	record, err := s.gameRepo.GetLatestGameState(ctx, gameID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, 0, ErrGameNotFound
		}
		return nil, 0, err
	}

	// Re-warm the Redis cache synchronously so immediate subsequent requests hit cache
	pipe := s.redis.Pipeline()
	pipe.Set(ctx, stateKey, record.State, 2*time.Hour)
	pipe.Set(ctx, moveNumKey, record.MoveNum, 2*time.Hour)
	_, _ = pipe.Exec(ctx)

	return record.State, record.MoveNum, nil
}

// GetAuthoritativeMoveNum returns the absolute source of truth for the game sequence.
func (s *stateService) GetAuthoritativeMoveNum(ctx context.Context, gameID string) (int, string, error) {
	_, moveNum, err := s.GetGameState(ctx, gameID)
	if err != nil {
		if err == ErrGameNotFound {
			return 0, "not_found", nil
		}
		return 0, "error", err
	}
	return moveNum, "ok", nil
}
