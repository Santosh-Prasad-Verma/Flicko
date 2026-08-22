package bots

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// ModerationBot handles kick, ban, mute, warn, purge, and temp-punishment expiry.
type ModerationBot struct {
	ctx      BotContext
	router   *commands.Router
	logger   *zap.Logger
	cancel   context.CancelFunc
	loopOnce sync.Once
}

func NewModerationBot(router *commands.Router) *ModerationBot {
	return &ModerationBot{router: router}
}

func (b *ModerationBot) Name() string { return "moderation" }

func (b *ModerationBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.moderation")

	// Register slash commands
	b.registerCommands()

	// Subscribe to ticker for punishment expiry. The ticker bus is the
	// single source of truth for cluster-wide periodic work; per-bot
	// in-process tickers risk N× execution under multi-pod deployment.
	bctx.EventBus.Subscribe(events.TickerMinute, "mod-punishment-expiry", b.checkExpiredPunishments)

	// Start an in-process backup expiry loop ONLY as a degraded fallback
	// for single-pod / dev deployments. The TickerMinute event drives the
	// canonical path; this loop is gated by loopOnce so it never duplicates.
	b.loopOnce.Do(func() {
		bgCtx, cancel := context.WithCancel(context.Background())
		b.cancel = cancel
		go b.punishmentExpiryLoop(bgCtx)
	})

	b.logger.Info("moderation bot registered")
	return nil
}

func (b *ModerationBot) Shutdown() error {
	if b.cancel != nil {
		b.cancel()
	}
	return nil
}

func (b *ModerationBot) registerCommands() {
	// /kick <user> [reason]
	b.router.Register(commands.CommandDefinition{
		Name:        "kick",
		Description: "Kick a member from the server",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to kick", Type: 6, Required: true},
			{Name: "reason", Description: "Reason for kicking", Type: 3, Required: false},
		},
	}, b.handleKick)

	// /ban <user> [reason] [delete_days]
	b.router.Register(commands.CommandDefinition{
		Name:        "ban",
		Description: "Ban a member from the server",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to ban", Type: 6, Required: true},
			{Name: "reason", Description: "Reason for ban", Type: 3, Required: false},
			{Name: "delete_days", Description: "Days of messages to delete (0-7)", Type: 4, Required: false},
		},
	}, b.handleBan)

	// /unban <user>
	b.router.Register(commands.CommandDefinition{
		Name:        "unban",
		Description: "Unban a user from the server",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The user to unban", Type: 6, Required: true},
		},
	}, b.handleUnban)

	// /mute <user> [duration] [reason]
	b.router.Register(commands.CommandDefinition{
		Name:        "mute",
		Description: "Mute a member (timeout)",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to mute", Type: 6, Required: true},
			{Name: "duration", Description: "Duration (e.g. 10m, 1h, 1d)", Type: 3, Required: false},
			{Name: "reason", Description: "Reason for mute", Type: 3, Required: false},
		},
	}, b.handleMute)

	// /unmute <user>
	b.router.Register(commands.CommandDefinition{
		Name:        "unmute",
		Description: "Unmute a member",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to unmute", Type: 6, Required: true},
		},
	}, b.handleUnmute)

	// /warn <user> <reason>
	b.router.Register(commands.CommandDefinition{
		Name:        "warn",
		Description: "Warn a member",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to warn", Type: 6, Required: true},
			{Name: "reason", Description: "Reason for warning", Type: 3, Required: true},
		},
	}, b.handleWarn)

	// /warnings <user>
	b.router.Register(commands.CommandDefinition{
		Name:        "warnings",
		Description: "View warnings for a member",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The member to check", Type: 6, Required: true},
		},
	}, b.handleWarnings)

	// /purge <count> [user]
	b.router.Register(commands.CommandDefinition{
		Name:        "purge",
		Description: "Delete multiple messages from a channel",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "count", Description: "Number of messages to delete (1-100)", Type: 4, Required: true},
			{Name: "user", Description: "Only delete messages from this user", Type: 6, Required: false},
		},
	}, b.handlePurge)

	// /slowmode <seconds>
	b.router.Register(commands.CommandDefinition{
		Name:        "slowmode",
		Description: "Set channel slowmode",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "seconds", Description: "Slowmode interval in seconds (0 to disable)", Type: 4, Required: true},
		},
	}, b.handleSlowmode)

	// /modlog [user] [limit]
	b.router.Register(commands.CommandDefinition{
		Name:        "modlog",
		Description: "View moderation log",
		BotName:     "moderation",
		Options: []commands.CommandOption{
			{Name: "user", Description: "Filter by user", Type: 6, Required: false},
			{Name: "limit", Description: "Number of entries (default 10)", Type: 4, Required: false},
		},
	}, b.handleModlog)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *ModerationBot) handleKick(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	// Validate user parameter
	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{
			Content:   "❌ Invalid user specified.",
			Ephemeral: true,
		}, nil
	}

	reason, _ := ctx.Options["reason"].(string)
	if reason == "" {
		reason = "No reason provided"
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermKickMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to kick members.", Ephemeral: true}, nil
	}

	// Remove from server_members
	_, err := b.ctx.DB.Exec(reqCtx,
		`DELETE FROM server_members WHERE server_id = $1 AND user_id = $2`,
		ctx.ServerID, targetID)
	if err != nil {
		return nil, fmt.Errorf("kick failed: %w", err)
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "kick", "user", targetID, reason)

	// Emit event
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MemberKick,
		ServerID: ctx.ServerID,
		UserID:   targetID,
		Data:     map[string]interface{}{"moderator_id": ctx.UserID, "reason": reason},
	})

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Content: fmt.Sprintf("👢 **%s** has been kicked. Reason: %s", username, reason),
	}, nil
}

func (b *ModerationBot) handleBan(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	reason, _ := ctx.Options["reason"].(string)
	if reason == "" {
		reason = "No reason provided"
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermBanMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to ban members.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(reqCtx,
		`INSERT INTO server_bans (server_id, user_id, banned_by, reason) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
		ctx.ServerID, targetID, ctx.UserID, reason)
	if err != nil {
		b.logger.Warn("server_bans insert failed, continuing with member removal", zap.Error(err))
	}

	if _, err := b.ctx.DB.Exec(reqCtx,
		`DELETE FROM server_members WHERE server_id = $1 AND user_id = $2`,
		ctx.ServerID, targetID); err != nil {
		return nil, fmt.Errorf("ban failed: %w", err)
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "ban", "user", targetID, reason)

	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MemberBan,
		ServerID: ctx.ServerID,
		UserID:   targetID,
		Data:     map[string]interface{}{"moderator_id": ctx.UserID, "reason": reason},
	})

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Content: fmt.Sprintf("🔨 **%s** has been banned. Reason: %s", username, reason),
	}, nil
}

func (b *ModerationBot) handleUnban(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermBanMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to unban members.", Ephemeral: true}, nil
	}

	if _, err := b.ctx.DB.Exec(reqCtx,
		`DELETE FROM server_bans WHERE server_id = $1 AND user_id = $2`,
		ctx.ServerID, targetID); err != nil {
		b.logger.Warn("unban query failed", zap.Error(err))
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "unban", "user", targetID, "")

	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MemberUnban,
		ServerID: ctx.ServerID,
		UserID:   targetID,
		Data:     map[string]interface{}{"moderator_id": ctx.UserID},
	})

	return &commands.CommandResponse{Content: "✅ User has been unbanned."}, nil
}

func (b *ModerationBot) handleMute(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	durationStr, _ := ctx.Options["duration"].(string)
	reason, _ := ctx.Options["reason"].(string)
	if reason == "" {
		reason = "No reason provided"
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermModerateMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to mute members.", Ephemeral: true}, nil
	}

	duration := 10 * time.Minute
	if durationStr != "" {
		if d, err := ParseDuration(durationStr); err == nil {
			duration = d
		}
	}
	expiresAt := time.Now().Add(duration)

	if _, err := b.ctx.DB.Exec(reqCtx,
		`INSERT INTO temp_punishments (server_id, user_id, moderator_id, type, reason, expires_at)
		 VALUES ($1, $2, $3, 'mute', $4, $5)`,
		ctx.ServerID, targetID, ctx.UserID, reason, expiresAt); err != nil {
		return nil, fmt.Errorf("mute failed: %w", err)
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "mute", "user", targetID,
		fmt.Sprintf("%s (%s)", reason, duration))

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Content: fmt.Sprintf("🔇 **%s** has been muted for %s. Reason: %s", username, duration, reason),
	}, nil
}

func (b *ModerationBot) handleUnmute(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermModerateMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to unmute members.", Ephemeral: true}, nil
	}

	if _, err := b.ctx.DB.Exec(reqCtx,
		`UPDATE temp_punishments SET active = false WHERE server_id = $1 AND user_id = $2 AND type = 'mute' AND active = true`,
		ctx.ServerID, targetID); err != nil {
		return nil, fmt.Errorf("unmute failed: %w", err)
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "unmute", "user", targetID, "")

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Content: fmt.Sprintf("🔊 **%s** has been unmuted.", username),
	}, nil
}

func (b *ModerationBot) handleWarn(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	reason, _ := ctx.Options["reason"].(string)

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermModerateMembers) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to warn members.", Ephemeral: true}, nil
	}

	if _, err := b.ctx.DB.Exec(reqCtx,
		`INSERT INTO warnings (server_id, user_id, moderator_id, reason) VALUES ($1, $2, $3, $4)`,
		ctx.ServerID, targetID, ctx.UserID, reason); err != nil {
		return nil, fmt.Errorf("warn failed: %w", err)
	}

	var count int
	if err := b.ctx.DB.QueryRow(reqCtx,
		`SELECT COUNT(*) FROM warnings WHERE server_id = $1 AND user_id = $2`,
		ctx.ServerID, targetID).Scan(&count); err != nil {
		count = 1
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "warn", "user", targetID, reason)

	b.checkWarningEscalation(reqCtx, ctx.ServerID, targetID, ctx.UserID, count)

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Content: fmt.Sprintf("⚠️ **%s** has been warned. Reason: %s (Warning #%d)", username, reason, count),
	}, nil
}

func (b *ModerationBot) handleWarnings(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, ok := ctx.Options["user"].(string)
	if !ok || targetID == "" {
		return &commands.CommandResponse{Content: "❌ Invalid user specified.", Ephemeral: true}, nil
	}

	rows, err := b.ctx.DB.Query(reqCtx,
		`SELECT id, reason, moderator_id, created_at FROM warnings
		 WHERE server_id = $1 AND user_id = $2
		 ORDER BY created_at DESC LIMIT 10`,
		ctx.ServerID, targetID)
	if err != nil {
		return nil, fmt.Errorf("fetch warnings failed: %w", err)
	}
	defer rows.Close()

	var fields []commands.EmbedField
	for rows.Next() {
		var id, reason string
		var modID *string
		var createdAt time.Time
		if err := rows.Scan(&id, &reason, &modID, &createdAt); err != nil {
			continue
		}
		modStr := "system"
		if modID != nil && *modID != "" {
			modStr = fmt.Sprintf("<@%s>", *modID)
		}
		shortID := id
		if len(shortID) > 8 {
			shortID = shortID[:8]
		}
		fields = append(fields, commands.EmbedField{
			Name:  fmt.Sprintf("#%s — %s", shortID, createdAt.Format("Jan 2, 2006")),
			Value: fmt.Sprintf("Reason: %s\nBy: %s", reason, modStr),
		})
	}

	if len(fields) == 0 {
		return &commands.CommandResponse{Content: "✅ This user has no warnings."}, nil
	}

	username := LookupUsername(b.ctx, targetID)
	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:  fmt.Sprintf("Warnings for %s", username),
			Color:  "#FFA500",
			Fields: fields,
		},
	}, nil
}

func (b *ModerationBot) handlePurge(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	countFloat, ok := ctx.Options["count"].(float64)
	if !ok {
		return &commands.CommandResponse{Content: "❌ Invalid count specified.", Ephemeral: true}, nil
	}
	count := int(countFloat)
	if count < 1 || count > 100 {
		return &commands.CommandResponse{Content: "❌ Count must be between 1 and 100.", Ephemeral: true}, nil
	}

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageMessages) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to purge messages.", Ephemeral: true}, nil
	}

	targetID, _ := ctx.Options["user"].(string)

	// Collect IDs first so we can publish a MESSAGE_DELETE_BULK event
	// (HIGH-16) and so realtime clients can reconcile their local cache.
	var (
		query string
		args  []interface{}
	)
	if targetID != "" {
		query = `SELECT id FROM messages WHERE channel_id = $1 AND author_id = $2 ORDER BY created_at DESC LIMIT $3`
		args = []interface{}{ctx.ChannelID, targetID, count}
	} else {
		query = `SELECT id FROM messages WHERE channel_id = $1 ORDER BY created_at DESC LIMIT $2`
		args = []interface{}{ctx.ChannelID, count}
	}

	rows, err := b.ctx.DB.Query(reqCtx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("purge query failed: %w", err)
	}
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()

	if len(ids) == 0 {
		return &commands.CommandResponse{Content: "🗑️ Nothing to delete.", Ephemeral: true}, nil
	}

	tag, err := b.ctx.DB.Exec(reqCtx,
		`DELETE FROM messages WHERE id = ANY($1::uuid[])`, ids)
	if err != nil {
		return nil, fmt.Errorf("purge failed: %w", err)
	}

	LogAudit(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, "purge", "channel", ctx.ChannelID,
		fmt.Sprintf("Purged %d messages", tag.RowsAffected()))

	// Best-effort realtime fan-out so clients can drop the deleted IDs.
	b.ctx.EventBus.Publish(events.Event{
		Type:      events.MessageDelete,
		ServerID:  ctx.ServerID,
		ChannelID: ctx.ChannelID,
		Data: map[string]interface{}{
			"message_ids": ids,
			"bulk":        true,
			"actor_id":    ctx.UserID,
		},
		Timestamp: time.Now(),
	})

	return &commands.CommandResponse{
		Content:   fmt.Sprintf("🗑️ Deleted %d messages.", tag.RowsAffected()),
		Ephemeral: true,
	}, nil
}

func (b *ModerationBot) handleSlowmode(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	secondsFloat, ok := ctx.Options["seconds"].(float64)
	if !ok {
		return &commands.CommandResponse{Content: "❌ Invalid seconds specified.", Ephemeral: true}, nil
	}
	seconds := int(secondsFloat)

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageMessages) {
		return &commands.CommandResponse{Content: "❌ You don't have permission to set slowmode.", Ephemeral: true}, nil
	}

	if _, err := b.ctx.DB.Exec(reqCtx,
		`UPDATE channels SET slowmode_seconds = $1 WHERE id = $2 AND server_id = $3`,
		seconds, ctx.ChannelID, ctx.ServerID); err != nil {
		return nil, fmt.Errorf("slowmode update failed: %w", err)
	}

	if seconds == 0 {
		return &commands.CommandResponse{Content: "⏱️ Slowmode has been disabled."}, nil
	}
	return &commands.CommandResponse{
		Content: fmt.Sprintf("⏱️ Slowmode set to %d seconds.", seconds),
	}, nil
}

func (b *ModerationBot) handleModlog(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
	defer cancel()

	targetID, _ := ctx.Options["user"].(string)
	limitFloat, _ := ctx.Options["limit"].(float64)
	limit := int(limitFloat)
	if limit <= 0 || limit > 50 {
		limit = 10
	}

	var (
		query string
		args  []interface{}
	)
	if targetID != "" {
		query = `SELECT action_type, target_id, actor_id, reason, created_at FROM audit_logs WHERE server_id = $1 AND target_id = $2 ORDER BY created_at DESC LIMIT $3`
		args = []interface{}{ctx.ServerID, targetID, limit}
	} else {
		query = `SELECT action_type, target_id, actor_id, reason, created_at FROM audit_logs WHERE server_id = $1 ORDER BY created_at DESC LIMIT $2`
		args = []interface{}{ctx.ServerID, limit}
	}

	rows, err := b.ctx.DB.Query(reqCtx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("modlog query failed: %w", err)
	}
	defer rows.Close()

	var fields []commands.EmbedField
	for rows.Next() {
		var action, reason string
		var target, actor *string
		var createdAt time.Time
		if err := rows.Scan(&action, &target, &actor, &reason, &createdAt); err != nil {
			continue
		}

		actorStr := "system"
		if actor != nil && *actor != "" {
			actorStr = fmt.Sprintf("<@%s>", *actor)
		}
		targetStr := "—"
		if target != nil && *target != "" {
			targetStr = fmt.Sprintf("<@%s>", *target)
		}
		fields = append(fields, commands.EmbedField{
			Name:  fmt.Sprintf("%s — %s", strings.ToUpper(action), createdAt.Format("Jan 2 15:04")),
			Value: fmt.Sprintf("Target: %s\nActor: %s\n%s", targetStr, actorStr, reason),
		})
	}

	if len(fields) == 0 {
		return &commands.CommandResponse{Content: "📋 No moderation logs found."}, nil
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:  "📋 Moderation Log",
			Color:  "#5865F2",
			Fields: fields,
		},
	}, nil
}

// ── Helpers ─────────────────────────────────────────────────────────────────

func (b *ModerationBot) checkWarningEscalation(parent context.Context, serverID, targetID, modID string, count int) {
	var maxWarnings int
	var maxAction string
	if err := b.ctx.DB.QueryRow(parent,
		`SELECT max_warnings, max_warning_action FROM mod_settings WHERE server_id = $1`,
		serverID).Scan(&maxWarnings, &maxAction); err != nil {
		return // no settings = no escalation
	}

	if count < maxWarnings {
		return
	}

	// CRIT-12 fix: every escalation invocation MUST carry a non-nil context.
	autoCtx := commands.CommandContext{
		Ctx:      context.Background(),
		ServerID: serverID,
		UserID:   modID,
		Options: map[string]interface{}{
			"user":   targetID,
			"reason": fmt.Sprintf("Auto-escalation: reached %d warnings", count),
		},
	}

	switch maxAction {
	case "mute":
		autoCtx.Options["duration"] = "1h"
		if _, err := b.handleMute(autoCtx); err != nil {
			b.logger.Error("auto-mute escalation failed", zap.Error(err))
		}
	case "kick":
		if _, err := b.handleKick(autoCtx); err != nil {
			b.logger.Error("auto-kick escalation failed", zap.Error(err))
		}
	case "ban":
		if _, err := b.handleBan(autoCtx); err != nil {
			b.logger.Error("auto-ban escalation failed", zap.Error(err))
		}
	}
}

func (b *ModerationBot) checkExpiredPunishments(evt events.Event) error {
	return b.expirePunishments()
}

func (b *ModerationBot) punishmentExpiryLoop(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := b.expirePunishments(); err != nil {
				b.logger.Error("punishment expiry error", zap.Error(err))
			}
		}
	}
}

func (b *ModerationBot) expirePunishments() error {
	ctx := context.Background()
	rows, err := b.ctx.DB.Query(ctx,
		`UPDATE temp_punishments SET active = false
		 WHERE active = true AND expires_at <= NOW()
		 RETURNING server_id, user_id, type`)
	if err != nil {
		if strings.Contains(err.Error(), "temp_punishments") || strings.Contains(err.Error(), "42P01") {
			return nil
		}
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var serverID, userID, pType string
		if err := rows.Scan(&serverID, &userID, &pType); err != nil {
			continue
		}
		b.logger.Info("punishment expired",
			zap.String("type", pType),
			zap.String("user", userID),
			zap.String("server", serverID),
		)
	}
	return nil
}

// parseDuration is removed — the canonical implementation lives in helpers.go
// (ParseDuration). It rejects non-positive values and caps at 30 days.
