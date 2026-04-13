// Package pubsub publishes domain events to Redis Pub/Sub for
// cross-gateway fanout. The msg-service is the single source of truth
// for message persistence, so it publishes events AFTER writing to
// PostgreSQL. WS-gateway instances subscribe and fan out to local
// WebSocket clients.
//
// Topic naming:
//
//	rt:channel:{channelID}  — channel messages
//	rt:dm:{channelID}       — DM messages
//	rt:typing:{channelID}   — typing indicators (via gateway)
//	rt:presence:{guildID}   — presence updates (via gateway)
package pubsub

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// Topic prefixes matching the ws-gateway subscriber expectations.
const (
	PrefixChannel  = "rt:channel:"
	PrefixDM       = "rt:dm:"
	PrefixTyping   = "rt:typing:"
	PrefixPresence = "rt:presence:"
)

// EventType constants for published events.
const (
	EventMessageCreated = "message.created"
	EventMessageUpdated = "message.updated"
	EventMessageDeleted = "message.deleted"
)

// MessageEvent is the slim payload published to Redis after a DB write.
// Keep it small — clients fetch full message content via REST if needed.
type MessageEvent struct {
	Type      string `json:"type"`
	ChannelID string `json:"channel_id"`
	MessageID string `json:"message_id"`
	AuthorID  string `json:"author_id"`
	CreatedAt string `json:"created_at"`
}

// Publisher publishes domain events to Redis Pub/Sub for cross-gateway
// fanout. Thread-safe (go-redis client is safe for concurrent use).
type Publisher struct {
	rdb *goredis.Client
	log *zap.Logger
}

// NewPublisher creates a Publisher.
func NewPublisher(rdb *goredis.Client, log *zap.Logger) *Publisher {
	return &Publisher{
		rdb: rdb,
		log: log.Named("pubsub.publisher"),
	}
}

// PublishMessageCreated publishes a message.created event after the
// message has been persisted to PostgreSQL. This is the primary path
// for realtime delivery to all WS-gateway instances.
func (p *Publisher) PublishMessageCreated(ctx context.Context, channelID, messageID, authorID string, createdAt time.Time, isDM bool) error {
	evt := MessageEvent{
		Type:      EventMessageCreated,
		ChannelID: channelID,
		MessageID: messageID,
		AuthorID:  authorID,
		CreatedAt: createdAt.Format(time.RFC3339Nano),
	}
	return p.publish(ctx, channelID, isDM, evt)
}

// PublishMessageUpdated publishes a message.updated event after an edit.
func (p *Publisher) PublishMessageUpdated(ctx context.Context, channelID, messageID, authorID string, isDM bool) error {
	evt := MessageEvent{
		Type:      EventMessageUpdated,
		ChannelID: channelID,
		MessageID: messageID,
		AuthorID:  authorID,
		CreatedAt: time.Now().Format(time.RFC3339Nano),
	}
	return p.publish(ctx, channelID, isDM, evt)
}

// PublishMessageDeleted publishes a message.deleted event after a soft-delete.
func (p *Publisher) PublishMessageDeleted(ctx context.Context, channelID, messageID, authorID string, isDM bool) error {
	evt := MessageEvent{
		Type:      EventMessageDeleted,
		ChannelID: channelID,
		MessageID: messageID,
		AuthorID:  authorID,
		CreatedAt: time.Now().Format(time.RFC3339Nano),
	}
	return p.publish(ctx, channelID, isDM, evt)
}

// publish serialises the event and publishes to the appropriate Redis topic.
func (p *Publisher) publish(ctx context.Context, channelID string, isDM bool, evt MessageEvent) error {
	data, err := json.Marshal(evt)
	if err != nil {
		return fmt.Errorf("pubsub: marshal event: %w", err)
	}

	// Choose topic prefix based on DM vs channel.
	prefix := PrefixChannel
	if isDM {
		prefix = PrefixDM
	}
	topic := prefix + channelID

	if err := p.rdb.Publish(ctx, topic, data).Err(); err != nil {
		p.log.Error("publish failed",
			zap.String("topic", topic),
			zap.String("type", evt.Type),
			zap.Error(err),
		)
		return fmt.Errorf("pubsub: publish to %s: %w", topic, err)
	}

	p.log.Debug("event published",
		zap.String("topic", topic),
		zap.String("type", evt.Type),
		zap.String("message_id", evt.MessageID),
	)
	return nil
}
