package abuse

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Redis key helpers
// ─────────────────────────────────────────────────────────────────────────────

const (
	// mutedKeyPrefix stores the muted state for a user.
	// Key: flicko:muted:{user_id} — TTL = mute duration.
	mutedKeyPrefix = "flicko:muted:"

)

// ─────────────────────────────────────────────────────────────────────────────
// AbuseLog entry (published to Redis + stored externally)
// ─────────────────────────────────────────────────────────────────────────────

// LogEntry represents a single abuse event persisted for admin review.
type LogEntry struct {
	UserID    string    `json:"user_id"`
	Reason    Reason    `json:"reason"`
	Action    string    `json:"action"`
	Details   string    `json:"details"`
	Timestamp time.Time `json:"timestamp"`
}

// ─────────────────────────────────────────────────────────────────────────────
// AbuseLogger interface (for testability)
// ─────────────────────────────────────────────────────────────────────────────

// AbuseLogger persists abuse events for admin review (e.g. database, stdout).
type AbuseLogger interface {
	LogAbuse(ctx context.Context, entry LogEntry) error
}

// ─────────────────────────────────────────────────────────────────────────────
// Enforcer — executes actions determined by the Detector
// ─────────────────────────────────────────────────────────────────────────────

// Enforcer applies mutes, bans, and other enforcement actions via Redis.
type Enforcer struct {
	rdb         redis.Cmdable
	abuseLogger AbuseLogger
	log         *zap.Logger
}

// NewEnforcer creates an Enforcer.
// abuseLogger may be nil — in that case abuse events are only logged via zap.
func NewEnforcer(rdb redis.Cmdable, abuseLogger AbuseLogger, log *zap.Logger) *Enforcer {
	return &Enforcer{
		rdb:         rdb,
		abuseLogger: abuseLogger,
		log:         log.Named("abuse.enforcer"),
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// AutoMute
// ─────────────────────────────────────────────────────────────────────────────

// AutoMute mutes a user for the given duration.
// While muted, messages from this user are silently dropped (not delivered
// via Pub/Sub, not stored in PostgreSQL).
//
// For a shadow-mute, the caller stores the message but skips publishing —
// the user sees their own message, but other clients never receive it.
func (e *Enforcer) AutoMute(ctx context.Context, userID string, duration time.Duration, reason Reason, details string) error {
	key := mutedKeyPrefix + userID
	if err := e.rdb.Set(ctx, key, string(reason), duration).Err(); err != nil {
		e.log.Error("failed to set mute key",
			zap.String("user_id", userID),
			zap.Error(err),
		)
		return fmt.Errorf("abuse: auto-mute SET: %w", err)
	}

	e.log.Warn("user auto-muted",
		zap.String("user_id", userID),
		zap.Duration("duration", duration),
		zap.String("reason", string(reason)),
		zap.String("details", details),
	)

	// Persist for admin review.
	entry := LogEntry{
		UserID:    userID,
		Reason:    reason,
		Action:    ActionMute.String(),
		Details:   details,
		Timestamp: time.Now().UTC(),
	}
	e.logEntry(ctx, entry)

	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// IsUserMuted
// ─────────────────────────────────────────────────────────────────────────────

// IsUserMuted checks whether userID is currently muted.
// Returns (true, nil) if muted, (false, nil) if not muted.
// On Redis error, returns (false, err) — callers should allow the message
// through (availability > enforcement).
func (e *Enforcer) IsUserMuted(ctx context.Context, userID string) (bool, error) {
	key := mutedKeyPrefix + userID
	n, err := e.rdb.Exists(ctx, key).Result()
	if err != nil {
		return false, fmt.Errorf("abuse: mute check: %w", err)
	}
	return n > 0, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// UnmuteUser (manual admin action)
// ─────────────────────────────────────────────────────────────────────────────

// UnmuteUser removes a mute (manual admin override).
func (e *Enforcer) UnmuteUser(ctx context.Context, userID string) error {
	key := mutedKeyPrefix + userID
	if err := e.rdb.Del(ctx, key).Err(); err != nil {
		return fmt.Errorf("abuse: unmute DEL: %w", err)
	}
	e.log.Info("user unmuted", zap.String("user_id", userID))
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Execute — dispatch the action from a CheckResult
// ─────────────────────────────────────────────────────────────────────────────

// Execute applies the enforcement action from a CheckResult.
// Returns nil if no enforcement was needed (ActionNone or ActionWarn).
func (e *Enforcer) Execute(ctx context.Context, result CheckResult, userID string) error {
	switch result.Action {
	case ActionNone:
		return nil

	case ActionWarn:
		e.log.Warn("abuse warning issued",
			zap.String("user_id", userID),
			zap.String("reason", string(result.Reason)),
			zap.String("details", result.Details),
		)
		entry := LogEntry{
			UserID:    userID,
			Reason:    result.Reason,
			Action:    ActionWarn.String(),
			Details:   result.Details,
			Timestamp: time.Now().UTC(),
		}
		e.logEntry(ctx, entry)
		return nil

	case ActionMute, ActionShadowMute:
		return e.AutoMute(ctx, userID, result.MuteDuration, result.Reason, result.Details)

	case ActionKick, ActionBan:
		// Kick/Ban require guild context — for now, escalate to mute + log.
		// Full kick/ban implementation will integrate with the guild service.
		e.log.Error("escalated action not yet implemented, applying mute",
			zap.String("user_id", userID),
			zap.String("action", result.Action.String()),
			zap.String("reason", string(result.Reason)),
		)
		return e.AutoMute(ctx, userID, 30*time.Minute, result.Reason, result.Details)

	default:
		return fmt.Errorf("abuse: unknown action %d", result.Action)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal logging
// ─────────────────────────────────────────────────────────────────────────────

// logEntry persists an abuse event via the AbuseLogger (if set) and logs it.
func (e *Enforcer) logEntry(ctx context.Context, entry LogEntry) {
	if e.abuseLogger != nil {
		if err := e.abuseLogger.LogAbuse(ctx, entry); err != nil {
			e.log.Error("failed to persist abuse log",
				zap.String("user_id", entry.UserID),
				zap.Error(err),
			)
		}
	}
}
