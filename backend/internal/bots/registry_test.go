package bots

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

// stubBot lets us assert how many times Register/Shutdown/Run are invoked.
type stubBot struct {
	name        string
	registers   int32
	shutdowns   int32
	runs        int32
	registerErr error
	runFn       func(ctx context.Context) error
}

func (s *stubBot) Name() string { return s.name }

func (s *stubBot) Register(_ BotContext) error {
	atomic.AddInt32(&s.registers, 1)
	return s.registerErr
}

func (s *stubBot) Shutdown() error {
	atomic.AddInt32(&s.shutdowns, 1)
	return nil
}

// runnableStubBot embeds stubBot and implements the optional RunnableBot interface.
type runnableStubBot struct {
	stubBot
}

func (r *runnableStubBot) Run(ctx context.Context) error {
	atomic.AddInt32(&r.runs, 1)
	if r.runFn != nil {
		return r.runFn(ctx)
	}
	<-ctx.Done()
	return nil
}

// TestRegistry_RegisterCalledExactlyOnce verifies CRIT-1: bots are no longer
// re-registered every 2 seconds in an unbounded loop.
func TestRegistry_RegisterCalledExactlyOnce(t *testing.T) {
	logger := zap.NewNop()
	bus := events.NewEventBus(logger)
	bctx := BotContext{EventBus: bus, Logger: logger}

	reg := NewRegistry(bctx)
	bot := &stubBot{name: "test-bot"}
	reg.Add(bot)

	if err := reg.StartAll(); err != nil {
		t.Fatalf("StartAll: %v", err)
	}

	// Wait long enough that the OLD code would have re-registered ~3 times.
	time.Sleep(7 * time.Second)

	got := atomic.LoadInt32(&bot.registers)
	assert.Equal(t, int32(1), got, "Register should be called exactly once, was called %d times", got)

	reg.ShutdownAll()
	assert.Equal(t, int32(1), atomic.LoadInt32(&bot.shutdowns))
}

// TestRegistry_RunnableBotPanicRecovers verifies that a panicking Run loop
// is restarted with backoff rather than crashing the process.
func TestRegistry_RunnableBotPanicRecovers(t *testing.T) {
	logger := zap.NewNop()
	bus := events.NewEventBus(logger)
	bctx := BotContext{EventBus: bus, Logger: logger}

	reg := NewRegistry(bctx)

	var calls int32
	bot := &runnableStubBot{
		stubBot: stubBot{name: "panicking-bot"},
	}
	bot.runFn = func(ctx context.Context) error {
		n := atomic.AddInt32(&calls, 1)
		if n < 3 {
			panic("boom")
		}
		<-ctx.Done()
		return nil
	}
	reg.Add(bot)

	if err := reg.StartAll(); err != nil {
		t.Fatalf("StartAll: %v", err)
	}

	// Each panic backs off 1s, 2s. By 5s we should have seen at least 3 calls.
	time.Sleep(5 * time.Second)

	got := atomic.LoadInt32(&calls)
	assert.GreaterOrEqual(t, got, int32(3),
		"runFn should have been called at least 3 times after panics; got %d", got)

	reg.ShutdownAll()
}

// TestRegistry_RunReturnsCleanlyDoesNotRestart verifies that a Run that
// returns nil (clean shutdown signal) is NOT restarted.
func TestRegistry_RunReturnsCleanlyDoesNotRestart(t *testing.T) {
	logger := zap.NewNop()
	bus := events.NewEventBus(logger)
	bctx := BotContext{EventBus: bus, Logger: logger}

	reg := NewRegistry(bctx)

	var calls int32
	bot := &runnableStubBot{
		stubBot: stubBot{name: "clean-bot"},
	}
	bot.runFn = func(ctx context.Context) error {
		atomic.AddInt32(&calls, 1)
		return nil // clean exit
	}
	reg.Add(bot)

	_ = reg.StartAll()
	time.Sleep(2 * time.Second)

	assert.Equal(t, int32(1), atomic.LoadInt32(&calls),
		"clean-exit Run should not be restarted")

	reg.ShutdownAll()
}

// TestRegistry_RegisterErrorIsSurfacedNotMasked verifies that register errors
// stop StartAll instead of being silently retried.
func TestRegistry_RegisterErrorIsSurfacedNotMasked(t *testing.T) {
	logger := zap.NewNop()
	bus := events.NewEventBus(logger)
	bctx := BotContext{EventBus: bus, Logger: logger}

	reg := NewRegistry(bctx)
	bot := &stubBot{name: "broken-bot", registerErr: errors.New("config invalid")}
	reg.Add(bot)

	err := reg.StartAll()
	assert.Error(t, err, "StartAll should propagate register errors")
	assert.Equal(t, int32(1), atomic.LoadInt32(&bot.registers))
}
