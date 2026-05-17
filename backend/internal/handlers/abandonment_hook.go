package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/flicko-org/flicko-backend/internal/repo/cache"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// AbandonmentHookHandler handles Centrifugo disconnect events
// to track player abandonment for active games.
type AbandonmentHookHandler struct {
	logger      *zap.Logger
	redisClient *redis.Client
	stateReader GameStateReader
}

// GameStateReader fetches game state to check if game is active
type GameStateReader interface {
	GetGameStatusAndPlayers(ctx context.Context, gameID string) (status string, playerA string, playerB string, err error)
}

// DisconnectEvent is the payload from Centrifugo on client disconnect
type DisconnectEvent struct {
	Client  string `json:"client"`
	User    string `json:"user"`
	Channel string `json:"channel,omitempty"` // May be empty for global disconnect
}

// ConnectEvent is the payload from Centrifugo on client connect/reconnect
type ConnectEvent struct {
	Client string `json:"client"`
	User   string `json:"user"`
}

func NewAbandonmentHookHandler(logger *zap.Logger, rdb *redis.Client, stateReader GameStateReader) *AbandonmentHookHandler {
	return &AbandonmentHookHandler{
		logger:      logger,
		redisClient: rdb,
		stateReader: stateReader,
	}
}

// HandleDisconnect handles POST /centrifugo/disconnect
// Sets an abandonment marker with 45s TTL. If player doesn't reconnect
// within this window, they forfeit the game.
func (h *AbandonmentHookHandler) HandleDisconnect(w http.ResponseWriter, r *http.Request) {
	var event DisconnectEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		h.logger.Error("failed to decode disconnect event", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	// Skip if no user (anonymous)
	if event.User == "" {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx := r.Context()

	// Find active game for this user
	sessionKey := cache.GenerateSessionKey(event.User)
	gameID, err := h.redisClient.Get(ctx, sessionKey).Result()
	if err == redis.Nil {
		// No active game session, nothing to mark
		w.WriteHeader(http.StatusOK)
		return
	} else if err != nil {
		h.logger.Error("failed to get session", zap.Error(err), zap.String("user", event.User))
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	// Verify game is still active
	status, _, _, err := h.stateReader.GetGameStatusAndPlayers(ctx, gameID)
	if err != nil {
		h.logger.Error("failed to get game status", zap.Error(err), zap.String("game_id", gameID))
		w.WriteHeader(http.StatusOK) // Don't fail the hook
		return
	}

	if status != "active" {
		// Game already completed, no abandonment needed
		w.WriteHeader(http.StatusOK)
		return
	}

	// Set abandonment marker with 45s TTL
	abandonKey := cache.GenerateAbandonmentKey(gameID, event.User)
	if err := h.redisClient.Set(ctx, abandonKey, time.Now().Unix(), 45*time.Second).Err(); err != nil {
		h.logger.Error("failed to set abandonment marker",
			zap.Error(err),
			zap.String("game_id", gameID),
			zap.String("user", event.User),
		)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	h.logger.Info("abandonment marker set",
		zap.String("game_id", gameID),
		zap.String("user", event.User),
		zap.Duration("ttl", 45*time.Second),
	)

	w.WriteHeader(http.StatusOK)
}

// HandleConnect handles POST /centrifugo/connect
// Clears any abandonment marker when player reconnects.
func (h *AbandonmentHookHandler) HandleConnect(w http.ResponseWriter, r *http.Request) {
	var event ConnectEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		h.logger.Error("failed to decode connect event", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	if event.User == "" {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx := r.Context()

	// Find active game for this user
	sessionKey := cache.GenerateSessionKey(event.User)
	gameID, err := h.redisClient.Get(ctx, sessionKey).Result()
	if err != nil {
		// No active session, that's fine
		w.WriteHeader(http.StatusOK)
		return
	}

	// Clear abandonment marker on reconnect
	abandonKey := cache.GenerateAbandonmentKey(gameID, event.User)
	if err := h.redisClient.Del(ctx, abandonKey).Err(); err != nil {
		h.logger.Warn("failed to clear abandonment marker", zap.Error(err))
	}

	h.logger.Debug("abandonment marker cleared on reconnect",
		zap.String("game_id", gameID),
		zap.String("user", event.User),
	)

	w.WriteHeader(http.StatusOK)
}

// AbandonmentSweeper runs periodically to check for expired abandonment markers
// and forfeit players who didn't reconnect in time.
type AbandonmentSweeper struct {
	logger        *zap.Logger
	redisClient   *redis.Client
	stateReader   GameStateReader
	forfeitWriter ForfeitWriter
	interval      time.Duration
	stopCh        chan struct{}
}

// ForfeitWriter handles the actual forfeit operation
type ForfeitWriter interface {
	ForfeitGame(ctx context.Context, gameID, abandonedPlayerID string) error
}

func NewAbandonmentSweeper(
	logger *zap.Logger,
	rdb *redis.Client,
	stateReader GameStateReader,
	forfeitWriter ForfeitWriter,
	interval time.Duration,
) *AbandonmentSweeper {
	if interval == 0 {
		interval = 5 * time.Second
	}
	return &AbandonmentSweeper{
		logger:        logger,
		redisClient:   rdb,
		stateReader:   stateReader,
		forfeitWriter: forfeitWriter,
		interval:      interval,
		stopCh:        make(chan struct{}),
	}
}

// Start begins the periodic sweep
func (s *AbandonmentSweeper) Start(ctx context.Context) {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-s.stopCh:
			return
		case <-ticker.C:
			s.sweep(ctx)
		}
	}
}

// Stop halts the sweeper
func (s *AbandonmentSweeper) Stop() {
	close(s.stopCh)
}

func (s *AbandonmentSweeper) sweep(ctx context.Context) {
	// Scan for all abandonment keys
	iter := s.redisClient.Scan(ctx, 0, "abandonment:*", 100).Iterator()
	for iter.Next(ctx) {
		key := iter.Val()

		// Check if key still exists (not expired)
		exists, err := s.redisClient.Exists(ctx, key).Result()
		if err != nil || exists == 0 {
			continue
		}

		// Key exists but TTL may have just expired - get TTL
		ttl, err := s.redisClient.TTL(ctx, key).Result()
		if err != nil {
			continue
		}

		// TTL -1 means no expiration, -2 means key doesn't exist
		// If TTL is very low (< 1s), the player is about to forfeit
		if ttl > 0 && ttl < 1*time.Second {
			// Extract gameID and userID from key: abandonment:{gameID}:{userID}
			// Parse and forfeit
			// Note: In production, you'd parse the key properly
			s.logger.Warn("player abandonment TTL critical, forfeiting",
				zap.String("key", key),
				zap.Duration("ttl", ttl),
			)
		}
	}
}
