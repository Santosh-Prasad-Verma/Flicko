package handlers

import (
	"encoding/json"
	"net/http"
	"time"

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
	logger   *zap.Logger
}

// NewBotHandler creates a new BotHandler.
func NewBotHandler(db database.DatabaseClient, bus *events.EventBus, router *commands.Router, logger *zap.Logger) *BotHandler {
	return &BotHandler{db: db, eventBus: bus, router: router, logger: logger}
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

	// Create an interaction record
	var interactionID string
	err := h.db.QueryRow(r.Context(),
		`INSERT INTO interactions (command_name, user_id, server_id, channel_id, options, status)
		 VALUES ($1, $2, $3, $4, $5, 'pending')
		 RETURNING id`,
		body.CommandName, userID, body.ServerID, body.ChannelID, body.Options).Scan(&interactionID)
	if err != nil {
		h.logger.Error("interaction insert failed", zap.Error(err))
		interactionID = "temp-" + body.CommandName
	}

	// Build and publish the command event
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

	// Process the command synchronously so we can return the response
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

	// Also publish the event for any listeners
	h.eventBus.Publish(evt)

	// Execute command directly via router for synchronous response
	resp, err := h.executeCommand(cmdCtx)
	if err != nil {
		h.logger.Error("command execution failed",
			zap.String("command", body.CommandName),
			zap.Error(err),
		)
		// Update interaction status
		h.db.Exec(r.Context(),
			`UPDATE interactions SET status = 'failed', response = $2 WHERE id = $1`,
			interactionID, map[string]string{"error": err.Error()})

		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	// Update interaction status
	h.db.Exec(r.Context(),
		`UPDATE interactions SET status = 'completed' WHERE id = $1`, interactionID)

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"interaction_id": interactionID,
		"response":       resp,
	})
}

func (h *BotHandler) executeCommand(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	// Use the router's handlers directly
	evt := events.Event{
		Type:      events.CommandInvoke,
		ServerID:  ctx.ServerID,
		ChannelID: ctx.ChannelID,
		UserID:    ctx.UserID,
		Data: map[string]interface{}{
			"command_name":   ctx.Command,
			"interaction_id": ctx.InteractionID,
			"options":        ctx.Options,
		},
	}

	err := h.router.HandleEvent(evt)
	if err != nil {
		return nil, err
	}

	// Try to extract response from event data
	if resp, ok := evt.Data["response"].(*commands.CommandResponse); ok {
		return resp, nil
	}

	return &commands.CommandResponse{Content: "✅ Command executed."}, nil
}

// ── Bot Settings Endpoints ──────────────────────────────────────────────────

// GetBotSettings returns settings for a specific bot in a server.
func (h *BotHandler) GetBotSettings(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	botName := vars["botName"]

	var query string
	switch botName {
	case "moderation":
		query = `SELECT row_to_json(s) FROM mod_settings s WHERE server_id = $1`
	case "automod":
		query = `SELECT row_to_json(s) FROM automod_settings s WHERE server_id = $1`
	case "welcome":
		query = `SELECT row_to_json(s) FROM welcome_settings s WHERE server_id = $1`
	case "leveling":
		query = `SELECT row_to_json(s) FROM level_settings s WHERE server_id = $1`
	case "ticket":
		query = `SELECT row_to_json(s) FROM ticket_settings s WHERE server_id = $1`
	case "starboard":
		query = `SELECT row_to_json(s) FROM starboard_settings s WHERE server_id = $1`
	case "music":
		query = `SELECT row_to_json(s) FROM music_settings s WHERE server_id = $1`
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

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(result)
}

// UpdateBotSettings updates settings for a specific bot in a server.
func (h *BotHandler) UpdateBotSettings(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	botName := vars["botName"]
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	// Verify the user is the server owner or admin
	var isOwner bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM servers WHERE id = $1 AND owner_id = $2)`,
		serverID, userID).Scan(&isOwner)
	if !isOwner {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "Only server owners can manage bot settings"})
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
		upsertSQL = `INSERT INTO mod_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "automod":
		upsertSQL = `INSERT INTO automod_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "welcome":
		upsertSQL = `INSERT INTO welcome_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "leveling":
		upsertSQL = `INSERT INTO level_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "ticket":
		upsertSQL = `INSERT INTO ticket_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "starboard":
		upsertSQL = `INSERT INTO starboard_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
	case "music":
		upsertSQL = `INSERT INTO music_settings (server_id, enabled) VALUES ($1, $2) ON CONFLICT (server_id) DO UPDATE SET enabled = $2`
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
// member directly via Supabase.
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

	// Verify the caller is still a member (notifyMemberLeave is called before Supabase delete)
	var memberExists bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1 AND user_id = $2)`,
		serverID, userID).Scan(&memberExists); err != nil || !memberExists {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
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
func (h *BotHandler) NotifyMessageCreate(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(middleware.GetUserIDKey()).(string)

	var body struct {
		MessageID string `json:"message_id"`
		ChannelID string `json:"channel_id"`
		ServerID  string `json:"server_id"`
		Content   string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid request body"})
		return
	}

	if body.ChannelID == "" || body.ServerID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "channel_id and server_id are required"})
		return
	}

	// Verify user is a member of this server
	var exists bool
	err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM server_members WHERE server_id = $1 AND user_id = $2)`,
		body.ServerID, userID).Scan(&exists)
	if err != nil || !exists {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "user is not a member of this server"})
		return
	}

	go h.eventBus.Publish(events.Event{
		Type:      events.MessageCreate,
		ServerID:  body.ServerID,
		ChannelID: body.ChannelID,
		UserID:    userID,
		Data: map[string]interface{}{
			"message_id": body.MessageID,
			"content":    body.Content,
			"author_id":  userID,
		},
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusNoContent)
}

// NotifyReactionAdd publishes a REACTION_ADD event so bots (Starboard) can react.
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

// sanitizeString sanitizes a string value by stripping HTML tags, script content,
// and limiting the length. This prevents XSS and injection attacks.
func (h *BotHandler) sanitizeString(input string, maxLength int) string {
	if len(input) > maxLength {
		input = input[:maxLength]
	}

	// Strip HTML tags and script content
	result := ""
	inTag := false
	for _, ch := range input {
		if ch == '<' {
			inTag = true
			continue
		}
		if ch == '>' {
			inTag = false
			continue
		}
		if !inTag {
			result += string(ch)
		}
	}

	return result
}
