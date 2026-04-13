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

// WelcomeBot sends welcome/goodbye messages and assigns auto roles.
type WelcomeBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewWelcomeBot(router *commands.Router) *WelcomeBot {
	return &WelcomeBot{router: router}
}

func (b *WelcomeBot) Name() string { return "welcome" }

func (b *WelcomeBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.welcome")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.MemberJoin, "welcome-greet", b.onMemberJoin)
	bctx.EventBus.Subscribe(events.MemberLeave, "welcome-goodbye", b.onMemberLeave)

	b.logger.Info("welcome bot registered")
	return nil
}

func (b *WelcomeBot) Shutdown() error { return nil }

func (b *WelcomeBot) registerCommands() {
	// /welcome setup <channel>
	b.router.Register(commands.CommandDefinition{
		Name:        "welcome",
		Description: "Configure welcome messages",
		BotName:     "welcome",
		Options: []commands.CommandOption{
			{Name: "action", Description: "setup, test, message, leave, autorole, card, dm, status", Type: 3, Required: true},
			{Name: "channel", Description: "Channel for welcome messages", Type: 7, Required: false},
			{Name: "message", Description: "Welcome message template", Type: 3, Required: false},
			{Name: "role", Description: "Auto-assign role", Type: 8, Required: false},
			{Name: "enabled", Description: "Enable or disable", Type: 5, Required: false},
		},
	}, b.handleWelcome)
}

func (b *WelcomeBot) handleWelcome(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "setup":
		channelID, _ := ctx.Options["channel"].(string)
		if channelID == "" {
			return &commands.CommandResponse{Content: "❌ Please specify a channel.", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO welcome_settings (server_id, enabled, welcome_channel_id)
			 VALUES ($1, true, $2)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, welcome_channel_id = $2, updated_at = now()`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Welcome messages enabled in <#%s>!", channelID)}, nil

	case "test":
		return b.testWelcome(ctx.ServerID, ctx.UserID)

	case "message":
		msg, _ := ctx.Options["message"].(string)
		if msg == "" {
			return &commands.CommandResponse{Content: "❌ Please provide a message. Variables: {{user}}, {{username}}, {{server}}, {{memberCount}}", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE welcome_settings SET welcome_message = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, msg)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Welcome message updated to: %s", msg)}, nil

	case "leave":
		channelID, _ := ctx.Options["channel"].(string)
		msg, _ := ctx.Options["message"].(string)
		enabled, _ := ctx.Options["enabled"].(bool)

		query := `UPDATE welcome_settings SET leave_enabled = $2`
		args := []interface{}{ctx.ServerID, enabled}
		if channelID != "" {
			query += `, leave_channel_id = $3`
			args = append(args, channelID)
		}
		if msg != "" {
			query += fmt.Sprintf(`, leave_message = $%d`, len(args)+1)
			args = append(args, msg)
		}
		query += `, updated_at = now() WHERE server_id = $1`

		_, err := b.ctx.DB.Exec(context.Background(), query, args...)
		if err != nil {
			return nil, err
		}

		status := "disabled"
		if enabled {
			status = "enabled"
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Leave messages %s.", status)}, nil

	case "autorole":
		roleID, _ := ctx.Options["role"].(string)
		if roleID == "" {
			return &commands.CommandResponse{Content: "❌ Please specify a role.", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE welcome_settings SET auto_roles = array_append(
				COALESCE(auto_roles, '{}'), $2::uuid
			), updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, roleID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Auto-role added: <@&%s>", roleID)}, nil

	case "card":
		enabled, _ := ctx.Options["enabled"].(bool)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE welcome_settings SET welcome_card_enabled = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, enabled)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Welcome card %s.", boolEmoji(enabled))}, nil

	case "dm":
		enabled, _ := ctx.Options["enabled"].(bool)
		msg, _ := ctx.Options["message"].(string)
		query := `UPDATE welcome_settings SET dm_enabled = $2`
		args := []interface{}{ctx.ServerID, enabled}
		if msg != "" {
			query += `, dm_message = $3`
			args = append(args, msg)
		}
		query += `, updated_at = now() WHERE server_id = $1`
		_, err := b.ctx.DB.Exec(context.Background(), query, args...)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Welcome DMs %s.", boolEmoji(enabled))}, nil

	case "status":
		return b.getWelcomeStatus(ctx.ServerID)

	default:
		return &commands.CommandResponse{
			Content:   "❌ Unknown action. Use: setup, test, message, leave, autorole, card, dm, status",
			Ephemeral: true,
		}, nil
	}
}

func (b *WelcomeBot) getWelcomeStatus(serverID string) (*commands.CommandResponse, error) {
	var s struct {
		Enabled        bool
		ChannelID      *string
		Message        string
		LeaveEnabled   bool
		LeaveChannelID *string
		AutoRoles      []string
		CardEnabled    bool
		DMEnabled      bool
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, welcome_channel_id, welcome_message, leave_enabled,
				leave_channel_id, auto_roles, welcome_card_enabled, dm_enabled
		 FROM welcome_settings WHERE server_id = $1`, serverID).Scan(
		&s.Enabled, &s.ChannelID, &s.Message, &s.LeaveEnabled,
		&s.LeaveChannelID, &s.AutoRoles, &s.CardEnabled, &s.DMEnabled,
	)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ Welcome bot is not configured. Use `/welcome setup <channel>` to get started."}, nil
	}

	channelStr := "Not set"
	if s.ChannelID != nil {
		channelStr = fmt.Sprintf("<#%s>", *s.ChannelID)
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: "👋 Welcome Bot Status",
			Color: "#57F287",
			Fields: []commands.EmbedField{
				{Name: "Status", Value: boolEmoji(s.Enabled), Inline: true},
				{Name: "Channel", Value: channelStr, Inline: true},
				{Name: "Message", Value: s.Message},
				{Name: "Leave Messages", Value: boolEmoji(s.LeaveEnabled), Inline: true},
				{Name: "Welcome Card", Value: boolEmoji(s.CardEnabled), Inline: true},
				{Name: "DM on Join", Value: boolEmoji(s.DMEnabled), Inline: true},
				{Name: "Auto Roles", Value: fmt.Sprintf("%d configured", len(s.AutoRoles)), Inline: true},
			},
		},
	}, nil
}

func (b *WelcomeBot) testWelcome(serverID, userID string) (*commands.CommandResponse, error) {
	msg, err := b.buildWelcomeMessage(serverID, userID)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ Welcome bot is not configured.", Ephemeral: true}, nil
	}
	return &commands.CommandResponse{
		Content:   "📝 **Preview:**\n" + msg,
		Ephemeral: true,
	}, nil
}

// ── Event Handlers ──────────────────────────────────────────────────────────

func (b *WelcomeBot) onMemberJoin(evt events.Event) error {
	if evt.ServerID == "" {
		return nil
	}

	userID := evt.UserID

	// Get settings
	var settings struct {
		Enabled     bool
		ChannelID   *string
		Message     string
		AutoRoles   []string
		CardEnabled bool
		DMEnabled   bool
		DMMessage   string
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, welcome_channel_id, welcome_message, auto_roles,
				welcome_card_enabled, dm_enabled, dm_message
		 FROM welcome_settings WHERE server_id = $1`, evt.ServerID).Scan(
		&settings.Enabled, &settings.ChannelID, &settings.Message,
		&settings.AutoRoles, &settings.CardEnabled, &settings.DMEnabled, &settings.DMMessage,
	)
	if err != nil || !settings.Enabled {
		return nil
	}

	// Send welcome message
	if settings.ChannelID != nil {
		msg, err := b.buildWelcomeMessage(evt.ServerID, userID)
		if err == nil {
			b.sendBotMessage(*settings.ChannelID, msg)
		}
	}

	// Assign auto roles
	for _, roleID := range settings.AutoRoles {
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO member_roles (server_id, user_id, role_id) VALUES ($1, $2, $3::uuid) ON CONFLICT DO NOTHING`,
			evt.ServerID, userID, roleID)
		if err != nil {
			b.logger.Error("auto-role assign failed", zap.Error(err), zap.String("role", roleID))
		}
	}

	b.logger.Info("welcome sent",
		zap.String("server", evt.ServerID),
		zap.String("user", userID),
	)
	return nil
}

func (b *WelcomeBot) onMemberLeave(evt events.Event) error {
	if evt.ServerID == "" {
		return nil
	}

	var leaveEnabled bool
	var leaveChannelID *string
	var leaveMessage string

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT leave_enabled, leave_channel_id, leave_message
		 FROM welcome_settings WHERE server_id = $1`, evt.ServerID).Scan(
		&leaveEnabled, &leaveChannelID, &leaveMessage,
	)
	if err != nil || !leaveEnabled || leaveChannelID == nil {
		return nil
	}

	username, _ := evt.Data["username"].(string)
	if username == "" {
		username = "Unknown User"
	}

	msg := strings.ReplaceAll(leaveMessage, "{{username}}", username)
	msg = strings.ReplaceAll(msg, "{{user}}", fmt.Sprintf("<@%s>", evt.UserID))

	b.sendBotMessage(*leaveChannelID, msg)
	return nil
}

// ── Helpers ─────────────────────────────────────────────────────────────────

func (b *WelcomeBot) buildWelcomeMessage(serverID, userID string) (string, error) {
	var message string
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT welcome_message FROM welcome_settings WHERE server_id = $1`, serverID).Scan(&message)
	if err != nil {
		return "", err
	}

	// Get user data
	var username string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COALESCE(display_name, username) FROM users WHERE id = $1`, userID).Scan(&username)

	// Get server data
	var serverName string
	var memberCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT name FROM servers WHERE id = $1`, serverID).Scan(&serverName)
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM server_members WHERE server_id = $1`, serverID).Scan(&memberCount)

	// Replace variables
	message = strings.ReplaceAll(message, "{{user}}", fmt.Sprintf("<@%s>", userID))
	message = strings.ReplaceAll(message, "{{username}}", username)
	message = strings.ReplaceAll(message, "{{server}}", serverName)
	message = strings.ReplaceAll(message, "{{memberCount}}", fmt.Sprintf("%d", memberCount))

	return message, nil
}

func (b *WelcomeBot) sendBotMessage(channelID, content string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := b.ctx.DB.Exec(ctx,
		`INSERT INTO messages (channel_id, content, type, created_at)
		 VALUES ($1, $2, 'system', $3)`,
		channelID, content, time.Now())
	if err != nil {
		b.logger.Error("failed to send bot message", zap.Error(err), zap.String("channel", channelID))
	}
}
