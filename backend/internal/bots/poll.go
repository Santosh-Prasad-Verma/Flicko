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

// PollBot creates and manages polls with reactions.
type PollBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewPollBot(router *commands.Router) *PollBot {
	return &PollBot{router: router}
}

func (b *PollBot) Name() string { return "poll" }

func (b *PollBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.poll")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.ButtonClick, "poll-vote", b.onButtonClick)

	b.logger.Info("poll bot registered")
	return nil
}

func (b *PollBot) Shutdown() error { return nil }

func (b *PollBot) registerCommands() {
	// /poll create <question> <options...>
	b.router.Register(commands.CommandDefinition{
		Name:        "poll",
		Description: "Create and manage polls",
		BotName:     "poll",
		Options: []commands.CommandOption{
			{Name: "action", Description: "create, close, results", Type: 3, Required: true},
			{Name: "question", Description: "Poll question", Type: 3, Required: false},
			{Name: "options", Description: "Options separated by | (e.g. Yes|No|Maybe)", Type: 3, Required: false},
			{Name: "duration", Description: "Duration (e.g. 1h, 1d)", Type: 3, Required: false},
			{Name: "multi_vote", Description: "Allow multiple votes", Type: 5, Required: false},
		},
	}, b.handlePoll)

	// /quickpoll <question>
	b.router.Register(commands.CommandDefinition{
		Name:        "quickpoll",
		Description: "Quick yes/no poll",
		BotName:     "poll",
		Options: []commands.CommandOption{
			{Name: "question", Description: "Poll question", Type: 3, Required: true},
		},
	}, b.handleQuickPoll)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *PollBot) handlePoll(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "create":
		return b.createPoll(ctx)
	case "close":
		return b.closePoll(ctx)
	case "results":
		return b.pollResults(ctx)
	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: create, close, results", Ephemeral: true}, nil
	}
}

func (b *PollBot) createPoll(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	question, _ := ctx.Options["question"].(string)
	optionsStr, _ := ctx.Options["options"].(string)
	durationStr, _ := ctx.Options["duration"].(string)
	multiVote, _ := ctx.Options["multi_vote"].(bool)

	if question == "" {
		return &commands.CommandResponse{Content: "❌ Please provide a question.", Ephemeral: true}, nil
	}

	options := strings.Split(optionsStr, "|")
	for i := range options {
		options[i] = strings.TrimSpace(options[i])
	}
	var cleanOptions []string
	for _, o := range options {
		if o != "" {
			cleanOptions = append(cleanOptions, o)
		}
	}
	if len(cleanOptions) < 2 {
		return &commands.CommandResponse{Content: "❌ Provide at least 2 options separated by |", Ephemeral: true}, nil
	}
	if len(cleanOptions) > 10 {
		return &commands.CommandResponse{Content: "❌ Maximum 10 options.", Ephemeral: true}, nil
	}

	var (
		expiresAt     *time.Time
		durationHours *int
	)
	if durationStr != "" {
		if d, err := ParseDuration(durationStr); err == nil {
			t := time.Now().Add(d)
			expiresAt = &t
			h := int(d.Hours())
			if h < 1 {
				h = 1
			}
			durationHours = &h
		}
	}

	// CRIT-4: the canonical polls schema (supabase/migrations/040_polls.sql)
	// requires message_id NOT NULL. We insert a placeholder system message
	// in the channel first, then attach the poll to it.
	systemID, _ := EnsureSystemUser(reqCtx, b.ctx)
	var msgID string
	if systemID != "" {
		_ = b.ctx.DB.QueryRow(reqCtx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, $2, $3, 'system', NOW())
			 RETURNING id`,
			ctx.ChannelID, systemID, "📊 "+question).Scan(&msgID)
	} else {
		_ = b.ctx.DB.QueryRow(reqCtx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, NULL, $2, 'system', NOW())
			 RETURNING id`,
			ctx.ChannelID, "📊 "+question).Scan(&msgID)
	}

	if msgID == "" {
		return &commands.CommandResponse{
			Content:   "❌ Could not anchor poll to a message. Try again.",
			Ephemeral: true,
		}, nil
	}

	var pollID string
	err := b.ctx.DB.QueryRow(reqCtx,
		`INSERT INTO polls (message_id, channel_id, creator_id, question, allow_multiselect, duration_hours, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id`,
		msgID, ctx.ChannelID, ctx.UserID, question, multiVote, durationHours, expiresAt).Scan(&pollID)
	if err != nil {
		return nil, fmt.Errorf("create poll failed: %w", err)
	}

	numberEmojis := []string{"1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"}
	var optionLines []string
	for i, opt := range cleanOptions {
		emoji := numberEmojis[i]
		if _, err := b.ctx.DB.Exec(reqCtx,
			`INSERT INTO poll_options (poll_id, label, emoji, position)
			 VALUES ($1, $2, $3, $4)`,
			pollID, opt, emoji, i); err != nil {
			b.logger.Error("poll option insert failed", zap.Error(err))
		}
		optionLines = append(optionLines, fmt.Sprintf("%s %s", emoji, opt))
	}

	desc := strings.Join(optionLines, "\n")
	footer := fmt.Sprintf("Poll ID: %s", pollID[:8])
	if multiVote {
		footer += " • Multi-vote"
	}
	if expiresAt != nil {
		footer += fmt.Sprintf(" • Ends: %s", expiresAt.Format("Jan 2 15:04"))
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       fmt.Sprintf("📊 %s", question),
			Description: desc,
			Color:       "#5865F2",
			Footer:      footer,
		},
	}, nil
}

func (b *PollBot) handleQuickPoll(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	question, _ := ctx.Options["question"].(string)
	if question == "" {
		return &commands.CommandResponse{Content: "❌ Provide a question.", Ephemeral: true}, nil
	}

	systemID, _ := EnsureSystemUser(reqCtx, b.ctx)
	var msgID string
	if systemID != "" {
		_ = b.ctx.DB.QueryRow(reqCtx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, $2, $3, 'system', NOW())
			 RETURNING id`,
			ctx.ChannelID, systemID, "📊 "+question).Scan(&msgID)
	} else {
		_ = b.ctx.DB.QueryRow(reqCtx,
			`INSERT INTO messages (channel_id, author_id, content, type, created_at)
			 VALUES ($1, NULL, $2, 'system', NOW())
			 RETURNING id`,
			ctx.ChannelID, "📊 "+question).Scan(&msgID)
	}
	if msgID == "" {
		return &commands.CommandResponse{
			Content:   "❌ Could not anchor poll to a message. Try again.",
			Ephemeral: true,
		}, nil
	}

	var pollID string
	if err := b.ctx.DB.QueryRow(reqCtx,
		`INSERT INTO polls (message_id, channel_id, creator_id, question, allow_multiselect)
		 VALUES ($1, $2, $3, $4, false)
		 RETURNING id`,
		msgID, ctx.ChannelID, ctx.UserID, question).Scan(&pollID); err != nil {
		return nil, err
	}

	for i, opt := range []struct{ label, emoji string }{{"Yes", "👍"}, {"No", "👎"}} {
		_, _ = b.ctx.DB.Exec(reqCtx,
			`INSERT INTO poll_options (poll_id, label, emoji, position) VALUES ($1, $2, $3, $4)`,
			pollID, opt.label, opt.emoji, i)
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       fmt.Sprintf("📊 %s", question),
			Description: "👍 Yes\n👎 No",
			Color:       "#5865F2",
			Footer:      fmt.Sprintf("Quick Poll • Poll ID: %s", pollID[:8]),
		},
	}, nil
}

func (b *PollBot) closePoll(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	// "Close" in this schema means stamping ended_at. Owner check is server
	// owner OR the original creator.
	var pollID, question string
	err := b.ctx.DB.QueryRow(reqCtx,
		`UPDATE polls
		 SET ended_at = NOW()
		 WHERE channel_id = $1
		   AND ended_at IS NULL
		   AND (creator_id = $2 OR EXISTS(
		       SELECT 1 FROM channels c
		       JOIN servers s ON s.id = c.server_id
		       WHERE c.id = $1 AND s.owner_id = $2
		   ))
		 RETURNING id, question`,
		ctx.ChannelID, ctx.UserID).Scan(&pollID, &question)
	if err != nil {
		return &commands.CommandResponse{Content: "❌ No active poll found that you can close.", Ephemeral: true}, nil
	}

	return b.showResults(pollID, question, true)
}

func (b *PollBot) pollResults(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	var pollID, question string
	err := b.ctx.DB.QueryRow(reqCtx,
		`SELECT id, question FROM polls
		 WHERE channel_id = $1
		 ORDER BY created_at DESC LIMIT 1`,
		ctx.ChannelID).Scan(&pollID, &question)
	if err != nil {
		return &commands.CommandResponse{Content: "❌ No poll found in this channel.", Ephemeral: true}, nil
	}

	return b.showResults(pollID, question, false)
}

func (b *PollBot) showResults(pollID, question string, isFinal bool) (*commands.CommandResponse, error) {
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT po.label, po.emoji, COUNT(pv.id) as vote_count
		 FROM poll_options po
		 LEFT JOIN poll_votes pv ON pv.option_id = po.id
		 WHERE po.poll_id = $1
		 GROUP BY po.id, po.label, po.emoji, po.position
		 ORDER BY po.position`,
		pollID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var totalVotes int
	type result struct {
		label, emoji string
		count        int
	}
	var results []result

	for rows.Next() {
		var r result
		if err := rows.Scan(&r.label, &r.emoji, &r.count); err != nil {
			continue
		}
		totalVotes += r.count
		results = append(results, r)
	}

	var lines []string
	for _, r := range results {
		pct := 0.0
		if totalVotes > 0 {
			pct = float64(r.count) / float64(totalVotes) * 100
		}
		bar := progressBar(pct)
		lines = append(lines, fmt.Sprintf("%s %s — %d votes (%.0f%%)\n%s", r.emoji, r.label, r.count, pct, bar))
	}

	title := fmt.Sprintf("📊 %s", question)
	if isFinal {
		title = fmt.Sprintf("📊 [CLOSED] %s", question)
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       title,
			Description: strings.Join(lines, "\n\n"),
			Color:       "#FFD700",
			Footer:      fmt.Sprintf("Total votes: %d", totalVotes),
		},
	}, nil
}

// ── Button Vote Handler ─────────────────────────────────────────────────────

func (b *PollBot) onButtonClick(evt events.Event) error {
	customID, _ := evt.Data["custom_id"].(string)
	if !strings.HasPrefix(customID, "poll_vote_") {
		return nil
	}

	optionID := strings.TrimPrefix(customID, "poll_vote_")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Active = not yet ended (ended_at IS NULL) AND not past expires_at.
	var pollID string
	var allowMulti bool
	err := b.ctx.DB.QueryRow(ctx,
		`SELECT p.id, p.allow_multiselect FROM polls p
		 JOIN poll_options po ON po.poll_id = p.id
		 WHERE po.id = $1
		   AND p.ended_at IS NULL
		   AND (p.expires_at IS NULL OR p.expires_at > NOW())`,
		optionID).Scan(&pollID, &allowMulti)
	if err != nil {
		return nil // poll not active or option not found
	}

	if !allowMulti {
		// Remove existing vote
		_, _ = b.ctx.DB.Exec(ctx,
			`DELETE FROM poll_votes WHERE user_id = $1
			 AND option_id IN (SELECT id FROM poll_options WHERE poll_id = $2)`,
			evt.UserID, pollID)
	}

	// Cast vote
	if _, err := b.ctx.DB.Exec(ctx,
		`INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES ($1, $2, $3)
		 ON CONFLICT DO NOTHING`,
		pollID, optionID, evt.UserID); err != nil {
		b.logger.Error("vote insert failed", zap.Error(err))
	}

	return nil
}

// ── Helpers ─────────────────────────────────────────────────────────────────

func progressBar(percentage float64) string {
	filled := int(percentage / 10)
	empty := 10 - filled
	if filled < 0 {
		filled = 0
	}
	if empty < 0 {
		empty = 0
	}
	return strings.Repeat("█", filled) + strings.Repeat("░", empty)
}
