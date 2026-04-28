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

// TicketBot manages support ticket creation, claiming, and closing.
type TicketBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
	cancel context.CancelFunc
}

func NewTicketBot(router *commands.Router) *TicketBot {
	return &TicketBot{router: router}
}

func (b *TicketBot) Name() string { return "ticket" }

func (b *TicketBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.ticket")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.ButtonClick, "ticket-button", b.onButtonClick)

	// Start auto-close ticker
	bgCtx, cancel := context.WithCancel(context.Background())
	b.cancel = cancel
	go b.autoCloseLoop(bgCtx)

	b.logger.Info("ticket bot registered")
	return nil
}

func (b *TicketBot) Shutdown() error {
	if b.cancel != nil {
		b.cancel()
	}
	return nil
}

func (b *TicketBot) registerCommands() {
	// /ticket new [subject] [category]
	b.router.Register(commands.CommandDefinition{
		Name:        "ticket",
		Description: "Manage support tickets",
		BotName:     "ticket",
		Options: []commands.CommandOption{
			{Name: "action", Description: "new, close, add, remove, claim, unclaim, rename, priority, panels, transcript, stats", Type: 3, Required: true},
			{Name: "subject", Description: "Ticket subject", Type: 3, Required: false},
			{Name: "category", Description: "Ticket category", Type: 3, Required: false},
			{Name: "user", Description: "User to add/remove", Type: 6, Required: false},
			{Name: "priority", Description: "low, normal, high, urgent", Type: 3, Required: false},
			{Name: "channel", Description: "Channel for ticket panel", Type: 7, Required: false},
		},
	}, b.handleTicket)

	// /ticket-config <action>
	b.router.Register(commands.CommandDefinition{
		Name:        "ticket-config",
		Description: "Configure ticket system",
		BotName:     "ticket",
		Options: []commands.CommandOption{
			{Name: "action", Description: "enable, disable, status, staff-role, log-channel, welcome-msg, max-tickets, auto-close", Type: 3, Required: true},
			{Name: "role", Description: "Staff role", Type: 8, Required: false},
			{Name: "channel", Description: "Log channel", Type: 7, Required: false},
			{Name: "value", Description: "Value for setting", Type: 3, Required: false},
		},
	}, b.handleTicketConfig)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *TicketBot) handleTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "new":
		return b.createTicket(ctx)
	case "close":
		return b.closeTicket(ctx)
	case "add":
		return b.addUserToTicket(ctx)
	case "remove":
		return b.removeUserFromTicket(ctx)
	case "claim":
		return b.claimTicket(ctx)
	case "unclaim":
		return b.unclaimTicket(ctx)
	case "rename":
		return b.renameTicket(ctx)
	case "priority":
		return b.setTicketPriority(ctx)
	case "panels":
		return b.createPanel(ctx)
	case "transcript":
		return b.generateTranscript(ctx)
	case "stats":
		return b.ticketStats(ctx)
	default:
		return &commands.CommandResponse{
			Content:   "❌ Unknown action. Use: new, close, add, remove, claim, unclaim, rename, priority, panels, transcript, stats",
			Ephemeral: true,
		}, nil
	}
}

func (b *TicketBot) createTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	subject, _ := ctx.Options["subject"].(string)
	category, _ := ctx.Options["category"].(string)
	if category == "" {
		category = "general"
	}
	if subject == "" {
		subject = "Support Request"
	}

	// Check max open tickets
	var maxTickets int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT max_open_tickets FROM ticket_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&maxTickets)
	if maxTickets == 0 {
		maxTickets = 3
	}

	var openCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM tickets WHERE server_id = $1 AND creator_id = $2 AND status = 'open'`,
		ctx.ServerID, ctx.UserID).Scan(&openCount)
	if openCount >= maxTickets {
		return &commands.CommandResponse{
			Content:   fmt.Sprintf("❌ You already have %d open tickets (max: %d).", openCount, maxTickets),
			Ephemeral: true,
		}, nil
	}

	// Get next ticket number
	var ticketNumber int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COALESCE(MAX(ticket_number), 0) + 1 FROM tickets WHERE server_id = $1`,
		ctx.ServerID).Scan(&ticketNumber)

	// Get prefix
	var prefix string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT ticket_prefix FROM ticket_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&prefix)
	if prefix == "" {
		prefix = "ticket"
	}

	channelName := fmt.Sprintf("%s-%04d", prefix, ticketNumber)

	// Create ticket channel
	var channelID string
	err := b.ctx.DB.QueryRow(context.Background(),
		`INSERT INTO channels (server_id, name, type, created_at)
		 VALUES ($1, $2, 'text', NOW())
		 RETURNING id`,
		ctx.ServerID, channelName).Scan(&channelID)
	if err != nil {
		return nil, fmt.Errorf("create ticket channel failed: %w", err)
	}

	// Create ticket record
	var ticketID string
	err = b.ctx.DB.QueryRow(context.Background(),
		`INSERT INTO tickets (server_id, channel_id, creator_id, ticket_number, category, subject, status, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, 'open', NOW())
		 RETURNING id`,
		ctx.ServerID, channelID, ctx.UserID, ticketNumber, category, subject).Scan(&ticketID)
	if err != nil {
		return nil, fmt.Errorf("create ticket failed: %w", err)
	}

	// Send welcome message
	var welcomeMsg string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT welcome_message FROM ticket_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&welcomeMsg)
	if welcomeMsg == "" {
		welcomeMsg = "A staff member will be with you shortly. Please describe your issue."
	}

	b.sendBotMessage(channelID, fmt.Sprintf("🎫 **Ticket #%d** — %s\n\n%s", ticketNumber, subject, welcomeMsg))

	return &commands.CommandResponse{
		Content: fmt.Sprintf("✅ Ticket **#%d** created! Head to <#%s>.", ticketNumber, channelID),
	}, nil
}

func (b *TicketBot) closeTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	// Find ticket by current channel
	var ticketID string
	var ticketNumber int
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT id, ticket_number FROM tickets WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID).Scan(&ticketID, &ticketNumber)
	if err != nil {
		return &commands.CommandResponse{Content: "❌ This channel is not an open ticket.", Ephemeral: true}, nil
	}

	// Close the ticket
	_, err = b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET status = 'closed', closed_by = $2, closed_at = NOW() WHERE id = $1`,
		ticketID, ctx.UserID)
	if err != nil {
		return nil, err
	}

	// Get close message
	var closeMsg string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT close_message FROM ticket_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&closeMsg)
	if closeMsg == "" {
		closeMsg = "This ticket has been closed. Thank you!"
	}

	b.sendBotMessage(ctx.ChannelID, fmt.Sprintf("🔒 %s", closeMsg))

	// Fetch messages for transcript before fully closing and hiding
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT u.username, m.content, m.created_at
		 FROM messages m
		 LEFT JOIN users u ON m.user_id = u.id
		 WHERE m.channel_id = $1
		 ORDER BY m.created_at ASC`,
		ctx.ChannelID)
	if err == nil {
		var lines []string
		lines = append(lines, fmt.Sprintf("Auto-Transcript for Ticket #%d", ticketNumber))
		lines = append(lines, "========================================")

		for rows.Next() {
			var username *string
			var content string
			var createdAt time.Time
			if err := rows.Scan(&username, &content, &createdAt); err == nil {
				name := "System"
				if username != nil {
					name = *username
				}
				lines = append(lines, fmt.Sprintf("[%s] %s: %s", createdAt.Format("2006-01-02 15:04:05"), name, content))
			}
		}
		rows.Close()

		transcriptText := strings.Join(lines, "\n")
		if len(transcriptText) > 1900 {
			transcriptText = transcriptText[:1900] + "\n... (truncated)"
		}

		// Send transcript to log channel specifically if standard logging works
		var logChannelID *string
		b.ctx.DB.QueryRow(context.Background(),
			`SELECT log_channel_id FROM ticket_settings WHERE server_id = $1`,
			ctx.ServerID).Scan(&logChannelID)
		if logChannelID != nil {
			b.sendBotMessage(*logChannelID, fmt.Sprintf("📄 **Transcript for closed ticket #%d:**\n```text\n%s\n```", ticketNumber, transcriptText))
		}
	}

	// Log to ticket log channel
	b.logTicketAction(ctx.ServerID, ticketNumber, ctx.UserID, "closed")

	return &commands.CommandResponse{Content: fmt.Sprintf("🔒 Ticket #%d has been closed.", ticketNumber)}, nil
}

func (b *TicketBot) addUserToTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	targetID, _ := ctx.Options["user"].(string)
	if targetID == "" {
		return &commands.CommandResponse{Content: "❌ Please specify a user.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET added_users = array_append(COALESCE(added_users, '{}'), $2::uuid)
		 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, targetID)
	if err != nil {
		return nil, err
	}

	return &commands.CommandResponse{Content: fmt.Sprintf("✅ <@%s> has been added to this ticket.", targetID)}, nil
}

func (b *TicketBot) removeUserFromTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	targetID, _ := ctx.Options["user"].(string)
	if targetID == "" {
		return &commands.CommandResponse{Content: "❌ Please specify a user.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET added_users = array_remove(COALESCE(added_users, '{}'), $2::uuid)
		 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, targetID)
	if err != nil {
		return nil, err
	}

	return &commands.CommandResponse{Content: fmt.Sprintf("✅ <@%s> has been removed from this ticket.", targetID)}, nil
}

func (b *TicketBot) claimTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET added_users = array_append(COALESCE(added_users, '{}'), $2::uuid)
		 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, ctx.UserID)
	if err != nil {
		return nil, err
	}

	username := b.getUsername(ctx.UserID)
	b.sendBotMessage(ctx.ChannelID, fmt.Sprintf("👤 **%s** has claimed this ticket.", username))

	return &commands.CommandResponse{Content: "✅ You have claimed this ticket."}, nil
}

func (b *TicketBot) unclaimTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET added_users = array_remove(COALESCE(added_users, '{}'), $2::uuid)
		 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, ctx.UserID)
	if err != nil {
		return nil, err
	}

	return &commands.CommandResponse{Content: "✅ You have unclaimed this ticket."}, nil
}

func (b *TicketBot) renameTicket(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	subject, _ := ctx.Options["subject"].(string)
	if subject == "" {
		return &commands.CommandResponse{Content: "❌ Provide a new subject.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET subject = $2 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, subject)
	if err != nil {
		return nil, err
	}

	return &commands.CommandResponse{Content: fmt.Sprintf("✅ Ticket subject updated to: %s", subject)}, nil
}

func (b *TicketBot) setTicketPriority(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	priority, _ := ctx.Options["priority"].(string)
	if priority == "" {
		return &commands.CommandResponse{Content: "❌ Provide a priority: low, normal, high, urgent", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE tickets SET priority = $2 WHERE channel_id = $1 AND status = 'open'`,
		ctx.ChannelID, priority)
	if err != nil {
		return nil, err
	}

	emoji := map[string]string{
		"low": "🟢", "normal": "🔵", "high": "🟠", "urgent": "🔴",
	}

	return &commands.CommandResponse{
		Content: fmt.Sprintf("%s Ticket priority set to **%s**.", emoji[priority], priority),
	}, nil
}

func (b *TicketBot) createPanel(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	channelID, _ := ctx.Options["channel"].(string)
	if channelID == "" {
		return &commands.CommandResponse{Content: "❌ Please specify a channel for the panel.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`INSERT INTO ticket_panels (server_id, channel_id, title, description, button_label)
		 VALUES ($1, $2, '🎫 Support Tickets', 'Click the button below to create a support ticket.', 'Create Ticket')`,
		ctx.ServerID, channelID)
	if err != nil {
		return nil, err
	}

	// Send panel message
	b.sendBotMessage(channelID, "🎫 **Support Tickets**\nClick the button below to create a support ticket.\n\n`[Create Ticket]`")

	return &commands.CommandResponse{Content: fmt.Sprintf("✅ Ticket panel created in <#%s>.", channelID)}, nil
}

func (b *TicketBot) generateTranscript(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	// Find ticket by current channel
	var ticketID string
	var ticketNumber int
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT id, ticket_number FROM tickets WHERE channel_id = $1`,
		ctx.ChannelID).Scan(&ticketID, &ticketNumber)
	if err != nil {
		return &commands.CommandResponse{Content: "❌ This channel is not a ticket.", Ephemeral: true}, nil
	}

	// Fetch messages for transcript
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT u.username, m.content, m.created_at
		 FROM messages m
		 LEFT JOIN users u ON m.user_id = u.id
		 WHERE m.channel_id = $1
		 ORDER BY m.created_at ASC`,
		ctx.ChannelID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch transcript messages: %w", err)
	}
	defer rows.Close()

	var lines []string
	lines = append(lines, fmt.Sprintf("Transcript for Ticket #%d", ticketNumber))
	lines = append(lines, "========================================")

	for rows.Next() {
		var username *string
		var content string
		var createdAt time.Time
		if err := rows.Scan(&username, &content, &createdAt); err == nil {
			name := "System"
			if username != nil {
				name = *username
			}
			lines = append(lines, fmt.Sprintf("[%s] %s: %s", createdAt.Format("2006-01-02 15:04:05"), name, content))
		}
	}

	transcriptText := strings.Join(lines, "\n")
	if len(transcriptText) > 1900 {
		transcriptText = transcriptText[:1900] + "\n... (truncated)"
	}

	// Log it if needed
	b.logTicketAction(ctx.ServerID, ticketNumber, ctx.UserID, "generated a transcript")

	return &commands.CommandResponse{
		Content: fmt.Sprintf("✅ **Transcript Generated**\n```text\n%s\n```", transcriptText),
	}, nil
}

func (b *TicketBot) ticketStats(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	var total, open, closed int
	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT 
			COUNT(*) as total,
			COUNT(*) FILTER (WHERE status = 'open') as open_tickets,
			COUNT(*) FILTER (WHERE status = 'closed') as closed_tickets
		 FROM tickets WHERE server_id = $1`, ctx.ServerID).Scan(&total, &open, &closed)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch ticket stats: %w", err)
	}

	statsText := fmt.Sprintf("📊 **Ticket Statistics**\n\n"+
		"**Total Tickets:** %d\n"+
		"**Open Tickets:** %d\n"+
		"**Closed Tickets:** %d", total, open, closed)

	return &commands.CommandResponse{Content: statsText}, nil
}

// ── Ticket Config ───────────────────────────────────────────────────────────

func (b *TicketBot) handleTicketConfig(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "enable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO ticket_settings (server_id, enabled) VALUES ($1, true)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, updated_at = now()`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "✅ Ticket system enabled!"}, nil

	case "disable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET enabled = false, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "🔴 Ticket system disabled."}, nil

	case "status":
		return b.getTicketStatus(ctx.ServerID)

	case "staff-role":
		roleID, _ := ctx.Options["role"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET staff_role_ids = array_append(
				COALESCE(staff_role_ids, '{}'), $2::uuid
			), updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, roleID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Staff role added: <@&%s>", roleID)}, nil

	case "log-channel":
		channelID, _ := ctx.Options["channel"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET log_channel_id = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Ticket logs will be sent to <#%s>.", channelID)}, nil

	case "welcome-msg":
		value, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET welcome_message = $2, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "✅ Ticket welcome message updated."}, nil

	case "max-tickets":
		value, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET max_open_tickets = $2::integer, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Max open tickets set to %s.", value)}, nil

	case "auto-close":
		value, _ := ctx.Options["value"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE ticket_settings SET auto_close_hours = $2::integer, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID, value)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Auto-close set to %s hours.", value)}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action.", Ephemeral: true}, nil
	}
}

func (b *TicketBot) getTicketStatus(serverID string) (*commands.CommandResponse, error) {
	var s struct {
		Enabled    bool
		MaxTickets int
		AutoClose  int
		WelcomeMsg string
		StaffRoles []string
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, max_open_tickets, auto_close_hours, welcome_message, staff_role_ids
		 FROM ticket_settings WHERE server_id = $1`, serverID).Scan(
		&s.Enabled, &s.MaxTickets, &s.AutoClose, &s.WelcomeMsg, &s.StaffRoles,
	)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ Ticket system is not configured. Use `/ticket-config enable`."}, nil
	}

	var openCount, closedCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM tickets WHERE server_id = $1 AND status = 'open'`, serverID).Scan(&openCount)
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM tickets WHERE server_id = $1 AND status = 'closed'`, serverID).Scan(&closedCount)

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: "🎫 Ticket System Status",
			Color: "#5865F2",
			Fields: []commands.EmbedField{
				{Name: "Status", Value: boolEmoji(s.Enabled), Inline: true},
				{Name: "Open Tickets", Value: fmt.Sprintf("%d", openCount), Inline: true},
				{Name: "Closed Tickets", Value: fmt.Sprintf("%d", closedCount), Inline: true},
				{Name: "Max Per User", Value: fmt.Sprintf("%d", s.MaxTickets), Inline: true},
				{Name: "Auto-Close", Value: fmt.Sprintf("%dh of inactivity", s.AutoClose), Inline: true},
				{Name: "Staff Roles", Value: fmt.Sprintf("%d configured", len(s.StaffRoles)), Inline: true},
			},
		},
	}, nil
}

// ── Button Handler ──────────────────────────────────────────────────────────

func (b *TicketBot) onButtonClick(evt events.Event) error {
	customID, _ := evt.Data["custom_id"].(string)
	if !strings.HasPrefix(customID, "ticket_") {
		return nil
	}

	// Create a new ticket via button
	_, err := b.createTicket(commands.CommandContext{
		ServerID:  evt.ServerID,
		ChannelID: evt.ChannelID,
		UserID:    evt.UserID,
		Options:   map[string]interface{}{"subject": "Button Support Request"},
	})
	return err
}

// ── Auto Close ──────────────────────────────────────────────────────────────

func (b *TicketBot) autoCloseLoop(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			b.processAutoClose()
		}
	}
}

func (b *TicketBot) processAutoClose() {
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT t.id, t.channel_id, t.ticket_number, t.server_id
		 FROM tickets t
		 JOIN ticket_settings ts ON ts.server_id = t.server_id
		 WHERE t.status = 'open'
		   AND ts.auto_close_hours > 0
		   AND t.last_activity_at < NOW() - (ts.auto_close_hours || ' hours')::interval`)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var ticketID, channelID, serverID string
		var ticketNumber int
		if err := rows.Scan(&ticketID, &channelID, &ticketNumber, &serverID); err != nil {
			continue
		}

		b.ctx.DB.Exec(context.Background(),
			`UPDATE tickets SET status = 'closed', closed_at = NOW() WHERE id = $1`, ticketID)

		b.sendBotMessage(channelID, "🔒 This ticket has been automatically closed due to inactivity.")
		b.logTicketAction(serverID, ticketNumber, "", "auto-closed")
	}
}

// ── Helpers ─────────────────────────────────────────────────────────────────

func (b *TicketBot) sendBotMessage(channelID, content string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := b.ctx.DB.Exec(ctx,
		`INSERT INTO messages (channel_id, content, type, created_at)
		 VALUES ($1, $2, 'system', $3)`,
		channelID, content, time.Now())
	if err != nil {
		b.logger.Error("failed to send ticket bot message", zap.Error(err))
	}
}

func (b *TicketBot) logTicketAction(serverID string, ticketNumber int, userID, action string) {
	var logChannelID *string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT log_channel_id FROM ticket_settings WHERE server_id = $1`,
		serverID).Scan(&logChannelID)
	if logChannelID != nil {
		username := "System"
		if userID != "" {
			username = b.getUsername(userID)
		}
		b.sendBotMessage(*logChannelID,
			fmt.Sprintf("📋 Ticket #%d %s by %s", ticketNumber, action, username))
	}
}

func (b *TicketBot) getUsername(userID string) string {
	var username string
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COALESCE(display_name, username) FROM users WHERE id = $1`, userID).Scan(&username)
	if username == "" {
		return userID[:8]
	}
	return username
}
