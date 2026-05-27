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
	pool   *pgxpool.Pool
	bus    *EventBus
	logger *zap.Logger
}

// NewPgListener creates a new Postgres LISTEN bridge.
func NewPgListener(pool *pgxpool.Pool, bus *EventBus, logger *zap.Logger) *PgListener {
	return &PgListener{
		pool:   pool,
		bus:    bus,
		logger: logger.Named("events.pg_listener"),
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

		l.bus.Publish(evt)
	}
}
