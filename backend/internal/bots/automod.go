package bots

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// AutoModBot evaluates messages against server auto-moderation rules.
type AutoModBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewAutoModBot(router *commands.Router) *AutoModBot {
	return &AutoModBot{router: router}
}

func (b *AutoModBot) Name() string { return "automod" }

func (b *AutoModBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.automod")

	b.registerCommands()

	bctx.EventBus.Subscribe(events.MessageCreate, "automod-filter", b.onMessageCreate)

	b.logger.Info("automod bot registered")
	return nil
}

func (b *AutoModBot) Shutdown() error { return nil }

func (b *AutoModBot) registerCommands() {
	// /automod enable
	b.router.Register(commands.CommandDefinition{
		Name:        "automod",
		Description: "Configure auto-moderation",
		BotName:     "automod",
		Options: []commands.CommandOption{
			{Name: "action", Description: "enable, disable, status, or configure", Type: 3, Required: true},
			{Name: "filter", Description: "Filter name (invites, links, caps, emoji, mentions, duplicates)", Type: 3, Required: false},
			{Name: "value", Description: "Value for the setting", Type: 3, Required: false},
		},
	}, b.handleAutomod)

	// /automod-exempt <role|channel|user> <id>
	b.router.Register(commands.CommandDefinition{
		Name:        "automod-exempt",
		Description: "Add an exemption to auto-moderation",
		BotName:     "automod",
		Options: []commands.CommandOption{
			{Name: "type", Description: "role, channel, or user", Type: 3, Required: true},
			{Name: "target", Description: "The role/channel/user to exempt", Type: 3, Required: true},
			{Name: "remove", Description: "Remove the exemption instead", Type: 5, Required: false},
		},
	}, b.handleAutomodExempt)
}

func (b *AutoModBot) handleAutomod(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{
			Content:   "❌ You need the Manage Server permission to configure AutoMod.",
			Ephemeral: true,
		}, nil
	}

	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "enable":
		_, err := b.ctx.DB.Exec(reqCtx,
			`INSERT INTO automod_settings (server_id, enabled) VALUES ($1, true)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, updated_at = now()`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "✅ Auto-moderation enabled."}, nil

	case "disable":
		_, err := b.ctx.DB.Exec(reqCtx,
			`UPDATE automod_settings SET enabled = false, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "🔴 Auto-moderation disabled."}, nil

	case "status":
		return b.getStatus(ctx.ServerID)

	case "configure":
		filter, _ := ctx.Options["filter"].(string)
		value, _ := ctx.Options["value"].(string)
		return b.configureFilter(ctx.ServerID, filter, value)

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: enable, disable, status, configure", Ephemeral: true}, nil
	}
}

func (b *AutoModBot) handleAutomodExempt(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{
			Content:   "❌ You need the Manage Server permission to manage AutoMod exemptions.",
			Ephemeral: true,
		}, nil
	}

	exemptType, _ := ctx.Options["type"].(string)
	target, _ := ctx.Options["target"].(string)
	remove, _ := ctx.Options["remove"].(bool)

	var query string
	switch {
	case exemptType == "role" && !remove:
		query = `UPDATE automod_settings SET exempt_roles = array_append(exempt_roles, $2::uuid) WHERE server_id = $1`
	case exemptType == "role" && remove:
		query = `UPDATE automod_settings SET exempt_roles = array_remove(exempt_roles, $2::uuid) WHERE server_id = $1`
	case exemptType == "channel" && !remove:
		query = `UPDATE automod_settings SET exempt_channels = array_append(exempt_channels, $2::uuid) WHERE server_id = $1`
	case exemptType == "channel" && remove:
		query = `UPDATE automod_settings SET exempt_channels = array_remove(exempt_channels, $2::uuid) WHERE server_id = $1`
	case exemptType == "user" && !remove:
		query = `UPDATE automod_settings SET exempt_users = array_append(exempt_users, $2::uuid) WHERE server_id = $1`
	case exemptType == "user" && remove:
		query = `UPDATE automod_settings SET exempt_users = array_remove(exempt_users, $2::uuid) WHERE server_id = $1`
	default:
		return &commands.CommandResponse{Content: "❌ Type must be: role, channel, or user", Ephemeral: true}, nil
	}

	if _, err := b.ctx.DB.Exec(reqCtx, query, ctx.ServerID, target); err != nil {
		return nil, err
	}

	actionWord := "added"
	if remove {
		actionWord = "removed"
	}
	return &commands.CommandResponse{Content: fmt.Sprintf("✅ Exemption %s for %s %s.", actionWord, exemptType, target)}, nil
}

func (b *AutoModBot) getStatus(serverID string) (*commands.CommandResponse, error) {
	var settings struct {
		Enabled          bool
		InviteFilter     bool
		LinkFilter       bool
		CapsFilter       bool
		CapsThreshold    int
		EmojiFilter      bool
		EmojiThreshold   int
		MentionFilter    bool
		MentionThreshold int
		DuplicateFilter  bool
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, invite_filter, link_filter, caps_filter, caps_threshold,
				emoji_filter, emoji_threshold, mention_filter, mention_threshold, duplicate_filter
		 FROM automod_settings WHERE server_id = $1`, serverID).Scan(
		&settings.Enabled, &settings.InviteFilter, &settings.LinkFilter,
		&settings.CapsFilter, &settings.CapsThreshold, &settings.EmojiFilter,
		&settings.EmojiThreshold, &settings.MentionFilter, &settings.MentionThreshold,
		&settings.DuplicateFilter,
	)
	if err != nil {
		return &commands.CommandResponse{Content: "⚠️ AutoMod is not configured for this server. Use `/automod enable` first."}, nil
	}

	status := "🔴 Disabled"
	if settings.Enabled {
		status = "🟢 Enabled"
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title: "🤖 AutoMod Status",
			Color: "#5865F2",
			Fields: []commands.EmbedField{
				{Name: "Status", Value: status, Inline: true},
				{Name: "Invite Filter", Value: BoolEmoji(settings.InviteFilter), Inline: true},
				{Name: "Link Filter", Value: BoolEmoji(settings.LinkFilter), Inline: true},
				{Name: "Caps Filter", Value: fmt.Sprintf("%s (%d%%)", BoolEmoji(settings.CapsFilter), settings.CapsThreshold), Inline: true},
				{Name: "Emoji Filter", Value: fmt.Sprintf("%s (max %d)", BoolEmoji(settings.EmojiFilter), settings.EmojiThreshold), Inline: true},
				{Name: "Mention Filter", Value: fmt.Sprintf("%s (max %d)", BoolEmoji(settings.MentionFilter), settings.MentionThreshold), Inline: true},
				{Name: "Duplicate Filter", Value: BoolEmoji(settings.DuplicateFilter), Inline: true},
			},
		},
	}, nil
}

func (b *AutoModBot) configureFilter(serverID, filter, value string) (*commands.CommandResponse, error) {
	var query string
	switch filter {
	case "invites":
		query = `UPDATE automod_settings SET invite_filter = $2::boolean WHERE server_id = $1`
	case "links":
		query = `UPDATE automod_settings SET link_filter = $2::boolean WHERE server_id = $1`
	case "caps":
		query = `UPDATE automod_settings SET caps_filter = true, caps_threshold = $2::integer WHERE server_id = $1`
	case "emoji":
		query = `UPDATE automod_settings SET emoji_filter = true, emoji_threshold = $2::integer WHERE server_id = $1`
	case "mentions":
		query = `UPDATE automod_settings SET mention_filter = true, mention_threshold = $2::integer WHERE server_id = $1`
	case "duplicates":
		query = `UPDATE automod_settings SET duplicate_filter = $2::boolean WHERE server_id = $1`
	default:
		return &commands.CommandResponse{Content: "❌ Unknown filter. Use: invites, links, caps, emoji, mentions, duplicates", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(), query, serverID, value)
	if err != nil {
		return nil, err
	}
	return &commands.CommandResponse{Content: fmt.Sprintf("✅ Filter `%s` updated to `%s`.", filter, value)}, nil
}

// ── Message Evaluation Engine ───────────────────────────────────────────────

var (
	inviteRegex = regexp.MustCompile(`(?i)\b(?:https?://)?(?:www\.)?(?:discord\.gg|discordapp\.com/invite|invite\.gg|flicko\.gg)/[a-zA-Z0-9_-]+`)
	urlRegex    = regexp.MustCompile(`\bhttps?://[^\s]+`)
	// MED-11 fix: Flicko mentions wrap UUIDs (with hyphens), not Discord
	// snowflakes. Match hex+hyphens.
	mentionRegex = regexp.MustCompile(`<@!?[a-fA-F0-9-]+>`)
	emojiRegex   = regexp.MustCompile(`<a?:\w+:\d+>|[\x{1F600}-\x{1F64F}]|[\x{1F300}-\x{1F5FF}]|[\x{1F680}-\x{1F6FF}]|[\x{1F1E0}-\x{1F1FF}]`)
)

func (b *AutoModBot) onMessageCreate(evt events.Event) error {
	if evt.ServerID == "" {
		return nil // DMs are not moderated
	}

	content, _ := evt.Data["content"].(string)
	if content == "" {
		return nil
	}
	authorID, _ := evt.Data["author_id"].(string)
	messageID, _ := evt.Data["message_id"].(string)

	// Load settings
	var settings struct {
		Enabled          bool
		InviteFilter     bool
		LinkFilter       bool
		CapsFilter       bool
		CapsThreshold    int
		EmojiFilter      bool
		EmojiThreshold   int
		MentionFilter    bool
		MentionThreshold int
		DuplicateFilter  bool
		ExemptRoles      []string
		ExemptChannels   []string
		ExemptUsers      []string
	}

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled, invite_filter, link_filter, caps_filter, caps_threshold,
				emoji_filter, emoji_threshold, mention_filter, mention_threshold, duplicate_filter,
				exempt_roles, exempt_channels, exempt_users
		 FROM automod_settings WHERE server_id = $1`, evt.ServerID).Scan(
		&settings.Enabled, &settings.InviteFilter, &settings.LinkFilter,
		&settings.CapsFilter, &settings.CapsThreshold, &settings.EmojiFilter,
		&settings.EmojiThreshold, &settings.MentionFilter, &settings.MentionThreshold,
		&settings.DuplicateFilter, &settings.ExemptRoles, &settings.ExemptChannels, &settings.ExemptUsers,
	)
	if err != nil || !settings.Enabled {
		return nil // not configured or disabled
	}

	// Check exemptions
	if b.isExempt(evt.ServerID, authorID, evt.ChannelID, settings.ExemptRoles, settings.ExemptChannels, settings.ExemptUsers) {
		return nil
	}

	// Run filters
	var violation string

	if settings.InviteFilter && inviteRegex.MatchString(content) {
		violation = "Server invite links are not allowed"
	}

	if violation == "" && settings.LinkFilter && urlRegex.MatchString(content) {
		violation = "Links are not allowed in this server"
	}

	if violation == "" && settings.CapsFilter {
		capsRatio := capsPercentage(content)
		if capsRatio > settings.CapsThreshold && utf8.RuneCountInString(content) > 10 {
			violation = fmt.Sprintf("Too many capital letters (%d%% caps)", capsRatio)
		}
	}

	if violation == "" && settings.EmojiFilter {
		emojiCount := len(emojiRegex.FindAllString(content, -1))
		if emojiCount > settings.EmojiThreshold {
			violation = fmt.Sprintf("Too many emojis (%d, max %d)", emojiCount, settings.EmojiThreshold)
		}
	}

	if violation == "" && settings.MentionFilter {
		mentionCount := len(mentionRegex.FindAllString(content, -1))
		if mentionCount > settings.MentionThreshold {
			violation = fmt.Sprintf("Too many mentions (%d, max %d)", mentionCount, settings.MentionThreshold)
		}
	}

	if violation != "" {
		b.takeAction(evt.ServerID, evt.ChannelID, messageID, authorID, violation)
	}

	return nil
}

func (b *AutoModBot) isExempt(serverID, userID, channelID string, roles, channels, users []string) bool {
	// Check if user is server owner
	var isOwner bool
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM servers WHERE id = $1 AND owner_id = $2)`,
		serverID, userID).Scan(&isOwner)
	if isOwner {
		return true
	}

	for _, u := range users {
		if u == userID {
			return true
		}
	}
	for _, c := range channels {
		if c == channelID {
			return true
		}
	}
	// Check roles
	if len(roles) > 0 {
		var hasRole bool
		b.ctx.DB.QueryRow(context.Background(),
			`SELECT EXISTS(
				SELECT 1 FROM member_roles WHERE server_id = $1 AND user_id = $2 AND role_id = ANY($3::uuid[])
			)`, serverID, userID, roles).Scan(&hasRole)
		if hasRole {
			return true
		}
	}
	return false
}

func (b *AutoModBot) takeAction(serverID, channelID, messageID, userID, reason string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// HIGH-18: Delete via the messages table is acceptable here because we
	// also publish a MESSAGE_DELETE event so realtime clients reconcile.
	// Attachment cleanup is owned by the attachment_cleanup service that
	// runs on a separate sweep; we do not duplicate that here.
	if _, err := b.ctx.DB.Exec(ctx,
		`DELETE FROM messages WHERE id = $1 AND channel_id = $2`, messageID, channelID); err != nil {
		b.logger.Error("automod delete failed", zap.Error(err))
		return
	}

	// Audit (uses canonical schema via shared helper).
	LogAudit(ctx, b.ctx, serverID, userID, "automod", "user", userID, reason)

	// Realtime fan-out.
	b.ctx.EventBus.Publish(events.Event{
		Type:      events.MessageDelete,
		ServerID:  serverID,
		ChannelID: channelID,
		Data: map[string]interface{}{
			"message_id": messageID,
			"reason":     "automod:" + reason,
		},
	})

	b.logger.Info("automod action taken",
		zap.String("server", serverID),
		zap.String("user", userID),
		zap.String("reason", reason),
	)
}

func capsPercentage(s string) int {
	if len(s) == 0 {
		return 0
	}
	caps := 0
	total := 0
	for _, r := range s {
		if r >= 'A' && r <= 'Z' {
			caps++
			total++
		} else if r >= 'a' && r <= 'z' {
			total++
		}
	}
	if total == 0 {
		return 0
	}
	return (caps * 100) / total
}

// boolEmoji is provided by helpers.go (BoolEmoji). The local copy used to
// duplicate that function — kept this comment to make the deletion obvious
// in code review.
