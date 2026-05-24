package services_test

import (
	"context"
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

type fakeRedisClient struct {
	redis.Cmdable
	queue [][]byte
	mu    sync.Mutex
}

func (f *fakeRedisClient) LPush(ctx context.Context, key string, values ...any) *redis.IntCmd {
	f.mu.Lock()
	defer f.mu.Unlock()

	cmd := redis.NewIntCmd(ctx, values...)
	for _, val := range values {
		switch v := val.(type) {
		case []byte:
			f.queue = append([][]byte{v}, f.queue...)
		case string:
			f.queue = append([][]byte{[]byte(v)}, f.queue...)
		}
	}
	cmd.SetVal(int64(len(values)))
	return cmd
}

func (f *fakeRedisClient) RPop(ctx context.Context, key string) *redis.StringCmd {
	f.mu.Lock()
	defer f.mu.Unlock()

	cmd := redis.NewStringCmd(ctx)
	if len(f.queue) == 0 {
		cmd.SetErr(redis.Nil)
		return cmd
	}

	val := f.queue[len(f.queue)-1]
	f.queue = f.queue[:len(f.queue)-1]
	cmd.SetVal(string(val))
	return cmd
}

type fakeCache struct {
	cache.CacheLayer
	client *fakeRedisClient
}

func (c *fakeCache) GetRedisClient() redis.Cmdable {
	return c.client
}

type fakeDBClient struct {
	database.DatabaseClient
	queries []string
	args    [][]any
	mu      sync.Mutex
}

func (f *fakeDBClient) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.queries = append(f.queries, sql)
	f.args = append(f.args, args)
	return pgconn.CommandTag{}, nil
}

func TestAuditLogService_CreateLog(t *testing.T) {
	db := new(fakeDBClient)
	redisClient := &fakeRedisClient{queue: make([][]byte, 0)}
	fc := &fakeCache{client: redisClient}
	perms := new(MockPermissionService)

	svc := services.NewAuditLogService(db, fc, perms)

	ctx := context.Background()
	serverID := uuid.New().String()
	actorID := uuid.New().String()
	targetID := uuid.New().String()
	reason := "Spamming links"
	changes := map[string]interface{}{"warnings": 1}

	err := svc.CreateLog(ctx, serverID, &actorID, models.ActionMemberKick, "user", &targetID, &reason, changes)
	assert.NoError(t, err)

	redisClient.mu.Lock()
	assert.Len(t, redisClient.queue, 1)
	payload := redisClient.queue[0]
	redisClient.mu.Unlock()

	var log models.AuditLog
	err = json.Unmarshal(payload, &log)
	assert.NoError(t, err)

	assert.Equal(t, serverID, log.ServerID)
	assert.Equal(t, &actorID, log.ActorID)
	assert.Equal(t, models.ActionMemberKick, log.ActionType)
	assert.Equal(t, "user", log.TargetType)
	assert.Equal(t, &targetID, log.TargetID)
	assert.Equal(t, &reason, log.Reason)
	assert.NotEmpty(t, log.ID)
}

func TestAuditWorker_BatchProcessing(t *testing.T) {
	db := &fakeDBClient{queries: make([]string, 0), args: make([][]any, 0)}
	redisClient := &fakeRedisClient{queue: make([][]byte, 0)}
	fc := &fakeCache{client: redisClient}
	logger := zap.NewNop()

	// Push 3 mock log payloads onto Redis
	for i := 0; i < 3; i++ {
		log := &models.AuditLog{
			ID:         uuid.New().String(),
			ServerID:   uuid.New().String(),
			ActionType: models.ActionChannelCreate,
			TargetType: "channel",
			CreatedAt:  time.Now().UTC(),
		}
		b, _ := json.Marshal(log)
		redisClient.LPush(context.Background(), "flicko:audit:queue", b)
	}

	worker := services.NewAuditWorker(db, fc, logger)
	worker.Start(context.Background())
	time.Sleep(150 * time.Millisecond)
	worker.Stop() // triggers remaining queue flush synchronously

	db.mu.Lock()
	assert.NotEmpty(t, db.queries)
	assert.Contains(t, db.queries[0], "INSERT INTO public.audit_logs")
	assert.Len(t, db.args[0], 27) // 3 logs * 9 fields = 27 arguments
	db.mu.Unlock()

	redisClient.mu.Lock()
	assert.Empty(t, redisClient.queue)
	redisClient.mu.Unlock()
}
