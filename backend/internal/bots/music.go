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

// MusicBot manages server playlists, song queues, and playback state.
// Since actual audio streaming happens client-side, this bot manages
// the queue, playlists, and now-playing state in the database.
type MusicBot struct {
	ctx    BotContext
	router *commands.Router
	logger *zap.Logger
}

func NewMusicBot(router *commands.Router) *MusicBot {
	return &MusicBot{router: router}
}

func (b *MusicBot) Name() string { return "music" }

func (b *MusicBot) Register(bctx BotContext) error {
	b.ctx = bctx
	b.logger = bctx.Logger.Named("bot.music")

	b.registerCommands()

	b.logger.Info("music bot registered")
	return nil
}

func (b *MusicBot) Shutdown() error { return nil }

// requireDJ ensures the caller is allowed to mutate playback. Server owners
// and members holding the configured dj_role_id are allowed; if no DJ role is
// configured, all members may control playback.
//
// HIGH-17 fix: a transient DB error now DENIES access (fail-closed) rather
// than opening DJ control to everyone.
func (b *MusicBot) requireDJ(ctx commands.CommandContext) (bool, string) {
	reqCtx := ctx.Ctx
	if reqCtx == nil {
		reqCtx = context.Background()
	}

	var djRoleID *string
	err := b.ctx.DB.QueryRow(reqCtx,
		`SELECT dj_role_id::text FROM music_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&djRoleID)
	if err != nil {
		// No settings row → no DJ role configured → allow everyone.
		// But distinguish "no row" from "query error":
		if err.Error() == "no rows in result set" || strings.Contains(err.Error(), "no rows") {
			return true, ""
		}
		// Transient error → fail-closed.
		b.logger.Warn("requireDJ: DB error, denying access", zap.Error(err))
		return false, "❌ Could not verify DJ permissions. Try again."
	}
	if djRoleID == nil || *djRoleID == "" {
		return true, "" // No DJ role configured → everyone allowed.
	}

	// Owner bypass.
	if HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return true, ""
	}

	// Role membership check.
	var has bool
	_ = b.ctx.DB.QueryRow(reqCtx,
		`SELECT EXISTS(
			SELECT 1 FROM member_roles mr
			WHERE mr.server_id = $1 AND mr.user_id = $2 AND mr.role_id = $3
		)`,
		ctx.ServerID, ctx.UserID, *djRoleID).Scan(&has)
	if has {
		return true, ""
	}
	return false, "❌ Only DJs can do that."
}

func (b *MusicBot) registerCommands() {
	// /play <query|url>
	b.router.Register(commands.CommandDefinition{
		Name:        "play",
		Description: "Add a song to the queue",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "query", Description: "Song name or URL", Type: 3, Required: true},
		},
	}, b.handlePlay)

	// /skip
	b.router.Register(commands.CommandDefinition{
		Name:        "skip",
		Description: "Skip the current song",
		BotName:     "music",
	}, b.handleSkip)

	// /queue [page]
	b.router.Register(commands.CommandDefinition{
		Name:        "queue",
		Description: "View the song queue",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "page", Description: "Page number", Type: 4, Required: false},
		},
	}, b.handleQueue)

	// /nowplaying
	b.router.Register(commands.CommandDefinition{
		Name:        "nowplaying",
		Description: "Show the currently playing song",
		BotName:     "music",
	}, b.handleNowPlaying)

	// /pause
	b.router.Register(commands.CommandDefinition{
		Name:        "pause",
		Description: "Pause playback",
		BotName:     "music",
	}, b.handlePause)

	// /resume
	b.router.Register(commands.CommandDefinition{
		Name:        "resume",
		Description: "Resume playback",
		BotName:     "music",
	}, b.handleResume)

	// /stop
	b.router.Register(commands.CommandDefinition{
		Name:        "stop",
		Description: "Stop playback and clear queue",
		BotName:     "music",
	}, b.handleStop)

	// /shuffle
	b.router.Register(commands.CommandDefinition{
		Name:        "shuffle",
		Description: "Shuffle the queue",
		BotName:     "music",
	}, b.handleShuffle)

	// /repeat <mode>
	b.router.Register(commands.CommandDefinition{
		Name:        "repeat",
		Description: "Set repeat mode",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "mode", Description: "off, song, or queue", Type: 3, Required: true},
		},
	}, b.handleRepeat)

	// /volume <level>
	b.router.Register(commands.CommandDefinition{
		Name:        "volume",
		Description: "Set volume (0-100)",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "level", Description: "Volume level 0-100", Type: 4, Required: true},
		},
	}, b.handleVolume)

	// /playlist <action>
	b.router.Register(commands.CommandDefinition{
		Name:        "playlist",
		Description: "Manage playlists",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "action", Description: "create, delete, list, add, remove, load", Type: 3, Required: true},
			{Name: "name", Description: "Playlist name", Type: 3, Required: false},
			{Name: "query", Description: "Song to add or remove", Type: 3, Required: false},
		},
	}, b.handlePlaylist)

	// /history
	b.router.Register(commands.CommandDefinition{
		Name:        "history",
		Description: "View recently played songs",
		BotName:     "music",
	}, b.handleHistory)

	// /music-config
	b.router.Register(commands.CommandDefinition{
		Name:        "music-config",
		Description: "Configure music bot",
		BotName:     "music",
		Options: []commands.CommandOption{
			{Name: "action", Description: "enable, disable, dj-role, np-channel", Type: 3, Required: true},
			{Name: "role", Description: "DJ role", Type: 8, Required: false},
			{Name: "channel", Description: "Now-playing channel", Type: 7, Required: false},
		},
	}, b.handleMusicConfig)
}

// ── Command Handlers ────────────────────────────────────────────────────────

func (b *MusicBot) handlePlay(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	query, _ := ctx.Options["query"].(string)
	if query == "" {
		return &commands.CommandResponse{Content: "❌ Provide a song name or URL.", Ephemeral: true}, nil
	}

	// MED-2: enforce music_settings.enabled before mutating the queue.
	// A row may not exist yet; treat that as "enabled by default" so the
	// first /play in a server still works.
	var enabled bool = true
	_ = b.ctx.DB.QueryRow(context.Background(),
		`SELECT enabled FROM music_settings WHERE server_id = $1`,
		ctx.ServerID).Scan(&enabled)
	if !enabled {
		return &commands.CommandResponse{
			Content:   "🔴 The music bot is disabled on this server. An admin can enable it with `/music-config enable`.",
			Ephemeral: true,
		}, nil
	}

	// Determine if it's a URL or search query (resolved client-side).
	title, trackURL, duration := b.resolveTrackMetadata(query)

	// Single-statement insert avoids the SELECT MAX → INSERT race that produced
	// duplicate positions on concurrent /play commands.
	var assignedPos int
	err := b.ctx.DB.QueryRow(context.Background(),
		`INSERT INTO music_queues (server_id, title, url, requested_by, position, duration_seconds)
		 VALUES (
			$1, $2, $3, $4,
			(SELECT COALESCE(MAX(position), 0) + 1 FROM music_queues WHERE server_id = $1),
			$5
		 )
		 RETURNING position`,
		ctx.ServerID, title, trackURL, ctx.UserID, duration).Scan(&assignedPos)
	if err != nil {
		return nil, err
	}

	// Publish queue update event
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "queue_add", "title": title, "url": trackURL, "position": assignedPos},
	})

	return &commands.CommandResponse{
		Content: fmt.Sprintf("🎵 Added to queue: **%s** (Position #%d)", title, assignedPos),
	}, nil
}

func (b *MusicBot) handleSkip(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	// Remove the first item from queue
	var title string
	err := b.ctx.DB.QueryRow(context.Background(),
		`DELETE FROM music_queues WHERE id = (
			SELECT id FROM music_queues WHERE server_id = $1 ORDER BY position LIMIT 1
		) RETURNING title`,
		ctx.ServerID).Scan(&title)
	if err != nil {
		return &commands.CommandResponse{Content: "❌ Nothing to skip — queue is empty."}, nil
	}

	// Log to history
	b.ctx.DB.Exec(context.Background(),
		`INSERT INTO song_history (server_id, title, url, played_by) VALUES ($1, $2, '', $3)`,
		ctx.ServerID, title, ctx.UserID)

	// Publish skip event
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "skip", "title": title},
	})

	return &commands.CommandResponse{Content: fmt.Sprintf("⏭️ Skipped: **%s**", title)}, nil
}

func (b *MusicBot) handleQueue(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	pageFloat, _ := ctx.Options["page"].(float64)
	page := int(pageFloat)
	if page < 1 {
		page = 1
	}
	limit := 10
	offset := (page - 1) * limit

	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT title, url, duration_seconds, requested_by, position
		 FROM music_queues WHERE server_id = $1
		 ORDER BY position
		 LIMIT $2 OFFSET $3`,
		ctx.ServerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lines []string
	for rows.Next() {
		var title, url, requestedBy string
		var duration, position int
		if err := rows.Scan(&title, &url, &duration, &requestedBy, &position); err != nil {
			continue
		}
		durStr := formatDuration(duration)
		lines = append(lines, fmt.Sprintf("**%d.** %s `[%s]`", position, title, durStr))
	}

	if len(lines) == 0 {
		return &commands.CommandResponse{Content: "🎵 The queue is empty! Use `/play` to add songs."}, nil
	}

	var totalCount int
	b.ctx.DB.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM music_queues WHERE server_id = $1`, ctx.ServerID).Scan(&totalCount)

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       fmt.Sprintf("🎵 Queue (Page %d)", page),
			Description: strings.Join(lines, "\n"),
			Color:       "#1DB954",
			Footer:      fmt.Sprintf("%d songs in queue", totalCount),
		},
	}, nil
}

func (b *MusicBot) handleNowPlaying(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	var title, url string
	var duration int
	var requestedBy string

	err := b.ctx.DB.QueryRow(context.Background(),
		`SELECT title, url, duration_seconds, requested_by
		 FROM music_queues WHERE server_id = $1
		 ORDER BY position LIMIT 1`,
		ctx.ServerID).Scan(&title, &url, &duration, &requestedBy)
	if err != nil {
		return &commands.CommandResponse{Content: "🎵 Nothing is currently playing."}, nil
	}

	username := LookupUsername(b.ctx, requestedBy)
	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       "🎵 Now Playing",
			Description: fmt.Sprintf("**%s**\n`[%s]`\n\nRequested by: %s", title, formatDuration(duration), username),
			Color:       "#1DB954",
		},
	}, nil
}

func (b *MusicBot) handlePause(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "pause"},
	})
	return &commands.CommandResponse{Content: "⏸️ Playback paused."}, nil
}

func (b *MusicBot) handleResume(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "resume"},
	})
	return &commands.CommandResponse{Content: "▶️ Playback resumed."}, nil
}

func (b *MusicBot) handleStop(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	_, err := b.ctx.DB.Exec(context.Background(),
		`DELETE FROM music_queues WHERE server_id = $1`, ctx.ServerID)
	if err != nil {
		return nil, err
	}
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "stop"},
	})
	return &commands.CommandResponse{Content: "⏹️ Playback stopped and queue cleared."}, nil
}

func (b *MusicBot) handleShuffle(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	// Randomize positions
	_, err := b.ctx.DB.Exec(context.Background(),
		`UPDATE music_queues SET position = sub.new_pos
		 FROM (
			SELECT id, ROW_NUMBER() OVER (ORDER BY random()) as new_pos
			FROM music_queues WHERE server_id = $1
		 ) sub WHERE music_queues.id = sub.id`,
		ctx.ServerID)
	if err != nil {
		return nil, err
	}
	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "shuffle"},
	})
	return &commands.CommandResponse{Content: "🔀 Queue shuffled!"}, nil
}

func (b *MusicBot) handleRepeat(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	mode, _ := ctx.Options["mode"].(string)
	if mode != "off" && mode != "song" && mode != "queue" {
		return &commands.CommandResponse{Content: "❌ Mode must be: off, song, or queue", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`INSERT INTO music_settings (server_id, repeat_mode) VALUES ($1, $2)
		 ON CONFLICT (server_id) DO UPDATE SET repeat_mode = $2, updated_at = now()`,
		ctx.ServerID, mode)
	if err != nil {
		return nil, err
	}

	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "repeat", "mode": mode},
	})
	emoji := map[string]string{"off": "➡️", "song": "🔂", "queue": "🔁"}
	return &commands.CommandResponse{Content: fmt.Sprintf("%s Repeat mode: **%s**", emoji[mode], mode)}, nil
}

func (b *MusicBot) handleVolume(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ok, msg := b.requireDJ(ctx); !ok {
		return &commands.CommandResponse{Content: msg, Ephemeral: true}, nil
	}
	levelFloat, _ := ctx.Options["level"].(float64)
	level := int(levelFloat)
	if level < 0 || level > 100 {
		return &commands.CommandResponse{Content: "❌ Volume must be 0-100.", Ephemeral: true}, nil
	}

	_, err := b.ctx.DB.Exec(context.Background(),
		`INSERT INTO music_settings (server_id, default_volume) VALUES ($1, $2)
		 ON CONFLICT (server_id) DO UPDATE SET default_volume = $2, updated_at = now()`,
		ctx.ServerID, level)
	if err != nil {
		return nil, err
	}

	b.ctx.EventBus.Publish(events.Event{
		Type:     events.MusicUpdate,
		ServerID: ctx.ServerID,
		Data:     map[string]interface{}{"action": "volume", "level": level},
	})
	return &commands.CommandResponse{Content: fmt.Sprintf("🔊 Volume set to %d%%", level)}, nil
}

func (b *MusicBot) handlePlaylist(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	action, _ := ctx.Options["action"].(string)
	name, _ := ctx.Options["name"].(string)
	query, _ := ctx.Options["query"].(string)

	switch strings.ToLower(action) {
	case "create":
		if name == "" {
			return &commands.CommandResponse{Content: "❌ Provide a playlist name.", Ephemeral: true}, nil
		}
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO playlists (server_id, name, creator_id) VALUES ($1, $2, $3)`,
			ctx.ServerID, name, ctx.UserID)
		if err != nil {
			return &commands.CommandResponse{Content: "❌ Playlist already exists or error occurred.", Ephemeral: true}, nil
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Playlist **%s** created!", name)}, nil

	case "delete":
		_, err := b.ctx.DB.Exec(context.Background(),
			`DELETE FROM playlists WHERE server_id = $1 AND name = $2 AND creator_id = $3`,
			ctx.ServerID, name, ctx.UserID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("🗑️ Playlist **%s** deleted.", name)}, nil

	case "list":
		rows, err := b.ctx.DB.Query(context.Background(),
			`SELECT p.name, u.username, (SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = p.id)
			 FROM playlists p JOIN users u ON u.id = p.creator_id
			 WHERE p.server_id = $1
			 ORDER BY p.created_at`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var fields []commands.EmbedField
		for rows.Next() {
			var plName, creator string
			var trackCount int
			if err := rows.Scan(&plName, &creator, &trackCount); err != nil {
				continue
			}
			fields = append(fields, commands.EmbedField{
				Name:  plName,
				Value: fmt.Sprintf("%d tracks • by %s", trackCount, creator),
			})
		}
		if len(fields) == 0 {
			return &commands.CommandResponse{Content: "🎵 No playlists yet. Use `/playlist create <name>`."}, nil
		}
		return &commands.CommandResponse{
			Embed: &commands.Embed{
				Title:  "🎵 Playlists",
				Color:  "#1DB954",
				Fields: fields,
			},
		}, nil

	case "add":
		if name == "" || query == "" {
			return &commands.CommandResponse{Content: "❌ Provide playlist name and song.", Ephemeral: true}, nil
		}
		var playlistID string
		err := b.ctx.DB.QueryRow(context.Background(),
			`SELECT id FROM playlists WHERE server_id = $1 AND name = $2`,
			ctx.ServerID, name).Scan(&playlistID)
		if err != nil {
			return &commands.CommandResponse{Content: "❌ Playlist not found.", Ephemeral: true}, nil
		}
		var maxPos int
		b.ctx.DB.QueryRow(context.Background(),
			`SELECT COALESCE(MAX(position), 0) FROM playlist_tracks WHERE playlist_id = $1`,
			playlistID).Scan(&maxPos)

		_, err = b.ctx.DB.Exec(context.Background(),
			`INSERT INTO playlist_tracks (playlist_id, title, url, position, added_by)
			 VALUES ($1, $2, $3, $4, $5)`,
			playlistID, query, fmt.Sprintf("search:%s", query), maxPos+1, ctx.UserID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Added **%s** to playlist **%s**.", query, name)}, nil

	case "load":
		if name == "" {
			return &commands.CommandResponse{Content: "❌ Provide a playlist name.", Ephemeral: true}, nil
		}
		var playlistID string
		err := b.ctx.DB.QueryRow(context.Background(),
			`SELECT id FROM playlists WHERE server_id = $1 AND name = $2`,
			ctx.ServerID, name).Scan(&playlistID)
		if err != nil {
			return &commands.CommandResponse{Content: "❌ Playlist not found.", Ephemeral: true}, nil
		}

		// Load all tracks into queue
		var maxQueuePos int
		b.ctx.DB.QueryRow(context.Background(),
			`SELECT COALESCE(MAX(position), 0) FROM music_queues WHERE server_id = $1`,
			ctx.ServerID).Scan(&maxQueuePos)

		tag, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO music_queues (server_id, title, url, duration_seconds, requested_by, position)
			 SELECT $1, title, url, duration_seconds, $3, $2 + position
			 FROM playlist_tracks WHERE playlist_id = $4
			 ORDER BY position`,
			ctx.ServerID, maxQueuePos, ctx.UserID, playlistID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Loaded **%s** — %d tracks added to queue.", name, tag.RowsAffected())}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action. Use: create, delete, list, add, load", Ephemeral: true}, nil
	}
}

func (b *MusicBot) handleHistory(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	rows, err := b.ctx.DB.Query(context.Background(),
		`SELECT title, played_by, played_at FROM song_history
		 WHERE server_id = $1 ORDER BY played_at DESC LIMIT 10`,
		ctx.ServerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lines []string
	for rows.Next() {
		var title, playedBy string
		var playedAt time.Time
		if err := rows.Scan(&title, &playedBy, &playedAt); err != nil {
			continue
		}
		username := LookupUsername(b.ctx, playedBy)
		lines = append(lines, fmt.Sprintf("🎵 **%s** — played by %s at %s",
			title, username, playedAt.Format("15:04")))
	}

	if len(lines) == 0 {
		return &commands.CommandResponse{Content: "🎵 No song history yet."}, nil
	}

	return &commands.CommandResponse{
		Embed: &commands.Embed{
			Title:       "📜 Recently Played",
			Description: strings.Join(lines, "\n"),
			Color:       "#1DB954",
		},
	}, nil
}

func (b *MusicBot) handleMusicConfig(ctx commands.CommandContext) (*commands.CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}
	reqCtx, cancel := context.WithTimeout(ctx.Ctx, 15*time.Second)
	defer cancel()

	if !HasPermission(reqCtx, b.ctx, ctx.ServerID, ctx.UserID, PermManageGuild) {
		return &commands.CommandResponse{
			Content:   "❌ You need the Manage Server permission to configure the music bot.",
			Ephemeral: true,
		}, nil
	}

	action, _ := ctx.Options["action"].(string)

	switch strings.ToLower(action) {
	case "enable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO music_settings (server_id, enabled) VALUES ($1, true)
			 ON CONFLICT (server_id) DO UPDATE SET enabled = true, updated_at = now()`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "✅ Music bot enabled!"}, nil

	case "disable":
		_, err := b.ctx.DB.Exec(context.Background(),
			`UPDATE music_settings SET enabled = false, updated_at = now() WHERE server_id = $1`,
			ctx.ServerID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: "🔴 Music bot disabled."}, nil

	case "dj-role":
		roleID, _ := ctx.Options["role"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO music_settings (server_id, dj_role_id) VALUES ($1, $2)
			 ON CONFLICT (server_id) DO UPDATE SET dj_role_id = $2, updated_at = now()`,
			ctx.ServerID, roleID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ DJ role set to <@&%s>.", roleID)}, nil

	case "np-channel":
		channelID, _ := ctx.Options["channel"].(string)
		_, err := b.ctx.DB.Exec(context.Background(),
			`INSERT INTO music_settings (server_id, now_playing_channel_id) VALUES ($1, $2)
			 ON CONFLICT (server_id) DO UPDATE SET now_playing_channel_id = $2, updated_at = now()`,
			ctx.ServerID, channelID)
		if err != nil {
			return nil, err
		}
		return &commands.CommandResponse{Content: fmt.Sprintf("✅ Now-playing channel set to <#%s>.", channelID)}, nil

	default:
		return &commands.CommandResponse{Content: "❌ Unknown action.", Ephemeral: true}, nil
	}
}

// ── Helpers ─────────────────────────────────────────────────────────────────

// getUsername removed — use LookupUsername from helpers.go

func (b *MusicBot) resolveTrackMetadata(query string) (string, string, int) {
	if strings.HasPrefix(query, "http") {
		return query, query, 0
	}

	// Music search is handled client-side via JioSaavn/YouTube (Drip Bash).
	// The backend just stores the query for queue management.
	return query, "search:" + query, 0
}

func formatDuration(seconds int) string {
	if seconds <= 0 {
		return "Unknown"
	}
	m := seconds / 60
	s := seconds % 60
	if m >= 60 {
		h := m / 60
		m = m % 60
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%d:%02d", m, s)
}
