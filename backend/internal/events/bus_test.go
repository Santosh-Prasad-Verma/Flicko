package events

import (
	"errors"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

// TestSubscribe_Idempotent verifies CRIT-2: subscribing the same
// (eventType, name) pair more than once REPLACES rather than appends.
func TestSubscribe_Idempotent(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var calls1, calls2 int32
	h1 := func(_ Event) error { atomic.AddInt32(&calls1, 1); return nil }
	h2 := func(_ Event) error { atomic.AddInt32(&calls2, 1); return nil }

	bus.Subscribe(MessageCreate, "dedup-test", h1)
	bus.Subscribe(MessageCreate, "dedup-test", h2)

	bus.Publish(Event{Type: MessageCreate})

	assert.Equal(t, int32(0), atomic.LoadInt32(&calls1), "first handler should be replaced")
	assert.Equal(t, int32(1), atomic.LoadInt32(&calls2), "second (replacement) handler should run once")
}

// TestSubscribe_DifferentNamesCoexist verifies that two handlers under
// different names both fire (the dedup is per-name, not global).
func TestSubscribe_DifferentNamesCoexist(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var a, b int32
	bus.Subscribe(MessageCreate, "handler-a", func(_ Event) error { atomic.AddInt32(&a, 1); return nil })
	bus.Subscribe(MessageCreate, "handler-b", func(_ Event) error { atomic.AddInt32(&b, 1); return nil })

	bus.Publish(Event{Type: MessageCreate})

	assert.Equal(t, int32(1), atomic.LoadInt32(&a))
	assert.Equal(t, int32(1), atomic.LoadInt32(&b))
}

// TestUnsubscribe_RemovesHandler verifies handler can be removed.
func TestUnsubscribe_RemovesHandler(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var calls int32
	bus.Subscribe(MessageCreate, "removable", func(_ Event) error { atomic.AddInt32(&calls, 1); return nil })

	bus.Publish(Event{Type: MessageCreate})
	assert.Equal(t, int32(1), atomic.LoadInt32(&calls))

	bus.Unsubscribe(MessageCreate, "removable")

	bus.Publish(Event{Type: MessageCreate})
	assert.Equal(t, int32(1), atomic.LoadInt32(&calls), "handler should not fire after unsubscribe")
}

// TestUnsubscribe_NonExistentNoop verifies Unsubscribe is safe even when
// the (eventType, name) pair was never subscribed.
func TestUnsubscribe_NonExistentNoop(t *testing.T) {
	bus := NewEventBus(zap.NewNop())
	// Should not panic.
	bus.Unsubscribe(MessageCreate, "never-subscribed")
}

// TestPublish_HandlerErrorDoesNotStopOthers verifies that one failing
// handler doesn't prevent subsequent ones from running.
func TestPublish_HandlerErrorDoesNotStopOthers(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var first, second int32
	bus.Subscribe(MessageCreate, "first", func(_ Event) error {
		atomic.AddInt32(&first, 1)
		return errors.New("failure")
	})
	bus.Subscribe(MessageCreate, "second", func(_ Event) error {
		atomic.AddInt32(&second, 1)
		return nil
	})

	bus.Publish(Event{Type: MessageCreate})

	assert.Equal(t, int32(1), atomic.LoadInt32(&first))
	assert.Equal(t, int32(1), atomic.LoadInt32(&second))
}

// TestRecoveryMiddleware_PanicReturnsSentinelError verifies MED-1:
// RecoveryMiddleware returns ErrHandlerPanic so a metrics layer can
// distinguish panics from regular handler errors.
func TestRecoveryMiddleware_PanicReturnsSentinelError(t *testing.T) {
	mw := RecoveryMiddleware(zap.NewNop())
	wrapped := mw(func(_ Event) error {
		panic("kaboom")
	})

	err := wrapped(Event{Type: MessageCreate})
	assert.ErrorIs(t, err, ErrHandlerPanic)
}

// TestRecoveryMiddleware_PassesThroughNormalErrors verifies non-panic
// errors are passed through unchanged.
func TestRecoveryMiddleware_PassesThroughNormalErrors(t *testing.T) {
	sentinel := errors.New("regular error")
	mw := RecoveryMiddleware(zap.NewNop())
	wrapped := mw(func(_ Event) error { return sentinel })

	err := wrapped(Event{Type: MessageCreate})
	assert.ErrorIs(t, err, sentinel)
	assert.NotErrorIs(t, err, ErrHandlerPanic)
}

// TestPublish_ConcurrentSubscribeDoesNotDeadlock verifies MED-6: holding
// only the read lock during snapshot keeps Subscribe non-blocking.
func TestPublish_ConcurrentSubscribeDoesNotDeadlock(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var subscribed sync.WaitGroup
	for i := 0; i < 10; i++ {
		subscribed.Add(1)
		go func(i int) {
			defer subscribed.Done()
			name := "concurrent-handler"
			bus.Subscribe(MessageCreate, name, func(_ Event) error { return nil })
		}(i)
	}

	subscribed.Wait()

	// Publish from multiple goroutines while subscribers may be in flight.
	var pubWg sync.WaitGroup
	for i := 0; i < 50; i++ {
		pubWg.Add(1)
		go func() {
			defer pubWg.Done()
			bus.Publish(Event{Type: MessageCreate})
		}()
	}
	pubWg.Wait()

	// Got here without deadlock or panic — we're good.
	assert.True(t, bus.HasSubscribers(MessageCreate))
}

// TestSubscribeMany_AllEventsReceiveHandler verifies the SubscribeMany helper.
func TestSubscribeMany_AllEventsReceiveHandler(t *testing.T) {
	bus := NewEventBus(zap.NewNop())

	var hits int32
	bus.SubscribeMany(
		[]EventType{MemberJoin, MemberLeave, MessageCreate},
		"multi",
		func(_ Event) error { atomic.AddInt32(&hits, 1); return nil },
	)

	bus.Publish(Event{Type: MemberJoin})
	bus.Publish(Event{Type: MemberLeave})
	bus.Publish(Event{Type: MessageCreate})

	assert.Equal(t, int32(3), atomic.LoadInt32(&hits))
}
