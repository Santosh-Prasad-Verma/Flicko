package bots

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// StarboardBot promotes popular messages to a starboard channel.
type StarboardBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewStarboardBot(router *commands.Router) *StarboardBot {
	return &StarboardBot{router: router}
}

func (b *StarboardBot) Name() string { return "starboard" }

func (b *StarboardBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.starboard")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.ReactionAdd, "starboard-add", b.onReactionAdd)
	bctx.EventBus.Subscribe(events.ReactionRemove, "starboard-remove", b.onReactionRemove)

	b.logger.Info("starboard bot registered")
	return nil
}

func (b *StarboardBot) Shutdown() error { return nil }

func (b *StarboardBot) registerCommands() {
	// /starboard <action>
	b.router.Register(commands.CommandDefinition{
		Name:        "starboard",
		Description: "Configure the starboard",
		BotName:     "starboard",
		Options: []commands.CommandOption{
			{Name: "action", Description: "setup, status, threshold, emoji, ignore, self-star", Type: 3, Required: true},
			{Name: "channel", Description: "Starboard channel", Type: 7, Required: false},
			{Name: "value", Description: "Value for the setting", Type: 3, Required: false},
			{Name: "enabled", Description: "Enable or disable", Type: 5, Required: false},
		},
	}, b.handleStarboard)

	// /stars [user]
	b.router.Register(commands.CommandDefinition{
		Name:        "stars",
		Description: "View starboard stats",
		BotName:     "starboard",
		Options: []commands.CommandOption{
			{Name: "user", Description: "View stats for a user", Type: 6, Required: false},
		},
	}, b.handleStars)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *StarboardBot) handleStarboard(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{
			Content:   "❌ You need the Manage Server permission to configure the starboard.",
			Ephemeral: true,
		}, nil
	}

	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "setup":
		channelID, _ := ctx.Options["channel"].(string)
		if channelID == "" {
			return &commands.CommandResponse{Content: "❌ Please specify a channel.", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO starboard_settings (server_id, enabled, starboard_channel_id)
			 VALUES ($1, true, $2)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, starboard_channel_id = $2, updated_at = now()`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("⭐ Starboard enabled in <#%s>!", channelID)}, nil

	case "status":
		return b.getStatus(ctx.ServerID)

	case "threshold":
		value, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE starboard_settings SET star_threshold = $2::integer, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("⭐ Star threshold set to %s.", value)}, nil

	case "emoji":
		value, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE starboard_settings SET star_emoji = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("⭐ Star emoji set to %s.", value)}, nil

	case "ignore":
		channelID, _ := ctx.Options["channel"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE starboard_settings SET ignored_channels = array_append(
				COALESCE(ignored_channels, '{}'), $2::uuid
			), updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("⭐ <#%s> will be ignored by the starboard.", channelID)}, nil

	case "self-star":
		enabled, _ := ctx.Options["enabled"].(bool)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE starboard_settings SET self_star = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, enabled)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("⭐ Self-starring %s.", BoolEmoji(enabled))}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: setup, status, threshold, emoji, ignore, self-star", Ephemeral: true}, nil
	}
}

func (b *StarboardBot) handleStars(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	targetID, _ := ctx.Options["user"].(string)

	if targetID != "" {
		// Show user stats
		var totalStars int
		var topMessage string
		var topStars int

		b.ctx.DB.QueryRow(context.Background(),
			`SELECT COALESCE(SUM(star_count), 0) FROM starboard_entries WHERE server_id = $1 AND author_id = $2`,
			ctx.ServerID, targetID).Scan(&totalStars)

		b.ctx.DB.QueryRow(context.Background(),
			`SELECT COALESCE(content, ''), star_count FROM starboard_entries
			 WHERE server_id = $1 AND author_id = $2
			 ORDER BY star_count DESC LIMIT 1`,
			ctx.ServerID, targetID).Scan(&topMessage, &topStars)

		username := LookupUsername(b.ctx, targetID)
		if len(topMessage) > 50 {
			topMessage = topMessage[:50] + "..."
		}

		return &commands.CommandResponse{
			Embed: &commands.Embed{
				Title: fmt.Sprintf("⭐ %s's Star Stats", username),
				Color: "#FFD700",
				Fields: []commands.EmbedField{
					{Name: "Total Stars", Value: fmt.Sprintf("%d", totalStars), Inline: true},
					{Name: "Top Message", Value: fmt.Sprintf("%d ⭐ — %s", topStars, topMessage)},
				},
			},
		}, nil
	}

	// Show server leaderboard
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT author_id, SUM(star_count) as total_stars
		 FROM starboard_entries WHERE server_id = $1
		 GROUP BY author_id ORDER BY total_stars DESC LIMIT 10`,
		ctx.ServerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var fields []commands.EmbedField
	pos := 1
	for rows.Next() {
		var userID string
		var stars int
		if err := rows.Scan(&userID, &stars); err != nil {
			continue
		}
		username := LookupUsername(b.ctx, userID)
		medal := fmt.Sprintf("#%d", pos)
		switch pos {
		case 1:
			medal = "🥇"
		case 2:
			medal = "🥈"
		case 3:
			medal = "🥉"
		}
		fields = append(fields, commands.EmbedField{
			Name:  fmt.Sprintf("%s %s", medal, username),
			Value: fmt.Sprintf("%d ⭐", stars),
		})
		pos++
	}

	if len(fields) == 0 {
		return &commands.CommandResponse{Content: "⭐ No starred messages yet!"}, nil
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:  "⭐ Starboard Leaderboard",
			Color:  "#FFD700",
			Fields: fields,
		},
	}, nil
}

func (b *StarboardBot) getStatus(serverID string) (*commands.CommandResponse, error) {
	var s struct {
		Enabled   bool
		ChannelID *string
		Threshold int
		Emoji     string
		SelfStar  bool
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, starboard_channel_id, star_threshold, star_emoji, self_star
		 FROM starboard_settings WHERE server_id = $1`, serverID).Scan(
		&s.Enabled, &s.ChannelID, &s.Threshold, &s.Emoji, &s.SelfStar,
	)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ Starboard is not configured. Use `/starboard setup <channel>`."}, nil
	}

	var totalEntries int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM starboard_entries WHERE server_id = $1`, serverID).Scan(&totalEntries)

	channelStr := "Not set"
	if s.ChannelID != nil {
		channelStr = fmt.Sprintf("<#%s>", *s.ChannelID)
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: "⭐ Starboard Configuration",
			Color: "#FFD700",
			Fields: []commands.EmbedField{
				{Name: "Status", Value: BoolEmoji(s.Enabled), Inline: true},
				{Name: "Channel", Value: channelStr, Inline: true},
				{Name: "Threshold", Value: fmt.Sprintf("%d %s", s.Threshold, s.Emoji), Inline: true},
				{Name: "Self-Star", Value: BoolEmoji(s.SelfStar), Inline: true},
				{Name: "Total Entries", Value: fmt.Sprintf("%d", totalEntries), Inline: true},
			},
		},
	}, nil
}

// ── Reaction Handlers ───────────────────────────────────────────────────────

func (b *StarboardBot) onReactionAdd(evt events.Event) error {
	if evt.ServerID == "" {
		return nil
	}

	emoji, _ := evt.Data["emoji"].(string)
	messageID, _ := evt.Data["message_id"].(string)
	userID := evt.UserID

	// Load starboard settings
	var settings struct {
		Enabled         bool
		ChannelID       *string
		Threshold       int
		StarEmoji       string
		SelfStar        bool
		IgnoredChannels []string
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, starboard_channel_id, star_threshold, star_emoji, self_star, ignored_channels
		 FROM starboard_settings WHERE server_id = $1`, evt.ServerID).Scan(
		&settings.Enabled, &settings.ChannelID, &settings.Threshold,
		&settings.StarEmoji, &settings.SelfStar, &settings.IgnoredChannels,
	)
	if err != nil || !settings.Enabled || settings.ChannelID == nil {
		return nil
	}

	// Check emoji matches
	if emoji != settings.StarEmoji {
		return nil
	}

	// Check ignored channels
	for _, ch := range settings.IgnoredChannels {
		if ch == evt.ChannelID {
			return nil
		}
	}

	// Don't star messages in the starboard channel itself
	if evt.ChannelID == *settings.ChannelID {
		return nil
	}

	// Get message info
	var authorID, content string
	err = b.ctx.DB.QueryRow(context.Background(),
		`SELECT author_id, content FROM messages WHERE id = $1`, messageID).Scan(&authorID, &content)
	if err != nil {
		return nil
	}

	// Check self-star
	if !settings.SelfStar && userID == authorID {
		return nil
	}

	// Get or create starboard entry
	var entryID string
	err = b.ctx.DB.QueryRow(context.Background(),
		`INSERT INTO starboard_entries (server_id, original_message_id, original_channel_id, author_id, content, star_count)
		 VALUES ($1, $2, $3, $4, $5, 0)
		 ON CONFLICT (server_id, original_message_id) DO UPDATE SET content = $5
		 RETURNING id`,
		evt.ServerID, messageID, evt.ChannelID, authorID, content).Scan(&entryID)
	if err != nil {
		return fmt.Errorf("starboard entry upsert failed: %w", err)
	}

	// Add star
	_, err = b.ctx.DB.Exec(context.Background(),
		`INSERT INTO starboard_stars (entry_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		entryID, userID)
	if err != nil {
		return nil
	}

	// Update star count
	var starCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM starboard_stars WHERE entry_id = $1`, entryID).Scan(&starCount)

	b.ctx.DB.Exec(context.Background(),
		`UPDATE starboard_entries SET star_count = $2 WHERE id = $1`, entryID, starCount)

	// Check threshold
	if starCount >= settings.Threshold {
		b.postOrUpdateStarboardMessage(entryID, *settings.ChannelID, evt.ChannelID, messageID, authorID, content, starCount, settings.StarEmoji)
	}

	return nil
}

func (b *StarboardBot) onReactionRemove(evt events.Event) error {
	if evt.ServerID == "" {
		return nil
	}

	emoji, _ := evt.Data["emoji"].(string)
	messageID, _ := evt.Data["message_id"].(string)

	// Load settings
	var starEmoji string
	var channelID *string
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT star_emoji, starboard_channel_id FROM starboard_settings WHERE server_id = $1 AND enabled = true`,
		evt.ServerID).Scan(&starEmoji, &channelID)
	if err != nil || channelID == nil || emoji != starEmoji {
		return nil
	}

	// Find entry
	var entryID string
	err = b.ctx.DB.QueryRow(context.Background(),
		`SELECT id FROM starboard_entries WHERE server_id = $1 AND original_message_id = $2`,
		evt.ServerID, messageID).Scan(&entryID)
	if err != nil {
		return nil
	}

	// Remove star
	b.ctx.DB.Exec(context.Background(),
		`DELETE FROM starboard_stars WHERE entry_id = $1 AND user_id = $2`,
		entryID, evt.UserID)

	// Update count
	var starCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM starboard_stars WHERE entry_id = $1`, entryID).Scan(&starCount)

	b.ctx.DB.Exec(context.Background(),
		`UPDATE starboard_entries SET star_count = $2 WHERE id = $1`, entryID, starCount)

	return nil
}

// ── Starboard Message ───────────────────────────────────────────────────────

func (b *StarboardBot) postOrUpdateStarboardMessage(entryID, starboardChannelID, originalChannelID, originalMessageID, authorID, content string, starCount int, emoji string) {
	username := LookupUsername(b.ctx, authorID)

	if len(content) > 200 {
		content = content[:200] + "..."
	}

	starMsg := fmt.Sprintf("%s **%d** | <#%s>\n\n**%s**: %s",
		emoji, starCount, originalChannelID, username, content)

	// Check if already posted
	var sbMessageID *string
	_ = b.ctx.DB.QueryRow(context.Background(),
		`SELECT starboard_message_id FROM starboard_entries WHERE id = $1`, entryID).Scan(&sbMessageID)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	systemID, _ := EnsureSystemUser(ctx, b.ctx)

	if sbMessageID != nil {
		// Update existing
		_, _ = b.ctx.DB.Exec(ctx,
			`UPDATE messages SET content = $2 WHERE id = $1`, *sbMessageID, starMsg)
	} else {
		// Create new (CRIT-6 fix: use author_id column, nullable)
		var newMsgID string
		var err error
		if systemID != "" {
			err = b.ctx.DB.QueryRow(ctx,
				`INSERT INTO messages (channel_id, author_id, content, type, created_at)
				 VALUES ($1, $2, $3, 'system', NOW()) RETURNING id`,
				starboardChannelID, systemID, starMsg).Scan(&newMsgID)
		} else {
			err = b.ctx.DB.QueryRow(ctx,
				`INSERT INTO messages (channel_id, author_id, content, type, created_at)
				 VALUES ($1, NULL, $2, 'system', NOW()) RETURNING id`,
				starboardChannelID, starMsg).Scan(&newMsgID)
		}
		if err != nil {
			b.logger.Error("starboard message post failed", zap.Error(err))
			return
		}
		_, _ = b.ctx.DB.Exec(ctx,
			`UPDATE starboard_entries SET starboard_message_id = $2 WHERE id = $1`,
			entryID, newMsgID)
	}
}

// getUsername removed — use LookupUsername from helpers.go
