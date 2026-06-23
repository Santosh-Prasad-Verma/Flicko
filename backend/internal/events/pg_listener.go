// Package events — pg_listener.go
//
// CRIT-7: Bridges Postgres NOTIFY events into the in-process EventBus.
//
// When the mobile client (or any Supabase-direct writer) inserts into
// server_members, messages, or message_reactions, a Postgres trigger fires
// pg_notify('flicko_events', json_payload). This listener receives those
// notifications and publishes the corresponding EventBus event so bots
// (welcome, automod, leveling, starboard) can react.
//
// Requires the companion migration that installs the triggers.
package events

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const pgChannel = "flicko_events"

// PgNotifyPayload is the JSON structure emitted by the Postgres trigger.
type PgNotifyPayload struct {
	Event     string                 `json:"event"`      // e.g. "MESSAGE_CREATE"
	ServerID  string                 `json:"server_id"`
	ChannelID string                 `json:"channel_id"`
	UserID    string                 `json:"user_id"`
	Data      map[string]interface{} `json:"data"`
}

// PgListener listens on a Postgres NOTIFY channel and republishes events
// into the EventBus.
type PgListener struct {
	pool          *pgxpool.Pool
	bus           *EventBus
	logger        *zap.Logger
	lastEventTime time.Time
	processedMu   sync.Mutex
	processedKeys map[string]time.Time
}

// NewPgListener creates a new Postgres LISTEN bridge.
func NewPgListener(pool *pgxpool.Pool, bus *EventBus, logger *zap.Logger) *PgListener {
	return &PgListener{
		pool:          pool,
		bus:           bus,
		logger:        logger.Named("events.pg_listener"),
		lastEventTime: time.Now(),
		processedKeys: make(map[string]time.Time),
	}
}

// Start begins listening. It blocks until ctx is cancelled. Run in a goroutine.
func (l *PgListener) Start(ctx context.Context) {
	for {
		if ctx.Err() != nil {
			return
		}
		if err := l.listen(ctx); err != nil {
			l.logger.Error("pg listener error, reconnecting in 2s", zap.Error(err))
			select {
			case <-ctx.Done():
				return
			case <-time.After(2 * time.Second):
			}
		}
	}
}

func (l *PgListener) listen(ctx context.Context) error {
	conn, err := l.pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()

	if _, err := conn.Exec(ctx, "LISTEN "+pgChannel); err != nil {
		return err
	}

	l.logger.Info("pg listener started", zap.String("channel", pgChannel))

	// Recover missed events asynchronously to not block the main notification loop
	go l.recoverMissedEvents(ctx)

	for {
		notification, err := conn.Conn().WaitForNotification(ctx)
		if err != nil {
			return err
		}

		var payload PgNotifyPayload
		if err := json.Unmarshal([]byte(notification.Payload), &payload); err != nil {
			l.logger.Warn("pg notify: invalid JSON payload", zap.Error(err))
			continue
		}

		evt := Event{
			Type:      EventType(payload.Event),
			ServerID:  payload.ServerID,
			ChannelID: payload.ChannelID,
			UserID:    payload.UserID,
			Data:      payload.Data,
			Timestamp: time.Now(),
		}

		l.processedMu.Lock()
		l.lastEventTime = time.Now()
		l.processedMu.Unlock()

		if l.dedupEvent(evt) {
			l.bus.Publish(evt)
		}
	}
}

func (l *PgListener) dedupEvent(evt Event) bool {
	l.processedMu.Lock()
	defer l.processedMu.Unlock()

	var key string
	switch evt.Type {
	case "MESSAGE_CREATE", "MESSAGE_UPDATE", "MESSAGE_DELETE":
		if msgID, ok := evt.Data["message_id"].(string); ok && msgID != "" {
			key = "msg:" + msgID
		} else {
			key = fmt.Sprintf("msg:%s:%s:%d", evt.ServerID, evt.UserID, evt.Timestamp.UnixNano())
		}
	case "REACTION_ADD", "REACTION_REMOVE":
		msgID, _ := evt.Data["message_id"].(string)
		emoji, _ := evt.Data["emoji"].(string)
		key = fmt.Sprintf("react:%s:%s:%s", msgID, evt.UserID, emoji)
	default:
		key = fmt.Sprintf("generic:%s:%s:%s", evt.Type, evt.ServerID, evt.UserID)
	}

	if _, exists := l.processedKeys[key]; exists {
		return false // duplicate
	}

	// Clean up old keys if the map gets too big (e.g. > 5000 items)
	now := time.Now()
	if len(l.processedKeys) > 5000 {
		for k, t := range l.processedKeys {
			if now.Sub(t) > 10*time.Minute {
				delete(l.processedKeys, k)
			}
		}
	}

	l.processedKeys[key] = now
	return true
}

func (l *PgListener) recoverMissedEvents(ctx context.Context) {
	l.processedMu.Lock()
	since := l.lastEventTime
	l.processedMu.Unlock()

	// Use a 5-second buffer to handle database write race conditions
	since = since.Add(-5 * time.Second)

	l.logger.Info("recovering missed events", zap.Time("since", since))

	maxTime := since

	// 1. Recover member joins/leaves
	memberQuery := `
		SELECT server_id, user_id, joined_at
		FROM server_members
		WHERE joined_at > $1
		ORDER BY joined_at ASC
	`
	memberRows, err := l.pool.Query(ctx, memberQuery, since)
	if err == nil {
		defer memberRows.Close()
		for memberRows.Next() {
			var serverID, userID string
			var joinedAt time.Time
			if err := memberRows.Scan(&serverID, &userID, &joinedAt); err == nil {
				if joinedAt.After(maxTime) {
					maxTime = joinedAt
				}
				evt := Event{
					Type:      "MEMBER_JOIN",
					ServerID:  serverID,
					UserID:    userID,
					Timestamp: joinedAt,
					Data:      map[string]interface{}{},
				}
				if l.dedupEvent(evt) {
					l.bus.Publish(evt)
				}
			}
		}
	}

	// 2. Recover messages
	messageQuery := `
		SELECT m.id, m.channel_id, m.author_id, m.content, m.created_at, c.server_id
		FROM messages m
		JOIN channels c ON c.id = m.channel_id
		WHERE m.created_at > $1
		ORDER BY m.created_at ASC
	`
	messageRows, err := l.pool.Query(ctx, messageQuery, since)
	if err == nil {
		defer messageRows.Close()
		for messageRows.Next() {
			var id, channelID, authorID, content string
			var createdAt time.Time
			var serverID *string
			if err := messageRows.Scan(&id, &channelID, &authorID, &content, &createdAt, &serverID); err == nil {
				if createdAt.After(maxTime) {
					maxTime = createdAt
				}
				srvID := ""
				if serverID != nil {
					srvID = *serverID
				}
				evt := Event{
					Type:      "MESSAGE_CREATE",
					ServerID:  srvID,
					ChannelID: channelID,
					UserID:    authorID,
					Timestamp: createdAt,
					Data: map[string]interface{}{
						"message_id": id,
						"content":    content,
						"author_id":  authorID,
					},
				}
				if l.dedupEvent(evt) {
					l.bus.Publish(evt)
				}
			}
		}
	}

	// 3. Recover reactions
	reactionQuery := `
		SELECT r.message_id, r.user_id, r.emoji, r.created_at, m.channel_id, c.server_id
		FROM reactions r
		JOIN messages m ON m.id = r.message_id
		JOIN channels c ON c.id = m.channel_id
		WHERE r.created_at > $1
		ORDER BY r.created_at ASC
	`
	reactionRows, err := l.pool.Query(ctx, reactionQuery, since)
	if err == nil {
		defer reactionRows.Close()
		for reactionRows.Next() {
			var messageID, userID, emoji, channelID string
			var createdAt time.Time
			var serverID *string
			if err := reactionRows.Scan(&messageID, &userID, &emoji, &createdAt, &channelID, &serverID); err == nil {
				if createdAt.After(maxTime) {
					maxTime = createdAt
				}
				srvID := ""
				if serverID != nil {
					srvID = *serverID
				}
				evt := Event{
					Type:      "REACTION_ADD",
					ServerID:  srvID,
					ChannelID: channelID,
					UserID:    userID,
					Timestamp: createdAt,
					Data: map[string]interface{}{
						"message_id": messageID,
						"emoji":      emoji,
					},
				}
				if l.dedupEvent(evt) {
					l.bus.Publish(evt)
				}
			}
		}
	}

	l.processedMu.Lock()
	if maxTime.After(l.lastEventTime) {
		l.lastEventTime = maxTime
	}
	l.processedMu.Unlock()
}
