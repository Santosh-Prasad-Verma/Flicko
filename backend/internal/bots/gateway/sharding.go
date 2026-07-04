package gateway

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

type GatewayBotResponse struct {
	URL               string            `json:"url"`
	Shards            int               `json:"shards"`
	SessionStartLimit SessionStartLimit `json:"session_start_limit"`
}

type SessionStartLimit struct {
	Total          int   `json:"total"`
	Remaining      int   `json:"remaining"`
	ResetAfter     int64 `json:"reset_after"`
	MaxConcurrency int   `json:"max_concurrency"`
}

type ShardCoordinator struct {
	db     *pgxpool.Pool
	rdb    redis.Cmdable
	logger *zap.Logger
}

func NewShardCoordinator(db *pgxpool.Pool, rdb redis.Cmdable, logger *zap.Logger) *ShardCoordinator {
	return &ShardCoordinator{
		db:     db,
		rdb:    rdb,
		logger: logger.Named("shard_coordinator"),
	}
}

func (sc *ShardCoordinator) HandleGatewayBot(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var totalServers int = 1
	if sc.db != nil {
		_ = sc.db.QueryRow(ctx, "SELECT COUNT(*) FROM public.servers").Scan(&totalServers)
	}

	// Standard Discord formula: 1 shard per 1000 guilds (minimum 1)
	recommendedShards := totalServers / 1000
	if recommendedShards < 1 {
		recommendedShards = 1
	}

	remainingStarts := 999
	if sc.rdb != nil {
		key := fmt.Sprintf("gateway_starts:%s", time.Now().Format("2006-01-02"))
		count, err := sc.rdb.Incr(ctx, key).Result()
		if err == nil {
			sc.rdb.Expire(ctx, key, 24*time.Hour)
			remainingStarts = 1000 - int(count)
			if remainingStarts < 0 {
				remainingStarts = 0
			}
		}
	}

	scheme := "ws"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "wss"
	}
	host := r.Host

	resp := GatewayBotResponse{
		URL:    fmt.Sprintf("%s://%s/api/v1/gateway", scheme, host),
		Shards: recommendedShards,
		SessionStartLimit: SessionStartLimit{
			Total:          1000,
			Remaining:      remainingStarts,
			ResetAfter:     86400000,
			MaxConcurrency: 1,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(resp)
}

func (sc *ShardCoordinator) BroadcastShardEvent(ctx context.Context, shardID int, eventType string, eventData json.RawMessage) error {
	if sc.rdb == nil {
		return nil
	}

	channelKey := fmt.Sprintf("shard:%d", shardID)
	payload := map[string]interface{}{
		"t": eventType,
		"d": eventData,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal shard payload: %w", err)
	}

	return sc.rdb.Publish(ctx, channelKey, string(payloadBytes)).Err()
}
