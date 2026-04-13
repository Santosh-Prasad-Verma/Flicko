package events

import (
	"sync"

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
func (eb *EventBus) Subscribe(eventType EventType, name string, h Handler) {
	eb.mu.Lock()
	defer eb.mu.Unlock()
	eb.subscribers[eventType] = append(eb.subscribers[eventType], HandlerEntry{
		Name:    name,
		Handler: h,
	})
	eb.logger.Debug("handler subscribed",
		zap.String("event", string(eventType)),
		zap.String("handler", name),
	)
}

// Publish dispatches an event to all subscribed handlers.
// Errors are logged but do not stop other handlers from executing.
func (eb *EventBus) Publish(evt Event) {
	eb.mu.RLock()
	entries := make([]HandlerEntry, len(eb.subscribers[evt.Type]))
	copy(entries, eb.subscribers[evt.Type])
	mws := make([]Middleware, len(eb.middleware))
	copy(mws, eb.middleware)
	eb.mu.RUnlock()

	for _, entry := range entries {
		handler := entry.Handler

		// Apply middleware in reverse order (outermost first)
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
		}
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
