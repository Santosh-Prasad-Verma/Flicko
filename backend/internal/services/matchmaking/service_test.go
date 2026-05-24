package matchmaking

import (
	"context"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestMatchmakingService_Integration(t *testing.T) {
	// Attempt to connect to local Redis container
	rdb := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})
	
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	
	err := rdb.Ping(ctx).Err()
	if err != nil {
		t.Skip("Local Redis is not running. Skipping matchmaking integration test.")
		return
	}
	defer rdb.Close()

	logger := zap.NewNop()
	svc := NewMatchmakingService(rdb, logger)
	gameType := "test_ludo"
	queueKey := "queue:" + gameType

	// Clean up from prior runs
	rdb.Del(ctx, queueKey)
	defer rdb.Del(ctx, queueKey)

	// 1. Join queue
	err = svc.JoinQueue(ctx, gameType, "user_A", 1200)
	assert.NoError(t, err)

	err = svc.JoinQueue(ctx, gameType, "user_B", 1210) // Small ELO gap (10 points)
	assert.NoError(t, err)

	// Attempt match immediately - should succeed because gap (10) < baseRange (50)
	matches, err := svc.AttemptMatch(ctx, gameType)
	assert.NoError(t, err)
	assert.Len(t, matches, 2)
	assert.Contains(t, matches, "user_A")
	assert.Contains(t, matches, "user_B")

	// 2. Test ELO band expansion
	// Clean up
	rdb.Del(ctx, queueKey)

	err = svc.JoinQueue(ctx, gameType, "user_C", 1000)
	assert.NoError(t, err)

	err = svc.JoinQueue(ctx, gameType, "user_D", 1100) // Large ELO gap (100 points)
	assert.NoError(t, err)

	// Attempt match immediately - should FAIL because gap (100) > baseRange (50)
	_, err = svc.AttemptMatch(ctx, gameType)
	assert.ErrorIs(t, err, ErrNoMatch)

	// 3. Verify RemovePlayerFromQueue
	err = svc.RemovePlayerFromQueue(ctx, gameType, "user_C")
	assert.NoError(t, err)

	members, err := rdb.ZRange(ctx, queueKey, 0, -1).Result()
	assert.NoError(t, err)
	assert.Len(t, members, 1) // only user_D remains
}
