package matchmaking

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

var (
	ErrQueueTimeout = errors.New("matchmaking queue timeout")
	ErrNoMatch      = errors.New("no match found")
)

// Lua script to atomically evaluate ELO match window expansion and pop two mutual candidates.
// KEYS[1] = queue sorted set key (queue:{gameType})
// ARGV[1] = current Unix timestamp (seconds)
// ARGV[2] = base ELO tolerance range (e.g., 50)
// ARGV[3] = expansion rate of ELO range per second (e.g., 10)
const matchPlayersLua = `
local queueKey = KEYS[1]
local now = tonumber(ARGV[1])
local baseRange = tonumber(ARGV[2])
local expansionRate = tonumber(ARGV[3])

-- Get all queued players with their ELO scores
local players = redis.call('ZRANGE', queueKey, 0, -1, 'WITHSCORES')

if #players < 4 then
	-- Not enough players in queue (WITHSCORES returns pairs of [member, score])
	return {}
end

local oldestMember = nil
local oldestP = nil
local oldestJoinTime = now + 999999
local oldestElo = 0
local oldestIndex = 0

-- 1. Find the oldest player in the queue (the one who has been waiting longest)
for i = 1, #players, 2 do
	local member = players[i]
	local elo = tonumber(players[i+1])
	
	local colonIdx = string.find(member, ":")
	if colonIdx then
		local pID = string.sub(member, 1, colonIdx - 1)
		local joinTime = tonumber(string.sub(member, colonIdx + 1))
		
		-- Prune expired entries: if joinTime is older than 60s, remove it
		if now - joinTime > 60 then
			redis.call('ZREM', queueKey, member)
		elseif joinTime < oldestJoinTime then
			oldestJoinTime = joinTime
			oldestMember = member
			oldestP = pID
			oldestElo = elo
			oldestIndex = i
		end
	end
end

if not oldestMember then
	return {}
end

-- 2. Calculate the oldest player's wait time and dynamic ELO band
local waitSec = math.max(0, now - oldestJoinTime)
local allowedDiff = baseRange + (waitSec * expansionRate)

local bestCandidateMember = nil
local bestCandidateP = nil
local bestGap = 999999

-- 3. Scan other queued players to find a mutually eligible match candidate
for i = 1, #players, 2 do
	if i ~= oldestIndex then
		local member = players[i]
		local elo = tonumber(players[i+1])
		
		local colonIdx = string.find(member, ":")
		if colonIdx then
			local pID = string.sub(member, 1, colonIdx - 1)
			local joinTime = tonumber(string.sub(member, colonIdx + 1))
			
			local eloGap = math.abs(elo - oldestElo)
			if eloGap <= allowedDiff then
				-- Check mutual consent: candidate's own ELO gap tolerance
				local candWait = math.max(0, now - joinTime)
				local candAllowedDiff = baseRange + (candWait * expansionRate)
				
				if eloGap <= candAllowedDiff then
					if eloGap < bestGap then
						bestGap = eloGap
						bestCandidateMember = member
						bestCandidateP = pID
					end
				end
			end
		end
	end
end

-- 4. Atomically remove matches if a mutually consenting player is found
if bestCandidateMember then
	redis.call('ZREM', queueKey, oldestMember, bestCandidateMember)
	return {oldestP, bestCandidateP}
end

return {}
`

type MatchmakingService interface {
	JoinQueue(ctx context.Context, gameType, userID string, elo int) error
	HeartbeatQueue(ctx context.Context, gameType, userID string, elo int) error
	AttemptMatch(ctx context.Context, gameType string) ([]string, error)
	RemovePlayerFromQueue(ctx context.Context, gameType, userID string) error
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

// JoinQueue adds a user to the Redis Sorted Set queue with ELO as the score
// and user_id:join_timestamp as the compound member.
func (s *matchmakingService) JoinQueue(ctx context.Context, gameType, userID string, elo int) error {
	queueKey := "queue:" + gameType
	now := time.Now().Unix()
	member := fmt.Sprintf("%s:%d", userID, now)

	// Clean up any existing entries for this player to prevent duplicates
	err := s.RemovePlayerFromQueue(ctx, gameType, userID)
	if err != nil {
		s.logger.Warn("failed to clean up player from queue", zap.Error(err), zap.String("userID", userID))
	}

	err = s.redisClient.ZAdd(ctx, queueKey, redis.Z{
		Score:  float64(elo),
		Member: member,
	}).Err()

	if err != nil {
		s.logger.Error("failed to join queue", zap.Error(err), zap.String("userID", userID))
		return err
	}
	return nil
}

// HeartbeatQueue maintains the player's presence in the queue by extending the joinTimestamp
func (s *matchmakingService) HeartbeatQueue(ctx context.Context, gameType, userID string, elo int) error {
	queueKey := "queue:" + gameType

	// Find the current ZSET member for this user
	members, err := s.redisClient.ZRange(ctx, queueKey, 0, -1).Result()
	if err != nil {
		return err
	}

	var foundMember string
	for _, m := range members {
		if strings.HasPrefix(m, userID+":") {
			foundMember = m
			break
		}
	}

	if foundMember == "" {
		// Player popped or not queued, rejoin queue
		return s.JoinQueue(ctx, gameType, userID, elo)
	}

	// Keep existing join time to preserve queue seniority, but update ZSET score if ELO changed
	err = s.redisClient.ZAdd(ctx, queueKey, redis.Z{
		Score:  float64(elo),
		Member: foundMember,
	}).Err()

	return err
}

// AttemptMatch runs the Lua script to atomically evaluate dynamic ELO window expansion and pop matches
func (s *matchmakingService) AttemptMatch(ctx context.Context, gameType string) ([]string, error) {
	queueKey := "queue:" + gameType
	now := time.Now().Unix()

	// Base ELO tolerance = 50, expands by 10 points per second
	result, err := s.redisClient.Eval(ctx, matchPlayersLua, []string{queueKey}, now, 50, 10).Result()
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

// RemovePlayerFromQueue scans and removes a player from the queue
func (s *matchmakingService) RemovePlayerFromQueue(ctx context.Context, gameType, userID string) error {
	queueKey := "queue:" + gameType
	members, err := s.redisClient.ZRange(ctx, queueKey, 0, -1).Result()
	if err != nil {
		return err
	}

	for _, m := range members {
		if strings.HasPrefix(m, userID+":") {
			return s.redisClient.ZRem(ctx, queueKey, m).Err()
		}
	}
	return nil
}
