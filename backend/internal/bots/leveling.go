package bots

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// sqrt is a package-level alias for math.Sqrt to keep the levelForXP formula readable.
var sqrt = math.Sqrt

// LevelingBot tracks user XP, levels, and rewards.
type LevelingBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewLevelingBot(router *commands.Router) *LevelingBot {
	return &LevelingBot{router: router}
}

func (b *LevelingBot) Name() string { return "leveling" }

func (b *LevelingBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.leveling")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.MessageCreate, "leveling-xp", b.onMessageCreate)

	b.logger.Info("leveling bot registered")
	return nil
}

func (b *LevelingBot) Shutdown() error { return nil }

func (b *LevelingBot) registerCommands() {
	// /rank [user]
	b.router.Register(commands.CommandDefinition{
		Name:        "rank",
		Description: "View your or another user's rank card",
		BotName:     "leveling",
		Options: []commands.CommandOption{
			{Name: "user", Description: "The user to check", Type: 6, Required: false},
		},
	}, b.handleRank)

	// /leaderboard [page]
	b.router.Register(commands.CommandDefinition{
		Name:        "leaderboard",
		Description: "View the server XP leaderboard",
		BotName:     "leveling",
		Options: []commands.CommandOption{
			{Name: "page", Description: "Page number", Type: 4, Required: false},
		},
	}, b.handleLeaderboard)

	// /xp set|add|remove <user> <amount>
	b.router.Register(commands.CommandDefinition{
		Name:        "xp",
		Description: "Manage user XP",
		BotName:     "leveling",
		Options: []commands.CommandOption{
			{Name: "action", Description: "set, add, remove, or reset", Type: 3, Required: true},
			{Name: "user", Description: "Target user", Type: 6, Required: true},
			{Name: "amount", Description: "XP amount", Type: 4, Required: false},
		},
	}, b.handleXP)

	// /level-config <action> [options]
	b.router.Register(commands.CommandDefinition{
		Name:        "level-config",
		Description: "Configure leveling system",
		BotName:     "leveling",
		Options: []commands.CommandOption{
			{Name: "action", Description: "enable, disable, status, reward, multiplier, noxp, message", Type: 3, Required: true},
			{Name: "level", Description: "Level for reward", Type: 4, Required: false},
			{Name: "role", Description: "Role to assign", Type: 8, Required: false},
			{Name: "channel", Description: "Channel for level-up messages or no-xp", Type: 7, Required: false},
			{Name: "value", Description: "Value for setting (multiplier, message, etc.)", Type: 3, Required: false},
		},
	}, b.handleLevelConfig)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *LevelingBot) handleRank(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 10*time.Second)
	defer cancel()

	targetID, _ := ctx.Options["user"].(string)
	if targetID == "" {
		targetID = ctx.UserID
	}

	var xp, level, messageCount int
	var rank int
	err := b.ctx.DB.QueryRow(reqCtx,
		`SELECT xp, level, message_count FROM user_xp WHERE user_id = $1 AND server_id = $2`,
		targetID, ctx.ServerID).Scan(&xp, &level, &messageCount)
	if err != nil {
		return &commands.CommandResponse{Content: "This user has no XP yet. Start chatting to earn XP!", Ephemeral: true}, nil
	}

	_ = b.ctx.DB.QueryRow(reqCtx,
		`SELECT COUNT(*) + 1 FROM user_xp WHERE server_id = $1 AND xp > $2`,
		ctx.ServerID, xp).Scan(&rank)

	username := LookupUsername(b.ctx, targetID)
	nextLevelXP := xpForLevel(level + 1)
	currentLevelXP := xpForLevel(level)
	denom := float64(nextLevelXP - currentLevelXP)
	progress := 0.0
	if denom > 0 {
		progress = float64(xp-currentLevelXP) / denom * 100
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: fmt.Sprintf("🏅 %s's Rank Card", username),
			Color: "#5865F2",
			Fields: []commands.EmbedField{
				{Name: "Rank", Value: fmt.Sprintf("#%d", rank), Inline: true},
				{Name: "Level", Value: fmt.Sprintf("%d", level), Inline: true},
				{Name: "XP", Value: fmt.Sprintf("%d / %d", xp, nextLevelXP), Inline: true},
				{Name: "Messages", Value: fmt.Sprintf("%d", messageCount), Inline: true},
				{Name: "Progress", Value: fmt.Sprintf("%.1f%%", progress), Inline: true},
			},
		},
	}, nil
}

func (b *LevelingBot) handleLeaderboard(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	pageFloat, _ := ctx.Options["page"].(float64)
	page := int(pageFloat)
	if page < 1 {
		page = 1
	}
	limit := 10
	offset := (page - 1) * limit

	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT ux.user_id, ux.xp, ux.level, u.username
		 FROM user_xp ux
		 JOIN users u ON u.id = ux.user_id
		 WHERE ux.server_id = $1
		 ORDER BY ux.xp DESC
		 LIMIT $2 OFFSET $3`,
		ctx.ServerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var fields []commands.EmbedField
	pos := offset + 1
	for rows.Next() {
		var userID, username string
		var xp, level int
		if err := rows.Scan(&userID, &xp, &level, &username); err != nil {
			continue
		}

		medal := ""
		switch pos {
		case 1:
			medal = "🥇"
		case 2:
			medal = "🥈"
		case 3:
			medal = "🥉"
		default:
			medal = fmt.Sprintf("#%d", pos)
		}

		fields = append(fields, commands.EmbedField{
			Name:  fmt.Sprintf("%s %s", medal, username),
			Value: fmt.Sprintf("Level %d • %d XP", level, xp),
		})
		pos++
	}

	if len(fields) == 0 {
		return &commands.CommandResponse{Content: "📊 No one has earned XP yet!"}, nil
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:  fmt.Sprintf("📊 Leaderboard (Page %d)", page),
			Color:  "#FFD700",
			Fields: fields,
		},
	}, nil
}

func (b *LevelingBot) handleXP(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)
	targetID, _ := ctx.Options["user"].(string)
	amountFloat, _ := ctx.Options["amount"].(float64)
	amount := int(amountFloat)

	if !HasPermission(context.Background(), b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{Content: "❌ Only admins can manage XP.", Ephemeral: true}, nil
	}

	username := LookupUsername(b.ctx, targetID)

	switch strings.ToLower(action) {
	case "set":
		level := levelForXP(amount)
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO user_xp (user_id, server_id, xp, level) VALUES ($1, $2, $3, $4)
			 ON CONFLICT (user_id, server_id) DO UPDATE SET xp = $3, level = $4`,
			targetID, ctx.ServerID, amount, level)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Set **%s**'s XP to %d (Level %d).", username, amount, level)}, nil

	case "add":
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO user_xp (user_id, server_id, xp, level) VALUES ($1, $2, $3, $4)
			 ON CONFLICT (user_id, server_id) DO UPDATE SET xp = user_xp.xp + $3`,
			targetID, ctx.ServerID, amount, 0)
		if err != nil {
			return nil, err
		}
		// Recalculate level
		b.recalculateLevel(ctx.ServerID, targetID)
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Added %d XP to **%s**.", amount, username)}, nil

	case "remove":
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE user_xp SET xp = GREATEST(0, xp - $3) WHERE user_id = $1 AND server_id = $2`,
			targetID, ctx.ServerID, amount)
		if err != nil {
			return nil, err
		}
		b.recalculateLevel(ctx.ServerID, targetID)
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Removed %d XP from **%s**.", amount, username)}, nil

	case "reset":
		_, err := b.ctx.DB.Exec(context.Background(),
			`DELETE FROM user_xp WHERE user_id = $1 AND server_id = $2`,
			targetID, ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Reset all XP for **%s**.", username)}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: set, add, remove, reset", Ephemeral: true}, nil
	}
}

func (b *LevelingBot) handleLevelConfig(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)

	if !HasPermission(context.Background(), b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{Content: "❌ Only admins can configure leveling.", Ephemeral: true}, nil
	}

	switch strings.ToLower(action) {
	case "enable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO level_settings (server_id, enabled) VALUES ($1, true)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, updated_at = now()`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "✅ Leveling system enabled!"}, nil

	case "disable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE level_settings SET enabled = false, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "🔴 Leveling system disabled."}, nil

	case "status":
		return b.getLevelStatus(ctx.ServerID)

	case "reward":
		levelFloat, _ := ctx.Options["level"].(float64)
		level := int(levelFloat)
		roleID, _ := ctx.Options["role"].(string)
		if level <= 0 || roleID == "" {
			return &commands.CommandResponse{Content: "❌ Provide a level and role.", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO level_role_rewards (server_id, level, role_id) VALUES ($1, $2, $3)
			 ON CONFLICT (server_id, level) DO UPDATE SET role_id = $3`,
			ctx.ServerID, level, roleID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Level %d reward: <@&%s>", level, roleID)}, nil

	case "multiplier":
		value, _ := ctx.Options["value"].(string)
		channelID, _ := ctx.Options["channel"].(string)
		roleID, _ := ctx.Options["role"].(string)

		var targetType, targetID string
		if channelID != "" {
			targetType = "channel"
			targetID = channelID
		} else if roleID != "" {
			targetType = "role"
			targetID = roleID
		} else {
			return &commands.CommandResponse{Content: "❌ Provide a channel or role.", Ephemeral: true}, nil
		}

		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO xp_multipliers (server_id, target_type, target_id, multiplier) VALUES ($1, $2, $3, $4::numeric)
			 ON CONFLICT (server_id, target_type, target_id) DO UPDATE SET multiplier = $4::numeric`,
			ctx.ServerID, targetType, targetID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ XP multiplier for %s set to %sx.", targetType, value)}, nil

	case "noxp":
		channelID, _ := ctx.Options["channel"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE level_settings SET no_xp_channels = array_append(
				COALESCE(no_xp_channels, '{}'), $2::uuid
			), updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ No XP will be earned in <#%s>.", channelID)}, nil

	case "message":
		msg, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE level_settings SET level_up_message = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, msg)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Level-up message updated: %s", msg)}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: enable, disable, status, reward, multiplier, noxp, message", Ephemeral: true}, nil
	}
}

func (b *LevelingBot) getLevelStatus(serverID string) (*commands.CommandResponse, error) {
	var s struct {
		Enabled    bool
		XPMin      int
		XPMax      int
		Cooldown   int
		Message    string
		StackRoles bool
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, xp_min, xp_max, cooldown_seconds, level_up_message, stack_roles
		 FROM level_settings WHERE server_id = $1`, serverID).Scan(
		&s.Enabled, &s.XPMin, &s.XPMax, &s.Cooldown, &s.Message, &s.StackRoles,
	)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ Leveling is not configured. Use `/level-config enable` first."}, nil
	}

	// Count rewards
	var rewardCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM level_role_rewards WHERE server_id = $1`, serverID).Scan(&rewardCount)

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: "📈 Leveling Configuration",
			Color: "#57F287",
			Fields: []commands.EmbedField{
				{Name: "Status", Value: BoolEmoji(s.Enabled), Inline: true},
				{Name: "XP Range", Value: fmt.Sprintf("%d - %d per message", s.XPMin, s.XPMax), Inline: true},
				{Name: "Cooldown", Value: fmt.Sprintf("%ds", s.Cooldown), Inline: true},
				{Name: "Stack Roles", Value: BoolEmoji(s.StackRoles), Inline: true},
				{Name: "Role Rewards", Value: fmt.Sprintf("%d configured", rewardCount), Inline: true},
				{Name: "Level-Up Message", Value: s.Message},
			},
		},
	}, nil
}

// ── XP Processing ───────────────────────────────────────────────────────────

func (b *LevelingBot) onMessageCreate(evt events.Event) error {
	if evt.ServerID == "" {
		return nil
	}

	authorID, _ := evt.Data["author_id"].(string)
	if authorID == "" {
		return nil
	}

	// Load settings
	var settings struct {
		Enabled          bool
		XPMin            int
		XPMax            int
		Cooldown         int
		Message          string
		NoXPChannels     []string
		StackRoles       bool
		LevelUpChannelID *string
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, xp_min, xp_max, cooldown_seconds, level_up_message,
				no_xp_channels, stack_roles, level_up_channel_id
		 FROM level_settings WHERE server_id = $1`, evt.ServerID).Scan(
		&settings.Enabled, &settings.XPMin, &settings.XPMax, &settings.Cooldown,
		&settings.Message, &settings.NoXPChannels, &settings.StackRoles, &settings.LevelUpChannelID,
	)
	if err != nil || !settings.Enabled {
		return nil
	}

	// Check no-xp channels
	for _, ch := range settings.NoXPChannels {
		if ch == evt.ChannelID {
			return nil
		}
	}

	// Check cooldown (MED-3: default 60s if settings.Cooldown is 0)
	cooldown := settings.Cooldown
	if cooldown <= 0 {
		cooldown = 60
	}
	var lastXP time.Time
	err = b.ctx.DB.QueryRow(context.Background(),
		`SELECT last_xp_at FROM user_xp WHERE user_id = $1 AND server_id = $2`,
		authorID, evt.ServerID).Scan(&lastXP)
	if err == nil && time.Since(lastXP) < time.Duration(cooldown)*time.Second {
		return nil // on cooldown
	}

	// Calculate XP with multipliers
	baseXP := settings.XPMin + rand.Intn(settings.XPMax-settings.XPMin+1)
	multiplier := b.getMultiplier(evt.ServerID, authorID, evt.ChannelID)
	xpGain := int(float64(baseXP) * multiplier)

	// Update XP
	var currentXP, currentLevel int
	err = b.ctx.DB.QueryRow(context.Background(),
		`INSERT INTO user_xp (user_id, server_id, xp, level, message_count, last_xp_at)
		 VALUES ($1, $2, $3, 0, 1, NOW())
		 ON CONFLICT (user_id, server_id) DO UPDATE SET
			xp = user_xp.xp + $3,
			message_count = user_xp.message_count + 1,
			last_xp_at = NOW()
		 RETURNING xp, level`,
		authorID, evt.ServerID, xpGain).Scan(&currentXP, &currentLevel)
	if err != nil {
		return fmt.Errorf("xp update failed: %w", err)
	}

	// Check for level up
	newLevel := levelForXP(currentXP)
	if newLevel > currentLevel {
		// Update stored level
		b.ctx.DB.Exec(context.Background(),
			`UPDATE user_xp SET level = $3 WHERE user_id = $1 AND server_id = $2`,
			authorID, evt.ServerID, newLevel)

		// Send level up message
		b.sendLevelUpMessage(evt.ServerID, evt.ChannelID, authorID, newLevel, settings.Message, settings.LevelUpChannelID)

		// Check role rewards
		b.checkRoleRewards(evt.ServerID, authorID, newLevel, settings.StackRoles)
	}

	return nil
}

func (b *LevelingBot) getMultiplier(serverID, userID, channelID string) float64 {
	multiplier := 1.0

	// Channel multiplier
	var chanMult float64
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT multiplier FROM xp_multipliers WHERE server_id = $1 AND target_type = 'channel' AND target_id = $2`,
		serverID, channelID).Scan(&chanMult)
	if err == nil {
		multiplier *= chanMult
	}

	// Role multiplier (use highest)
	var roleMult float64
	err = b.ctx.DB.QueryRow(context.Background(),
		`SELECT COALESCE(MAX(m.multiplier), 1.0)
		 FROM xp_multipliers m
		 JOIN member_roles mr ON mr.role_id = m.target_id::uuid
		 WHERE m.server_id = $1 AND m.target_type = 'role' AND mr.user_id = $2`,
		serverID, userID).Scan(&roleMult)
	if err == nil && roleMult > 1.0 {
		multiplier *= roleMult
	}

	return multiplier
}

func (b *LevelingBot) sendLevelUpMessage(serverID, channelID, userID string, level int, template string, lvlUpChannel *string) {
	username := LookupUsername(b.ctx, userID)

	msg := template
	msg = strings.ReplaceAll(msg, "{{user}}", fmt.Sprintf("<@%s>", userID))
	msg = strings.ReplaceAll(msg, "{{username}}", username)
	msg = strings.ReplaceAll(msg, "{{level}}", fmt.Sprintf("%d", level))

	targetChannel := channelID
	if lvlUpChannel != nil && *lvlUpChannel != "" {
		targetChannel = *lvlUpChannel
	}

	SendBotMessage(b.ctx, targetChannel, msg)
}

func (b *LevelingBot) checkRoleRewards(serverID, userID string, level int, stackRoles bool) {
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT level, role_id, remove_previous FROM level_role_rewards
		 WHERE server_id = $1 AND level <= $2 ORDER BY level DESC`,
		serverID, level)
	if err != nil {
		return
	}
	defer rows.Close()

	isFirst := true
	for rows.Next() {
		var rewardLevel int
		var roleID string
		var removePrevious bool
		if err := rows.Scan(&rewardLevel, &roleID, &removePrevious); err != nil {
			continue
		}

		if isFirst || stackRoles {
			// Grant role
			b.ctx.DB.Exec(context.Background(),
				`INSERT INTO member_roles (server_id, user_id, role_id) VALUES ($1, $2, $3::uuid) ON CONFLICT DO NOTHING`,
				serverID, userID, roleID)
		}

		if isFirst && removePrevious && !stackRoles {
			// Remove lower-level roles
			b.ctx.DB.Exec(context.Background(),
				`DELETE FROM member_roles WHERE server_id = $1 AND user_id = $2
				 AND role_id IN (SELECT role_id::uuid FROM level_role_rewards WHERE server_id = $1 AND level < $3)`,
				serverID, userID, rewardLevel)
		}

		isFirst = false
	}
}

func (b *LevelingBot) recalculateLevel(serverID, userID string) {
	var xp int
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT xp FROM user_xp WHERE user_id = $1 AND server_id = $2`,
		userID, serverID).Scan(&xp)
	if err != nil {
		return
	}
	newLevel := levelForXP(xp)
	b.ctx.DB.Exec(context.Background(),
		`UPDATE user_xp SET level = $3 WHERE user_id = $1 AND server_id = $2`,
		userID, serverID, newLevel)
}

// checkAdminPermission and getUsername removed — use shared helpers
// HasPermission / LookupUsername from helpers.go.

// ── XP/Level Math ───────────────────────────────────────────────────────────

// xpForLevel returns the total XP required to reach a given level.
// Uses Discord-like formula: 5 * (lvl^2) + (50 * lvl) + 100
func xpForLevel(level int) int {
	return 5*(level*level) + 50*level + 100
}

// levelForXP returns the level for a given amount of total XP.
// HIGH-5 fix: closed-form inverse of the quadratic formula instead of O(level) loop.
// Formula: level = floor((-50 + sqrt(2500 + 20*(xp-100))) / 10)
func levelForXP(xp int) int {
	if xp < 100 {
		return 0
	}
	// Solve 5*L^2 + 50*L + 100 <= xp
	// => L <= (-50 + sqrt(2500 + 20*(xp-100))) / 10
	discriminant := float64(2500 + 20*(xp-100))
	if discriminant < 0 {
		return 0
	}
	level := int((-50.0 + sqrt(discriminant)) / 10.0)
	if level < 0 {
		return 0
	}
	// Safety cap
	if level > 1000 {
		level = 1000
	}
	return level
}
