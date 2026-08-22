package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/commands"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

// BotHandler handles bot-related API endpoints.
type BotHandler struct {
	db       database.DatabaseClient
	eventBus *events.EventBus
	router   *commands.Router
	cache    cache.CacheLayer // optional; nil disables idempotency dedup
	logger   *zap.Logger
}

// NewBotHandler creates a new BotHandler.
//
// The cache parameter is optional (may be nil). When non-nil, the notify
// endpoints use it to dedup events so a replayed request from the client
// does not double-trigger XP grants, AutoMod actions, etc.
func NewBotHandler(db database.DatabaseClient, bus *events.EventBus, router *commands.Router, c cache.CacheLayer, logger *zap.Logger) *BotHandler {
	return &BotHandler{
		db:       db,
		eventBus: bus,
		router:   router,
		cache:    c,
		logger:   logger,
	}
}

// idempotent returns true if this is the first time we've seen the given key
// within ttl. Subsequent calls with the same key (within ttl) return false.
// If the cache is unavailable, returns true (fail-open) to avoid blocking
// the bus on a Redis outage.
func (h *BotHandler) idempotent(ctx context.Context, key string, ttl time.Duration) bool {
	if h.cache == nil {
		return true
	}
	rdb := h.cache.GetRedisClient()
	ok, err := rdb.SetNX(ctx, "bot:idem:"+key, "1", ttl).Result()
	if err != nil {
		h.logger.Debug("idempotency check error (fail-open)", zap.Error(err))
		return true
	}
	return ok
}

// ── Slash Command Endpoints ─────────────────────────────────────────────────

// ListCommands returns all registered slash commands.
func (h *BotHandler) ListCommands(w http.ResponseWriter, r *http.Request) {
	defs := h.router.GetDefinitions()
	writeJSON(w, http.StatusOK, defs)
}

// ListServerCommands returns commands available for a specific server.
func (h *BotHandler) ListServerCommands(w http.ResponseWriter, r *http.Request) {
	// For now, all commands are available in all servers
	defs := h.router.GetDefinitions()
	writeJSON(w, http.StatusOK, defs)
}

// InvokeCommand processes a slash command invocation from the client.
func (h *BotHandler) InvokeCommand(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		CommandName string                 `json:"command_name"`
		ServerID    string                 `json:"server_id"`
		ChannelID   string                 `json:"channel_id"`
		Options     map[string]interface{} `json:"options"`
	}

	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body"})
		return
	}

	if body.CommandName == "" || body.ServerID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "command_name and server_id are required"})
		return
	}

	body.CommandName = h.sanitizeString(body.CommandName, 100)
	body.ServerID = h.sanitizeString(body.ServerID, 100)
	body.ChannelID = h.sanitizeString(body.ChannelID, 100)

	// HIGH-13: Per-(user, command) rate limit. Discord-style commands like
	// /ban or /purge have huge blast radius if spammed; /rank is harmless.
	// Use a token bucket via Redis INCR with EXPIRE. Limits:
	//   • write commands (ban/kick/mute/warn/purge/ticket-config/automod/etc.) → 10/min
	//   • read commands (rank/leaderboard/stars/etc.)                          → 60/min
	//   • everything else                                                      → 30/min
	if !h.rateLimitOK(r.Context(), userID, body.CommandName) {
		writeJSON(w, http.StatusTooManyRequests, map[string]string{
			"error": "You're using this command too quickly. Try again in a moment.",
		})
		return
	}

	// Security: Validate command name against known commands to prevent injection
	defs := h.router.GetDefinitions()
	commandExists := false
	for _, def := range defs {
		if def.Name == body.CommandName {
			commandExists = true
			break
		}
	}
	if !commandExists {
		h.logger.Warn("unknown command invoked",
			zap.String("user_id", userID),
			zap.String("command", body.CommandName),
		)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Unknown command: " + body.CommandName})
		return
	}

	// Security: Sanitize options to prevent injection attacks
	sanitizedOptions := h.sanitizeOptions(body.Options)
	body.Options = sanitizedOptions

	// Create an interaction record matching the deployed schema.
	// type=2 == APPLICATION_COMMAND in the Discord-style enum.
	var interactionID string
	{
		data := map[string]interface{}{
			"name":    body.CommandName,
			"options": body.Options,
		}
		err := h.db.QueryRow(r.Context(),
			`INSERT INTO interactions (type, guild_id, channel_id, user_id, data)
			 VALUES (2, $1::uuid, $2::uuid, $3::uuid, $4)
			 RETURNING id`,
			body.ServerID, body.ChannelID, userID, data).Scan(&interactionID)
		if err != nil {
			h.logger.Error("interaction insert failed",
				zap.Error(err),
				zap.String("command", body.CommandName),
			)
			// Continue with a synthetic ID; the slash command itself should
			// still execute even if the audit row failed.
			interactionID = "temp-" + body.CommandName
		}
	}

	// Build and publish the command event for analytics / external bots.
	// IMPORTANT: this is fire-and-forget. The router does NOT execute on
	// receiving this event (CRIT-8 fix). Execution happens via Dispatch below.
	evt := events.Event{
		Type:      events.CommandInvoke,
		ServerID:  body.ServerID,
		ChannelID: body.ChannelID,
		UserID:    userID,
		Timestamp: time.Now(),
		Data: map[string]interface{}{
			"command_name":   body.CommandName,
			"interaction_id": interactionID,
			"options":        body.Options,
		},
	}
	h.eventBus.Publish(evt)

	// Process the command synchronously so we can return the response.
	cmdCtx := commands.CommandContext{
		Ctx:           r.Context(),
		Command:       body.CommandName,
		Options:       body.Options,
		UserID:        userID,
		ServerID:      body.ServerID,
		ChannelID:     body.ChannelID,
		InteractionID: interactionID,
	}

	// Extract sub-command if present
	if sub, ok := body.Options["subcommand"].(string); ok {
		cmdCtx.SubCommand = sub
	}

	resp, err := h.router.Dispatch(cmdCtx)
	if err != nil {
		h.logger.Error("command execution failed",
			zap.String("command", body.CommandName),
			zap.Error(err),
		)
		// Update interaction status (best-effort)
		_, _ = h.db.Exec(r.Context(),
			`UPDATE interactions SET responded = true WHERE id = $1`,
			interactionID)

		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	// Update interaction status (best-effort)
	_, _ = h.db.Exec(r.Context(),
		`UPDATE interactions SET responded = true WHERE id = $1`, interactionID)

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"interaction_id": interactionID,
		"response":       resp,
	})
}

// ── Bot Settings Endpoints ──────────────────────────────────────────────────

// GetBotSettings returns settings for a specific bot in a server.
func (h *BotHandler) GetBotSettings(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	botName := vars["botName"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	var query string
	switch botName {
	case "moderation":
		query = `SELECT row_to_json(s) FROM mod_settings s WHERE server_id = $1::uuid`
	case "automod":
		query = `SELECT row_to_json(s) FROM automod_settings s WHERE server_id = $1::uuid`
	case "welcome":
		query = `SELECT row_to_json(s) FROM welcome_settings s WHERE server_id = $1::uuid`
	case "leveling":
		query = `SELECT row_to_json(s) FROM level_settings s WHERE server_id = $1::uuid`
	case "ticket":
		query = `SELECT row_to_json(s) FROM ticket_settings s WHERE server_id = $1::uuid`
	case "starboard":
		query = `SELECT row_to_json(s) FROM starboard_settings s WHERE server_id = $1::uuid`
	case "music":
		query = `SELECT row_to_json(s) FROM music_settings s WHERE server_id = $1::uuid`
	default:
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Unknown bot: " + botName})
		return
	}

	var result json.RawMessage
	err := h.db.QueryRow(r.Context(), query, serverID).Scan(&result)
	if err != nil {
		// Return empty/default settings
		writeJSON(w, http.StatusOK, map[string]interface{}{"enabled": false, "server_id": serverID})
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// UpdateBotSettings updates settings for a specific bot in a server.
// Permission (HIGH-12 fix): server owner OR any role with the MANAGE_GUILD
// permission bit (0x20). This allows co-admins to manage bots.
func (h *BotHandler) UpdateBotSettings(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	botName := vars["botName"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.canManageBots(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{
			"error": "You need MANAGE_GUILD permission to manage bot settings",
		})
		return
	}

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON"})
		return
	}

	// For each bot, handle the enabled toggle minimally
	enabled, _ := body["enabled"].(bool)

	// Use a pre-validated query per bot — no string concatenation.
	var upsertSQL string
	switch botName {
	case "moderation":
		upsertSQL = `INSERT INTO mod_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "automod":
		upsertSQL = `INSERT INTO automod_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "welcome":
		upsertSQL = `INSERT INTO welcome_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "leveling":
		upsertSQL = `INSERT INTO level_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "ticket":
		upsertSQL = `INSERT INTO ticket_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "starboard":
		upsertSQL = `INSERT INTO starboard_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "music":
		upsertSQL = `INSERT INTO music_settings (server_id, enabled) VALUES ($1::uuid, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	default:
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Unknown bot"})
		return
	}

	_, err := h.db.Exec(r.Context(), upsertSQL, serverID, enabled)
	if err != nil {
		h.logger.Error("bot settings update failed", zap.Error(err))
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update settings"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"success": true, "enabled": enabled})
}

// ── XP/Level Endpoints ──────────────────────────────────────────────────────

// GetLeaderboard returns the XP leaderboard for a server.
func (h *BotHandler) GetLeaderboard(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT ux.user_id, u.username, u.avatar_url, ux.xp, ux.level, ux.message_count
		 FROM user_xp ux
		 JOIN users u ON u.id = ux.user_id
		 WHERE ux.server_id = $1
		 ORDER BY ux.xp DESC
		 LIMIT 50`,
		serverID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	type entry struct {
		UserID       string  `json:"user_id"`
		Username     string  `json:"username"`
		AvatarURL    *string `json:"avatar_url"`
		XP           int     `json:"xp"`
		Level        int     `json:"level"`
		MessageCount int     `json:"message_count"`
		Rank         int     `json:"rank"`
	}

	var entries []entry
	rank := 1
	for rows.Next() {
		var e entry
		if err := rows.Scan(&e.UserID, &e.Username, &e.AvatarURL, &e.XP, &e.Level, &e.MessageCount); err != nil {
			continue
		}
		e.Rank = rank
		entries = append(entries, e)
		rank++
	}

	writeJSON(w, http.StatusOK, entries)
}

// GetUserRank returns a specific user's rank in a server.
func (h *BotHandler) GetUserRank(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID := vars["userId"]
	authUserID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, authUserID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	var xp, level, messageCount int
	err := h.db.QueryRow(r.Context(),
		`SELECT xp, level, message_count FROM user_xp WHERE user_id = $1 AND server_id = $2`,
		userID, serverID).Scan(&xp, &level, &messageCount)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "No XP data found"})
		return
	}

	var rank int
	h.db.QueryRow(r.Context(),
		`SELECT COUNT(*) + 1 FROM user_xp WHERE server_id = $1 AND xp > $2`,
		serverID, xp).Scan(&rank)

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":       userID,
		"server_id":     serverID,
		"xp":            xp,
		"level":         level,
		"message_count": messageCount,
		"rank":          rank,
	})
}

// ── Ticket Endpoints ────────────────────────────────────────────────────────

// GetServerTickets returns tickets for a server.
func (h *BotHandler) GetServerTickets(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	status := r.URL.Query().Get("status")
	if status == "" {
		status = "open"
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT t.id, t.ticket_number, t.subject, t.status, t.priority,
				t.creator_id, u.username, t.created_at, t.message_count
		 FROM tickets t
		 JOIN users u ON u.id = t.creator_id
		 WHERE t.server_id = $1 AND t.status = $2
		 ORDER BY t.created_at DESC LIMIT 50`,
		serverID, status)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	type ticket struct {
		ID           string    `json:"id"`
		Number       int       `json:"ticket_number"`
		Subject      string    `json:"subject"`
		Status       string    `json:"status"`
		Priority     string    `json:"priority"`
		CreatorID    string    `json:"creator_id"`
		CreatorName  string    `json:"creator_name"`
		CreatedAt    time.Time `json:"created_at"`
		MessageCount int       `json:"message_count"`
	}

	var tickets []ticket
	for rows.Next() {
		var t ticket
		if err := rows.Scan(&t.ID, &t.Number, &t.Subject, &t.Status, &t.Priority,
			&t.CreatorID, &t.CreatorName, &t.CreatedAt, &t.MessageCount); err != nil {
			continue
		}
		tickets = append(tickets, t)
	}

	writeJSON(w, http.StatusOK, tickets)
}

// ── Poll Endpoints ──────────────────────────────────────────────────────────

// GetActivePolls returns active polls for a server.
func (h *BotHandler) GetActivePolls(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT p.id, p.question, p.creator_id, p.anonymous, p.multi_vote,
				p.status, p.expires_at, p.created_at,
				COALESCE(
					json_agg(
						json_build_object('id', po.id, 'label', po.label, 'emoji', po.emoji,
							'votes', (SELECT COUNT(*) FROM poll_votes pv WHERE pv.option_id = po.id)
						) ORDER BY po.position
					) FILTER (WHERE po.id IS NOT NULL), '[]'
				) as options
		 FROM polls p
		 LEFT JOIN poll_options po ON po.poll_id = p.id
		 WHERE p.server_id = $1 AND p.status = 'active'
		 GROUP BY p.id
		 ORDER BY p.created_at DESC`,
		serverID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	type poll struct {
		ID        string          `json:"id"`
		Question  string          `json:"question"`
		CreatorID string          `json:"creator_id"`
		Anonymous bool            `json:"anonymous"`
		MultiVote bool            `json:"multi_vote"`
		Status    string          `json:"status"`
		ExpiresAt *time.Time      `json:"expires_at"`
		CreatedAt time.Time       `json:"created_at"`
		Options   json.RawMessage `json:"options"`
	}

	var polls []poll
	for rows.Next() {
		var p poll
		if err := rows.Scan(&p.ID, &p.Question, &p.CreatorID, &p.Anonymous,
			&p.MultiVote, &p.Status, &p.ExpiresAt, &p.CreatedAt, &p.Options); err != nil {
			continue
		}
		polls = append(polls, p)
	}

	writeJSON(w, http.StatusOK, polls)
}

// VotePoll handles voting on a poll option.
func (h *BotHandler) VotePoll(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		PollID   string `json:"poll_id"`
		OptionID string `json:"option_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request"})
		return
	}

	// Check if poll allows multi-vote
	var multiVote bool
	err := h.db.QueryRow(r.Context(),
		`SELECT multi_vote FROM polls WHERE id = $1 AND status = 'active'`,
		body.PollID).Scan(&multiVote)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "Poll not found or closed"})
		return
	}

	if !multiVote {
		// Remove existing vote
		h.db.Exec(r.Context(),
			`DELETE FROM poll_votes WHERE user_id = $1
			 AND option_id IN (SELECT id FROM poll_options WHERE poll_id = $2)`,
			userID, body.PollID)
	}

	_, err = h.db.Exec(r.Context(),
		`INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES ($1, $2, $3)
		 ON CONFLICT DO NOTHING`,
		body.PollID, body.OptionID, userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Vote failed"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "voted"})
}

// ── Starboard Endpoints ─────────────────────────────────────────────────────

// GetStarboardEntries returns top starred messages for a server.
func (h *BotHandler) GetStarboardEntries(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if !h.isMember(r.Context(), serverID, userID) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT se.id, se.original_message_id, se.original_channel_id,
				se.author_id, u.username, se.star_count, se.content, se.created_at
		 FROM starboard_entries se
		 JOIN users u ON u.id = se.author_id
		 WHERE se.server_id = $1 AND se.star_count > 0
		 ORDER BY se.star_count DESC
		 LIMIT 50`,
		serverID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	type entry struct {
		ID         string    `json:"id"`
		MessageID  string    `json:"original_message_id"`
		ChannelID  string    `json:"original_channel_id"`
		AuthorID   string    `json:"author_id"`
		AuthorName string    `json:"author_name"`
		StarCount  int       `json:"star_count"`
		Content    string    `json:"content"`
		CreatedAt  time.Time `json:"created_at"`
	}

	var entries []entry
	for rows.Next() {
		var e entry
		if err := rows.Scan(&e.ID, &e.MessageID, &e.ChannelID,
			&e.AuthorID, &e.AuthorName, &e.StarCount, &e.Content, &e.CreatedAt); err != nil {
			continue
		}
		entries = append(entries, e)
	}

	writeJSON(w, http.StatusOK, entries)
}

// NotifyMemberJoin publishes a MEMBER_JOIN event so bots (e.g. WelcomeBot) can
// react when a user joins a server. The frontend calls this after adding the
// member directly.
//
// Idempotent per (server_id, user_id) for 60 seconds to absorb retries.
func (h *BotHandler) NotifyMemberJoin(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if serverID == "" || userID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "server_id and authenticated user required"})
		return
	}

	// Verify the user is actually a member of this server to prevent abuse
	var exists bool
	err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1 AND user_id = $2)`,
		serverID, userID).Scan(&exists)
	if err != nil || !exists {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	if !h.idempotent(r.Context(), "join:"+serverID+":"+userID, 60*time.Second) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	go h.eventBus.Publish(events.Event{
		Type:      events.MemberJoin,
		ServerID:  serverID,
		UserID:    userID,
		Data:      map[string]interface{}{},
		Timestamp: time.Now(),
	})

	h.logger.Info("MEMBER_JOIN event published",
		zap.String("server_id", serverID),
		zap.String("user_id", userID),
	)

	w.WriteHeader(http.StatusNoContent)
}

// NotifyMemberLeave publishes a MEMBER_LEAVE event so bots (e.g. WelcomeBot
// goodbye message) can react when a user leaves a server.
func (h *BotHandler) NotifyMemberLeave(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	if serverID == "" || userID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "server_id and authenticated user required"})
		return
	}

	// Verify the caller is still a member (notifyMemberLeave is called before member delete)
	var memberExists bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1 AND user_id = $2)`,
		serverID, userID).Scan(&memberExists); err != nil || !memberExists {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	if !h.idempotent(r.Context(), "leave:"+serverID+":"+userID, 60*time.Second) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	// Look up username for the goodbye message
	var username string
	if err := h.db.QueryRow(r.Context(),
		`SELECT COALESCE(display_name, username) FROM users WHERE id = $1`, userID).Scan(&username); err != nil {
		h.logger.Warn("could not look up username for goodbye message", zap.String("user_id", userID), zap.Error(err))
	}

	go h.eventBus.Publish(events.Event{
		Type:     events.MemberLeave,
		ServerID: serverID,
		UserID:   userID,
		Data: map[string]interface{}{
			"username": username,
		},
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusNoContent)
}

// NotifyMessageCreate publishes a MESSAGE_CREATE event so bots (AutoMod,
// Leveling) can process new messages.
//
// Security (CRIT-14): the message MUST exist server-side, MUST belong to the
// claimed channel, and MUST be authored by the calling user. Content is
// re-read from the database — never trusted from the request body.
//
// Idempotent per message_id for 5 minutes.
func (h *BotHandler) NotifyMessageCreate(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		MessageID string `json:"message_id"`
		ChannelID string `json:"channel_id"`
		ServerID  string `json:"server_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body"})
		return
	}

	if body.MessageID == "" || body.ChannelID == "" || body.ServerID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "message_id, channel_id, and server_id are required"})
		return
	}

	// Verify the message exists, is in the claimed channel/server, and was
	// authored by the calling user. Re-read content from the DB so a client
	// cannot inject fake content for AutoMod to act on.
	var (
		dbAuthorID  string
		dbChannelID string
		dbServerID  string
		dbContent   string
	)
	err := h.db.QueryRow(r.Context(),
		`SELECT m.author_id, m.channel_id, c.server_id, m.content
		 FROM messages m
		 JOIN channels c ON c.id = m.channel_id
		 WHERE m.id = $1`,
		body.MessageID).Scan(&dbAuthorID, &dbChannelID, &dbServerID, &dbContent)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "message not found"})
		return
	}
	if dbAuthorID != userID || dbChannelID != body.ChannelID || dbServerID != body.ServerID {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "message ownership mismatch"})
		return
	}

	if !h.idempotent(r.Context(), "msg:"+body.MessageID, 5*time.Minute) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	go h.eventBus.Publish(events.Event{
		Type:      events.MessageCreate,
		ServerID:  body.ServerID,
		ChannelID: body.ChannelID,
		UserID:    userID,
		Data: map[string]interface{}{
			"message_id": body.MessageID,
			"content":    dbContent,
			"author_id":  userID,
		},
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusNoContent)
}

// NotifyReactionAdd publishes a REACTION_ADD event so bots (Starboard) can react.
// Idempotent per (message_id, user_id, emoji) for 60 seconds.
func (h *BotHandler) NotifyReactionAdd(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		MessageID string `json:"message_id"`
		ChannelID string `json:"channel_id"`
		ServerID  string `json:"server_id"`
		Emoji     string `json:"emoji"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body"})
		return
	}

	if body.MessageID == "" || body.ServerID == "" || body.Emoji == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "message_id, server_id, and emoji are required"})
		return
	}

	if !h.idempotent(r.Context(), "rx+:"+body.MessageID+":"+userID+":"+body.Emoji, 60*time.Second) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	go h.eventBus.Publish(events.Event{
		Type:      events.ReactionAdd,
		ServerID:  body.ServerID,
		ChannelID: body.ChannelID,
		UserID:    userID,
		Data: map[string]interface{}{
			"message_id": body.MessageID,
			"emoji":      body.Emoji,
		},
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusNoContent)
}

// NotifyReactionRemove publishes a REACTION_REMOVE event so bots (Starboard) can react.
func (h *BotHandler) NotifyReactionRemove(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		MessageID string `json:"message_id"`
		ChannelID string `json:"channel_id"`
		ServerID  string `json:"server_id"`
		Emoji     string `json:"emoji"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body"})
		return
	}

	if body.MessageID == "" || body.ServerID == "" || body.Emoji == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "message_id, server_id, and emoji are required"})
		return
	}

	go h.eventBus.Publish(events.Event{
		Type:      events.ReactionRemove,
		ServerID:  body.ServerID,
		ChannelID: body.ChannelID,
		UserID:    userID,
		Data: map[string]interface{}{
			"message_id": body.MessageID,
			"emoji":      body.Emoji,
		},
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusNoContent)
}

// sanitizeOptions recursively sanitizes command options to prevent injection attacks.
// It limits string lengths and strips potentially dangerous characters.
func (h *BotHandler) sanitizeOptions(options map[string]interface{}) map[string]interface{} {
	if options == nil {
		return nil
	}

	sanitized := make(map[string]interface{})
	for key, value := range options {
		sanitizedKey := h.sanitizeString(key, 100)

		switch v := value.(type) {
		case string:
			sanitized[sanitizedKey] = h.sanitizeString(v, 4000)
		case map[string]interface{}:
			sanitized[sanitizedKey] = h.sanitizeOptions(v)
		case []interface{}:
			sanitized[sanitizedKey] = h.sanitizeArray(v)
		default:
			sanitized[sanitizedKey] = v
		}
	}
	return sanitized
}

// sanitizeArray sanitizes array values in command options.
func (h *BotHandler) sanitizeArray(arr []interface{}) []interface{} {
	sanitized := make([]interface{}, 0, len(arr))
	for _, item := range arr {
		switch v := item.(type) {
		case string:
			sanitized = append(sanitized, h.sanitizeString(v, 4000))
		case map[string]interface{}:
			sanitized = append(sanitized, h.sanitizeOptions(v))
		default:
			sanitized = append(sanitized, v)
		}
	}
	return sanitized
}

// sanitizeString sanitizes a string value by stripping HTML tags / script
// content and limiting the length, while preserving Discord-style mentions
// like <#channelid>, <@userid>, <@&roleid>, <a:emoji:id> (MED-5 fix).
//
// Heuristic: anything inside <…> that starts with #, @, &, a:, or :
// is preserved as-is; everything else inside <…> is stripped.
func (h *BotHandler) sanitizeString(input string, maxLength int) string {
	if len(input) > maxLength {
		input = input[:maxLength]
	}

	var b strings.Builder
	b.Grow(len(input))

	i := 0
	runes := []rune(input)
	for i < len(runes) {
		ch := runes[i]
		if ch != '<' {
			b.WriteRune(ch)
			i++
			continue
		}
		// Find the matching '>'.
		j := i + 1
		for j < len(runes) && runes[j] != '>' {
			j++
		}
		if j >= len(runes) {
			// Unmatched '<' — drop it and stop scanning the tag.
			i++
			continue
		}
		inner := string(runes[i+1 : j])
		// Preserve Discord-style mentions and emoji refs.
		if isMentionLike(inner) {
			b.WriteByte('<')
			b.WriteString(inner)
			b.WriteByte('>')
		}
		// Otherwise, drop the tag entirely (HTML/script removal).
		i = j + 1
	}
	return b.String()
}

// isMentionLike returns true if the body of a <…> looks like a Discord-style
// mention/emoji rather than an HTML tag. Examples:
//   - "@uuid"        — user mention
//   - "@!uuid"       — user mention (legacy)
//   - "@&uuid"       — role mention
//   - "#channelid"   — channel mention
//   - ":name:id"     — custom emoji
//   - "a:name:id"    — animated custom emoji
func isMentionLike(s string) bool {
	if s == "" {
		return false
	}
	switch s[0] {
	case '#', '@':
		return true
	case ':':
		return true
	case 'a':
		return strings.HasPrefix(s, "a:")
	}
	return false
}


// canManageBots returns true if the user is allowed to change bot settings
// for the given server. The contract is:
//   - Server owner: always allowed.
//   - Member with at least one role carrying MANAGE_GUILD (0x20) or
//     ADMINISTRATOR (0x8): allowed.
//
// All errors are treated as "not allowed" (fail-closed).
func (h *BotHandler) canManageBots(ctx context.Context, serverID, userID string) bool {
	if serverID == "" || userID == "" {
		return false
	}

	var isOwner bool
	if err := h.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM servers WHERE id = $1::uuid AND owner_id = $2::uuid)`,
		serverID, userID,
	).Scan(&isOwner); err == nil && isOwner {
		return true
	}

	// Permissions bitmask: ADMINISTRATOR=0x8, MANAGE_GUILD=0x20.
	const wantBits int64 = 0x8 | 0x20
	var hasRole bool
	err := h.db.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1
			FROM member_roles mr
			JOIN roles r ON r.id = mr.role_id
			WHERE mr.server_id = $1::uuid
			  AND mr.user_id = $2::uuid
			  AND (r.permissions & $3) <> 0
		)`,
		serverID, userID, wantBits,
	).Scan(&hasRole)
	if err != nil {
		h.logger.Debug("canManageBots role lookup failed", zap.Error(err))
		return false
	}
	return hasRole
}


// rateLimitOK applies a Redis-backed per-(user, command) token bucket.
// Returns true if the call should proceed; false to drop with 429.
//
// Fail-open: if Redis is unreachable, we let the call through rather than
// blocking the entire bot surface on a cache outage.
func (h *BotHandler) rateLimitOK(ctx context.Context, userID, command string) bool {
	if h.cache == nil || userID == "" {
		return true
	}

	// Categorize commands by blast radius.
	const (
		writeLimit   = 10 // per minute
		readLimit    = 60 // per minute
		defaultLimit = 30 // per minute
	)
	limit := defaultLimit
	switch command {
	// High blast radius — moderation, config, ticket creation
	case "ban", "unban", "kick", "mute", "unmute", "warn", "purge", "slowmode",
		"ticket", "ticket-config", "automod", "automod-exempt",
		"welcome", "starboard", "music-config", "level-config", "xp",
		"poll", "quickpoll":
		limit = writeLimit
	// Low blast radius — read-only views
	case "rank", "leaderboard", "warnings", "modlog", "stars",
		"queue", "nowplaying", "history":
		limit = readLimit
	}

	rdb := h.cache.GetRedisClient()
	key := fmt.Sprintf("bot:rl:%s:%s", userID, command)

	// INCR; on first hit, set EXPIRE.
	count, err := rdb.Incr(ctx, key).Result()
	if err != nil {
		h.logger.Debug("rate limit INCR error (fail-open)", zap.Error(err))
		return true
	}
	if count == 1 {
		_ = rdb.Expire(ctx, key, time.Minute).Err()
	}
	return int(count) <= limit
}

func (h *BotHandler) isMember(ctx context.Context, serverID, userID string) bool {
	if serverID == "" || userID == "" {
		return false
	}
	var exists bool
	err := h.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1::uuid AND user_id = $2::uuid)`,
		serverID, userID).Scan(&exists)
	return err == nil && exists
}
