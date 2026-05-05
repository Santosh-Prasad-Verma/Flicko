package cache

import "fmt"

// Redis Key schemas for the Gaming Hub
const (
	// Prefix formatters
	QueuePrefix       = "queue:%s"
	GameStatePrefix   = "game:%s:state"
	GameMoveNumPrefix = "game:%s:move_num"
	GameLockPrefix    = "game:%s:lock"
	GameTurnPrefix    = "game:%s:turn"
	AbandonmentPrefix = "abandonment:%s:%s" // gameId, userId
	SessionPrefix     = "session:%s"        // userId

	// Static keys
	MatchmakingLeaderLock = "matchmaking:leader"
)

// GenerateQueueKey returns the key for the matchmaking sorted set queue for a specific game type.
// Example: queue:chess
func GenerateQueueKey(gameType string) string {
	return fmt.Sprintf(QueuePrefix, gameType)
}

// GenerateGameStateKey returns the key for caching the serialized JSON state of a game.
func GenerateGameStateKey(gameId string) string {
	return fmt.Sprintf(GameStatePrefix, gameId)
}

// GenerateGameMoveNumKey returns the key for the atomic move sequence counter.
func GenerateGameMoveNumKey(gameId string) string {
	return fmt.Sprintf(GameMoveNumPrefix, gameId)
}

// GenerateGameLockKey returns the key used for the UUID-based distributed lock.
func GenerateGameLockKey(gameId string) string {
	return fmt.Sprintf(GameLockPrefix, gameId)
}

// GenerateGameTurnKey returns the key for the specific turn state (e.g. Ludo dice rolls, turn timeouts).
func GenerateGameTurnKey(gameId string) string {
	return fmt.Sprintf(GameTurnPrefix, gameId)
}

// GenerateAbandonmentKey returns the key created when Centrifugo detects a disconnect.
func GenerateAbandonmentKey(gameId, userId string) string {
	return fmt.Sprintf(AbandonmentPrefix, gameId, userId)
}

// GenerateSessionKey returns the key that maps a user ID to their active game session.
func GenerateSessionKey(userId string) string {
	return fmt.Sprintf(SessionPrefix, userId)
}
