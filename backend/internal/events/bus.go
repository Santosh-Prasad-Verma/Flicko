package events

import (
	"context"
	"sync"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
)

// Handler is a function that processes an event.
// Return an error to signal processing failure (logged, not fatal).
type Handler func(evt Event) error

// HandlerEntry stores a handler with its subscriber name for logging.
type HandlerEntry struct {
	Name    string
	Handler Handler
}

// EventBus is a publish-subscribe event dispatcher.
// Bots subscribe to event types; the backend publishes events into the bus.
type EventBus struct {
	mu          sync.RWMutex
	subscribers map[EventType][]HandlerEntry
	middleware  []Middleware
	logger      *zap.Logger
}

// Middleware wraps a Handler, allowing pre/post processing.
type Middleware func(next Handler) Handler

// NewEventBus creates a new event bus.
func NewEventBus(logger *zap.Logger) *EventBus {
	return &EventBus{
		subscribers: make(map[EventType][]HandlerEntry),
		logger:      logger,
	}
}

// Use adds middleware that wraps every handler.
func (eb *EventBus) Use(mw Middleware) {
	eb.mu.Lock()
	defer eb.mu.Unlock()
	eb.middleware = append(eb.middleware, mw)
}

// Subscribe registers a named handler for a specific event type.
//
// Idempotency: subscribing the same (eventType, name) pair more than once
// REPLACES the previous handler instead of appending. This prevents duplicate
// dispatch when a bot is re-registered (e.g. after a panic-and-recover loop).
func (eb *EventBus) Subscribe(eventType EventType, name string, h Handler) {
	eb.mu.Lock()
	defer eb.mu.Unlock()

	list := eb.subscribers[eventType]
	for i, e := range list {
		if e.Name == name {
			list[i].Handler = h
			eb.logger.Debug("handler re-subscribed (replaced)",
				zap.String("event", string(eventType)),
				zap.String("handler", name),
			)
			return
		}
	}
	eb.subscribers[eventType] = append(list, HandlerEntry{
		Name:    name,
		Handler: h,
	})
	eb.logger.Debug("handler subscribed",
		zap.String("event", string(eventType)),
		zap.String("handler", name),
	)
}

// Unsubscribe removes a handler by (eventType, name). Safe to call even
// if the handler is not present (no-op).
func (eb *EventBus) Unsubscribe(eventType EventType, name string) {
	eb.mu.Lock()
	defer eb.mu.Unlock()

	list := eb.subscribers[eventType]
	for i, e := range list {
		if e.Name == name {
			eb.subscribers[eventType] = append(list[:i], list[i+1:]...)
			return
		}
	}
}

// Publish dispatches an event to all subscribed handlers.
// Errors are logged but do not stop other handlers from executing.
//
// MED-6: We snapshot subscribers and middleware under the read lock so
// long-running handlers don't block Subscribe(). The snapshot is allocated
// once per publish; under steady-state load this is ~tens of bytes.
//
// LOW-3: An OTel span is started per publish so handler latency / errors
// surface in distributed traces. Per-handler spans are nested inside.
func (eb *EventBus) Publish(evt Event) {
	tracer := otel.GetTracerProvider().Tracer("flicko/events")
	ctx, span := tracer.Start(context.Background(), "EventBus.Publish",
		trace.WithAttributes(
			attribute.String("event.type", string(evt.Type)),
			attribute.String("server_id", evt.ServerID),
			attribute.String("channel_id", evt.ChannelID),
		),
	)
	defer span.End()

	eb.mu.RLock()
	srcEntries := eb.subscribers[evt.Type]
	srcMws := eb.middleware
	entries := append([]HandlerEntry(nil), srcEntries...)
	mws := append([]Middleware(nil), srcMws...)
	eb.mu.RUnlock()

	for _, entry := range entries {
		_, hSpan := tracer.Start(ctx, "EventBus.Handler",
			trace.WithAttributes(
				attribute.String("handler", entry.Name),
				attribute.String("event.type", string(evt.Type)),
			),
		)

		handler := entry.Handler
		// Apply middleware in reverse order (outermost first).
		for i := len(mws) - 1; i >= 0; i-- {
			handler = mws[i](handler)
		}

		if err := handler(evt); err != nil {
			eb.logger.Error("event handler error",
				zap.String("event", string(evt.Type)),
				zap.String("handler", entry.Name),
				zap.String("server_id", evt.ServerID),
				zap.Error(err),
			)
			hSpan.RecordError(err)
		}
		hSpan.End()
	}
}

// SubscribeMany registers a handler for multiple event types.
func (eb *EventBus) SubscribeMany(types []EventType, name string, h Handler) {
	for _, t := range types {
		eb.Subscribe(t, name, h)
	}
}

// HasSubscribers returns true if any handler is registered for the given type.
func (eb *EventBus) HasSubscribers(eventType EventType) bool {
	eb.mu.RLock()
	defer eb.mu.RUnlock()
	return len(eb.subscribers[eventType]) > 0
}
