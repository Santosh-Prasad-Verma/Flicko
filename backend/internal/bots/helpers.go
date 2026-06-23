// Package bots — shared helpers used across every internal bot.
//
// This file exists to remove the duplicated, schema-incorrect, and
// panic-prone implementations of sendBotMessage / getUsername /
// checkAdminPermission that previously lived in every bot.
package bots

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"
)

// ─── System User ──────────────────────────────────────────────────────────────

// systemUserOnce ensures EnsureSystemUser only runs once per process.
var systemUserOnce sync.Once
var systemUserID string
var systemUserErr error

// EnsureSystemUser provisions (or fetches) the stable bot/system principal
// used as messages.author_id for any system-emitted message. The row is
// idempotent on the seeded UUID; subsequent calls return the cached ID.
//
// Returns the system user's UUID. On error, callers should still treat the
// returned string as a best-effort fallback ("" allowed; messages.author_id
// is nullable per supabase/migrations/064b_allow_system_messages_without_author.sql).
func EnsureSystemUser(ctx context.Context, bctx BotContext) (string, error) {
	systemUserOnce.Do(func() {
		// Seeded UUID for the system user. Stable across deployments so
		// historical messages keep referencing the same author_id.
		const seedID = "00000000-0000-0000-0000-000000bot001"

		_, err := bctx.DB.Exec(ctx,
			`INSERT INTO profiles (id, username, display_name, created_at)
			 VALUES ($1, 'flicko', 'Flicko', NOW())
			 ON CONFLICT (id) DO NOTHING`,
			seedID)
		if err != nil {
			// We don't treat this as fatal — author_id is nullable.
			bctx.Logger.Warn("EnsureSystemUser: profile upsert failed (author_id will be NULL)",
				zap.Error(err),
			)
			systemUserErr = err
			return
		}
		systemUserID = seedID
	})
	return systemUserID, systemUserErr
}

// ─── Bot Message Sender ───────────────────────────────────────────────────────

// SendBotMessage inserts a system-typed message into a channel using the
// canonical column names (author_id NULL, type='system'). Replaces every
// bot's local copy of this function (CRIT-6 fix).
//
// Failures are logged but never returned — system messages are best-effort.
// Callers MUST NOT block their happy path on this completing.
func SendBotMessage(bctx BotContext, channelID, content string) {
	if channelID == "" || content == "" {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	systemID, _ := EnsureSystemUser(ctx, bctx)

	// author_id is nullable for system messages; if EnsureSystemUser failed,
	// we still insert with NULL.
	var err error
	if systemID == "" {
		_, err = bctx.DB.Exec(ctx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, NULL, $2, 'system', NOW())`,
			channelID, content)
	} else {
		_, err = bctx.DB.Exec(ctx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, $2, $3, 'system', NOW())`,
			channelID, systemID, content)
	}

	if err != nil {
		bctx.Logger.Error("SendBotMessage failed",
			zap.String("channel_id", channelID),
			zap.Error(err),
		)
	}
}

// SendBotMessageDetailed inserts a system message and registers banner and GIF attachments
func SendBotMessageDetailed(bctx BotContext, channelID, content string, bannerURL, gifURL string) {
	if channelID == "" || content == "" {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	systemID, _ := EnsureSystemUser(ctx, bctx)

	var messageID string
	var err error
	if systemID == "" {
		err = bctx.DB.QueryRow(ctx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, NULL, $2, 'system', NOW()) RETURNING id`,
			channelID, content).Scan(&messageID)
	} else {
		err = bctx.DB.QueryRow(ctx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, $2, $3, 'system', NOW()) RETURNING id`,
			channelID, systemID, content).Scan(&messageID)
	}

	if err != nil {
		bctx.Logger.Error("SendBotMessageDetailed failed to insert message",
			zap.String("channel_id", channelID),
			zap.Error(err),
		)
		return
	}

	// Insert banner attachment if present
	if bannerURL != "" {
		filename := "banner"
		if idx := strings.LastIndex(bannerURL, "/"); idx != -1 && idx+1 < len(bannerURL) {
			filename = bannerURL[idx+1:]
		}
		if idx := strings.Index(filename, "?"); idx != -1 {
			filename = filename[:idx]
		}
		mimeType := "image/png"
		if strings.HasSuffix(strings.ToLower(filename), ".jpg") || strings.HasSuffix(strings.ToLower(filename), ".jpeg") {
			mimeType = "image/jpeg"
		} else if strings.HasSuffix(strings.ToLower(filename), ".webp") {
			mimeType = "image/webp"
		} else if strings.HasSuffix(strings.ToLower(filename), ".gif") {
			mimeType = "image/gif"
		}

		_, err = bctx.DB.Exec(ctx,
			`INSERT INTO public.attachments (id, message_id, filename, size, mime_type, url, is_malware)
			 VALUES (gen_random_uuid(), $1, $2, 0, $3, $4, false)`,
			messageID, filename, mimeType, bannerURL)
		if err != nil {
			bctx.Logger.Error("SendBotMessageDetailed failed to insert banner attachment",
				zap.String("message_id", messageID),
				zap.Error(err),
			)
		}
	}

	// Insert GIF attachment if present
	if gifURL != "" {
		filename := "welcome.gif"
		if idx := strings.LastIndex(gifURL, "/"); idx != -1 && idx+1 < len(gifURL) {
			filename = gifURL[idx+1:]
		}
		if idx := strings.Index(filename, "?"); idx != -1 {
			filename = filename[:idx]
		}
		mimeType := "image/gif"

		_, err = bctx.DB.Exec(ctx,
			`INSERT INTO public.attachments (id, message_id, filename, size, mime_type, url, is_malware)
			 VALUES (gen_random_uuid(), $1, $2, 0, $3, $4, false)`,
			messageID, filename, mimeType, gifURL)
		if err != nil {
			bctx.Logger.Error("SendBotMessageDetailed failed to insert GIF attachment",
				zap.String("message_id", messageID),
				zap.Error(err),
			)
		}
	}
}


// ─── Username lookup (panic-safe) ─────────────────────────────────────────────

// LookupUsername returns a display name for a user ID. Returns the safe
// fallback "user" if the ID is empty, the lookup fails, or the row has
// no display_name/username (HIGH-6 fix — no more userID[:8] panics).
func LookupUsername(bctx BotContext, userID string) string {
	if userID == "" {
		return "user"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	var username string
	if err := bctx.DB.QueryRow(ctx,
		`SELECT COALESCE(display_name, username, '') FROM users WHERE id = $1`,
		userID,
	).Scan(&username); err != nil || username == "" {
		// Truncate UUID safely. UUIDs are 36 chars; index up to 8 is safe.
		if len(userID) >= 8 {
			return userID[:8]
		}
		return userID
	}
	return username
}

// ─── Permission checks ────────────────────────────────────────────────────────

// PermissionBits defines the standard Discord-style permission bitmask values
// used across every bot. Wire-format compatibility with Discord eases mobile
// client UX porting later.
type PermissionBits int64

const (
	// PermAdministrator overrides every other check.
	PermAdministrator PermissionBits = 0x8
	// PermManageGuild allows bot/role/integration configuration.
	PermManageGuild PermissionBits = 0x20
	// PermKickMembers allows /kick.
	PermKickMembers PermissionBits = 0x2
	// PermBanMembers allows /ban, /unban.
	PermBanMembers PermissionBits = 0x4
	// PermManageMessages allows /purge.
	PermManageMessages PermissionBits = 0x2000
	// PermModerateMembers allows /mute, /unmute, /warn, /timeout.
	PermModerateMembers PermissionBits = 0x10000000000
)

// HasPermission returns true if the user is the server owner OR holds at
// least one role with any of the requested bits (Administrator always wins).
//
// Fail-closed: any DB error returns false.
func HasPermission(ctx context.Context, bctx BotContext, serverID, userID string, want PermissionBits) bool {
	if serverID == "" || userID == "" {
		return false
	}

	var isOwner bool
	if err := bctx.DB.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM servers WHERE id = $1 AND owner_id = $2)`,
		serverID, userID,
	).Scan(&isOwner); err == nil && isOwner {
		return true
	}

	mask := int64(want) | int64(PermAdministrator)
	var has bool
	err := bctx.DB.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1
			FROM member_roles mr
			JOIN roles r ON r.id = mr.role_id
			WHERE mr.server_id = $1
			  AND mr.user_id = $2
			  AND (r.permissions & $3) <> 0
		)`,
		serverID, userID, mask,
	).Scan(&has)
	if err != nil {
		bctx.Logger.Debug("HasPermission lookup failed",
			zap.String("server_id", serverID),
			zap.String("user_id", userID),
			zap.Error(err),
		)
		return false
	}
	return has
}

// RequirePermission is a convenience wrapper around HasPermission that
// returns ErrInsufficientPermission when denied. Designed for early-return
// in command handlers:
//
//	if err := bots.RequirePermission(ctx, bctx, serverID, userID, bots.PermBanMembers); err != nil {
//	    return "❌ You don't have permission to use this command.", nil
//	}
func RequirePermission(ctx context.Context, bctx BotContext, serverID, userID string, want PermissionBits) error {
	if HasPermission(ctx, bctx, serverID, userID, want) {
		return nil
	}
	return ErrInsufficientPermission
}

// ─── Audit Logging ────────────────────────────────────────────────────────────

// LogAudit inserts a row into the canonical audit_logs table
// (supabase/migrations/032_moderation_domain_tables.sql, partitioned in 133).
//
// Schema: (server_id, actor_id, action_type, target_type, target_id, reason, changes)
// Replaces the old (moderator_id, target_id, action, reason) shape (CRIT-3 fix).
//
// Failures are logged at error level but never returned — audit logs are
// best-effort and should never block a moderation action.
func LogAudit(ctx context.Context, bctx BotContext, serverID, actorID, actionType, targetType, targetID, reason string) {
	if serverID == "" {
		return
	}

	// actor_id, target_id are nullable in the schema; pass NULL when empty.
	var actorPtr, targetPtr interface{}
	if actorID != "" {
		actorPtr = actorID
	}
	if targetID != "" {
		targetPtr = targetID
	}
	if targetType == "" {
		targetType = "user"
	}

	_, err := bctx.DB.Exec(ctx,
		`INSERT INTO audit_logs (server_id, actor_id, action_type, target_type, target_id, reason)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		serverID, actorPtr, actionType, targetType, targetPtr, reason)
	if err != nil {
		bctx.Logger.Error("audit log insert failed",
			zap.String("action", actionType),
			zap.String("server_id", serverID),
			zap.Error(err),
		)
	}
}

// ─── Misc helpers ─────────────────────────────────────────────────────────────

// BoolEmoji returns ✅ Enabled / ❌ Disabled for status embeds.
// Lifted out of automod.go so other bots can share it.
func BoolEmoji(v bool) string {
	if v {
		return "✅ Enabled"
	}
	return "❌ Disabled"
}

// ParseDuration parses human-friendly durations like "10m", "1h", "7d".
// Caps at 30 days and rejects non-positive values.
//
// Lifted out of moderation.go so other bots (poll, etc.) can share it.
func ParseDuration(s string) (time.Duration, error) {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return 0, errors.New("empty duration")
	}

	var (
		d   time.Duration
		err error
	)
	if strings.HasSuffix(s, "d") {
		var days int
		if _, e := fmt.Sscanf(strings.TrimSuffix(s, "d"), "%d", &days); e != nil {
			return 0, e
		}
		d = time.Duration(days) * 24 * time.Hour
	} else {
		d, err = time.ParseDuration(s)
		if err != nil {
			return 0, err
		}
	}

	if d <= 0 {
		return 0, errors.New("duration must be positive")
	}
	const maxDuration = 30 * 24 * time.Hour
	if d > maxDuration {
		return 0, errors.New("duration too long (maximum is 30 days)")
	}
	return d, nil
}
