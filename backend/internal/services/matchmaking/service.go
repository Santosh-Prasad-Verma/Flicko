package matchmaking

import (
	"context"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

var (
	ErrQueueTimeout = errors.New("matchmaking queue timeout")
	ErrNoMatch      = errors.New("no match found")
)

// Lua script to atomically find and pop two eligible players from the queue
// ARGV[1] = current time (Unix epoch) to check expiry
const matchPlayersLua = `
local queueKey = KEYS[1]
local now = tonumber(ARGV[1])

-- Find the top 2 oldest entries in the queue (lowest scores/earliest expiries)
local players = redis.call('ZRANGE', queueKey, 0, 1, 'WITHSCORES')

if #players < 4 then
	-- Not enough players (returns pairs of user, score)
	return {}
end

local p1 = players[1]
local score1 = tonumber(players[2])
local p2 = players[3]
local score2 = tonumber(players[4])

-- Check if either player has expired
if score1 < now or score2 < now then
	-- One or both expired, we must prune expired.
	-- We remove anything older than 'now'
	redis.call('ZREMRANGEBYSCORE', queueKey, '-inf', '(' .. now)
	return {}
end

-- Both are valid, pop them
redis.call('ZREM', queueKey, p1, p2)

return {p1, p2}
`

type MatchmakingService interface {
	JoinQueue(ctx context.Context, gameType, userID string) error
	HeartbeatQueue(ctx context.Context, gameType, userID string) error
	AttemptMatch(ctx context.Context, gameType string) ([]string, error)
}

type matchmakingService struct {
	redisClient *redis.Client
	logger      *zap.Logger
}

func NewMatchmakingService(rc *redis.Client, logger *zap.Logger) MatchmakingService {
	return &matchmakingService{
		redisClient: rc,
		logger:      logger,
	}
}

// JoinQueue adds a user to the Redis Sorted Set queue with an expiry timestamp
func (s *matchmakingService) JoinQueue(ctx context.Context, gameType, userID string) error {
	queueKey := "queue:" + gameType
	expiry := time.Now().Add(30 * time.Second).Unix()

	err := s.redisClient.ZAdd(ctx, queueKey, redis.Z{
		Score:  float64(expiry),
		Member: userID,
	}).Err()

	if err != nil {
		s.logger.Error("failed to join queue", zap.Error(err), zap.String("userID", userID))
		return err
	}
	return nil
}

// HeartbeatQueue updates the TTL (score) of a queue entry using GT.
// GT ensures the score can only be increased (pushed further into the future).
// Since we use ZRANGE ascending (lowest score/oldest expiry is matched first),
// a malicious client sending a tiny score to jump to the front will be rejected by GT.
func (s *matchmakingService) HeartbeatQueue(ctx context.Context, gameType, userID string) error {
	queueKey := "queue:" + gameType
	expiry := time.Now().Add(30 * time.Second).Unix()

	// ZAddArgs with XX and GT requires Redis 6.2+
	// XX prevents recreating a popped user, GT prevents score shrinking.
	err := s.redisClient.ZAddArgs(ctx, queueKey, redis.ZAddArgs{
		XX: true,
		GT: true,
		Members: []redis.Z{
			{Score: float64(expiry), Member: userID},
		},
	}).Err()

	if err != nil {
		return err
	}
	return nil
}

// AttemptMatch runs the Lua script to atomically pop two matched players
func (s *matchmakingService) AttemptMatch(ctx context.Context, gameType string) ([]string, error) {
	queueKey := "queue:" + gameType
	now := time.Now().Unix()

	result, err := s.redisClient.Eval(ctx, matchPlayersLua, []string{queueKey}, now).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, ErrNoMatch
		}
		return nil, err
	}

	players, ok := result.([]interface{})
	if !ok || len(players) != 2 {
		return nil, ErrNoMatch
	}

	p1, ok1 := players[0].(string)
	p2, ok2 := players[1].(string)
	if !ok1 || !ok2 {
		return nil, ErrNoMatch
	}

	return []string{p1, p2}, nil
}
