// Package pubsub provides Redis Pub/Sub integration for cross-gateway
// message fan-out in Flicko's WebSocket Gateway.
//
// Architecture:
//
//Redis Pub/Sub channel key: "ch:{channelID}"
//Redis typing key:          "typing:{channelID}"
//Redis presence key:        "presence:{guildID}"
//
//Publisher path (local message → other gateways):
//  client → manager.HandleInbound → pubsub.Publish → Redis
//
//Subscriber path (other gateways → local clients):
//  Redis → reader goroutine → workerChan → worker pool → manager.FanoutToChannel
package pubsub

import "context"

// EventBus is the abstraction over the message transport layer.
// RedisPubSub implements it today; NATSEventBus can implement it later.
type EventBus interface {
// Publish sends a message to the given topic (fire-and-forget semantics).
Publish(ctx context.Context, topic string, payload []byte) error

// Subscribe begins listening on the given topic.
// Received messages are delivered to the registered FanoutFunc.
Subscribe(ctx context.Context, topic string) error

// Unsubscribe stops listening on the given topic.
Unsubscribe(topic string) error

// Start initialises the worker pool and internal goroutines.
// Must be called before Subscribe.
Start(ctx context.Context) error

// Stop drains workers, closes all subscriptions, and releases resources.
Stop() error
}

// Compile-time interface check.
var _ EventBus = (*RedisPubSub)(nil)
