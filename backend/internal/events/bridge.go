package events

import (
	"context"
	"encoding/json"

	"github.com/flicko-org/flicko-backend/internal/database"
	"go.uber.org/zap"
)

// Bridge handles syncing internal events to external systems (e.g. Supabase Realtime).
type Bridge struct {
	db     database.DatabaseClient
	bus    *EventBus
	logger *zap.Logger
}

// NewBridge creates a new event bridge.
func NewBridge(db database.DatabaseClient, bus *EventBus, logger *zap.Logger) *Bridge {
	return &Bridge{
		db:     db,
		bus:    bus,
		logger: logger,
	}
}

// Start registers the bridge as a subscriber to the event bus.
func (b *Bridge) Start() {
	// Subscribe to events that should be broadcast to clients via Realtime
	clientEvents := []EventType{
		MusicUpdate,
		VoiceJoin,
		VoiceLeave,
		VideoToggle,
		ScreenShareToggle,
	}

	b.bus.SubscribeMany(clientEvents, "bridge.supabase", b.handleClientEvent)
}

func (b *Bridge) handleClientEvent(evt Event) error {
	// Skip events without a server ID
	if evt.ServerID == "" {
		return nil
	}

	// Determine bot name based on event type
	botName := "system"
	switch evt.Type {
	case MusicUpdate:
		botName = "music"
	case VoiceJoin, VoiceLeave, VideoToggle, ScreenShareToggle:
		botName = "voice"
	}

	dataJSON, err := json.Marshal(evt.Data)
	if err != nil {
		b.logger.Error("failed to marshal event data", zap.Error(err))
		return err
	}

	_, err = b.db.Exec(context.Background(),
		`INSERT INTO bot_events (server_id, bot_name, event_type, data) VALUES ($1, $2, $3, $4)`,
		evt.ServerID, botName, string(evt.Type), dataJSON)
	if err != nil {
		b.logger.Error("failed to persist bot event", zap.Error(err))
		return err
	}

	return nil
}
