package redis

import (
	"context"
	"fmt"
	"strconv"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// TTLs from Production-Architecture.md §4.2.
const (
	PresenceTTL = 60 * time.Second // Re-set by heartbeat every 20s.
	TypingTTL   = 8 * time.Second  // Client re-sends every 5s while typing.
)

// Presence represents a user's online status stored in Redis.
type Presence struct {
	Status    string `json:"status"`     // online, idle, dnd, offline
	LastSeen  int64  `json:"last_seen"`  // Unix ms timestamp
	GatewayID string `json:"gateway_id"` // Which gateway instance owns this
}

// PresenceManager handles user presence, typing indicators, and
// guild online member tracking via Redis.
type PresenceManager struct {
	rdb *goredis.Client
	log *zap.Logger
}

// NewPresenceManager creates a PresenceManager.
func NewPresenceManager(rdb *goredis.Client, log *zap.Logger) *PresenceManager {
	return &PresenceManager{rdb: rdb, log: log.Named("presence")}
}

// ---------- User Presence ----------

// SetPresence stores a user's presence in Redis as a hash with TTL.
// Key: flicko:presence:{userID}
// Fields: status, last_seen, gateway_id
func (p *PresenceManager) SetPresence(ctx context.Context, userID, status, gatewayID string) error {
	key := "flicko:presence:" + userID
	nowMS := strconv.FormatInt(time.Now().UnixMilli(), 10)

	pipe := p.rdb.Pipeline()
	pipe.HSet(ctx, key, map[string]interface{}{
		"status":     status,
		"last_seen":  nowMS,
		"gateway_id": gatewayID,
	})
	pipe.Expire(ctx, key, PresenceTTL)

	_, err := pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("presence: set %s: %w", userID, err)
	}
	return nil
}

// GetPresence retrieves a user's presence from Redis.
// Returns nil, nil if the key does not exist (user is offline).
func (p *PresenceManager) GetPresence(ctx context.Context, userID string) (*Presence, error) {
	key := "flicko:presence:" + userID

	result, err := p.rdb.HGetAll(ctx, key).Result()
	if err != nil {
		return nil, fmt.Errorf("presence: get %s: %w", userID, err)
	}
	if len(result) == 0 {
		return nil, nil // not found → offline
	}

	lastSeen, _ := strconv.ParseInt(result["last_seen"], 10, 64)
	return &Presence{
		Status:    result["status"],
		LastSeen:  lastSeen,
		GatewayID: result["gateway_id"],
	}, nil
}

// RefreshPresence extends the TTL of a user's presence key without
// overwriting fields. This is called by the gateway heartbeat loop
// every ~20 s to keep the presence alive while the WS is connected.
func (p *PresenceManager) RefreshPresence(ctx context.Context, userID, gatewayID string) error {
	key := "flicko:presence:" + userID
	nowMS := strconv.FormatInt(time.Now().UnixMilli(), 10)

	pipe := p.rdb.Pipeline()
	pipe.HSet(ctx, key, "last_seen", nowMS, "gateway_id", gatewayID)
	pipe.Expire(ctx, key, PresenceTTL)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("presence: refresh %s: %w", userID, err)
	}
	return nil
}

// RemovePresence deletes a user's presence (e.g. on disconnect).
func (p *PresenceManager) RemovePresence(ctx context.Context, userID string) error {
	return p.rdb.Del(ctx, "flicko:presence:"+userID).Err()
}

// ---------- Typing Indicators ----------

// SetTyping marks a user as typing in a channel.
// Key: flicko:typing:{channelID}:{userID} with 8s TTL.
func (p *PresenceManager) SetTyping(ctx context.Context, channelID, userID string) error {
	key := fmt.Sprintf("flicko:typing:%s:%s", channelID, userID)
	return p.rdb.Set(ctx, key, "1", TypingTTL).Err()
}

// GetTyping returns the list of user IDs currently typing in a channel.
// It scans for keys matching flicko:typing:{channelID}:*.
func (p *PresenceManager) GetTyping(ctx context.Context, channelID string) ([]string, error) {
	pattern := fmt.Sprintf("flicko:typing:%s:*", channelID)
	prefix := fmt.Sprintf("flicko:typing:%s:", channelID)

	var userIDs []string
	iter := p.rdb.Scan(ctx, 0, pattern, 100).Iterator()
	for iter.Next(ctx) {
		key := iter.Val()
		if len(key) > len(prefix) {
			userIDs = append(userIDs, key[len(prefix):])
		}
	}
	if err := iter.Err(); err != nil {
		return nil, fmt.Errorf("presence: get typing %s: %w", channelID, err)
	}
	return userIDs, nil
}

// ClearTyping removes a user's typing indicator (e.g. after sending a message).
func (p *PresenceManager) ClearTyping(ctx context.Context, channelID, userID string) error {
	key := fmt.Sprintf("flicko:typing:%s:%s", channelID, userID)
	return p.rdb.Del(ctx, key).Err()
}

// ---------- Guild Online Members ----------

// UpdateGuildOnline adds/refreshes a user in the guild's online sorted set.
// Key: flicko:guild:online:{guildID}
// Score: current Unix ms timestamp (for ZREMRANGEBYSCORE cleanup).
func (p *PresenceManager) UpdateGuildOnline(ctx context.Context, guildID, userID string) error {
	key := "flicko:guild:online:" + guildID
	score := float64(time.Now().UnixMilli())
	return p.rdb.ZAdd(ctx, key, goredis.Z{
		Score:  score,
		Member: userID,
	}).Err()
}

// GetGuildOnline returns the most recently active user IDs in a guild.
// Limited to `limit` results, ordered by most-recently-active first.
func (p *PresenceManager) GetGuildOnline(ctx context.Context, guildID string, limit int) ([]string, error) {
	key := "flicko:guild:online:" + guildID

	// First remove stale entries (older than PresenceTTL).
	cutoff := float64(time.Now().Add(-PresenceTTL).UnixMilli())
	p.rdb.ZRemRangeByScore(ctx, key, "-inf", strconv.FormatFloat(cutoff, 'f', 0, 64))

	// Fetch most recent members.
	if limit <= 0 {
		limit = 100
	}
	return p.rdb.ZRevRange(ctx, key, 0, int64(limit-1)).Result()
}

// RemoveGuildOnline removes a user from the guild's online set.
func (p *PresenceManager) RemoveGuildOnline(ctx context.Context, guildID, userID string) error {
	key := "flicko:guild:online:" + guildID
	return p.rdb.ZRem(ctx, key, userID).Err()
}
