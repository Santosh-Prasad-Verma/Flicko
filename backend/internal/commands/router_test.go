package commands

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

// TestRouter_RegisterReplacesNotAppends verifies HIGH-1: re-registering the
// same command name REPLACES (rather than appending) so the definitions
// list doesn't grow unboundedly.
func TestRouter_RegisterReplacesNotAppends(t *testing.T) {
	r := NewRouter(zap.NewNop())

	def := CommandDefinition{Name: "ban", Description: "first"}
	r.Register(def, func(_ CommandContext) (*CommandResponse, error) {
		return &CommandResponse{Content: "first"}, nil
	})

	def2 := CommandDefinition{Name: "ban", Description: "second"}
	r.Register(def2, func(_ CommandContext) (*CommandResponse, error) {
		return &CommandResponse{Content: "second"}, nil
	})

	defs := r.GetDefinitions()
	assert.Len(t, defs, 1, "duplicate registration should not append")
	assert.Equal(t, "second", defs[0].Description, "second definition should win")

	// Run it: should hit the second handler.
	resp, err := r.Dispatch(CommandContext{Command: "ban", Ctx: context.Background()})
	assert.NoError(t, err)
	assert.Equal(t, "second", resp.Content)
}

// TestRouter_DispatchUnknownCommand returns ErrUnknownCommand so callers can
// distinguish "no such command" from "handler returned an error".
func TestRouter_DispatchUnknownCommand(t *testing.T) {
	r := NewRouter(zap.NewNop())
	_, err := r.Dispatch(CommandContext{Command: "nope", Ctx: context.Background()})
	assert.ErrorIs(t, err, ErrUnknownCommand)
}

// TestRouter_DispatchPropagatesHandlerError shows that handler errors flow
// back to the caller.
func TestRouter_DispatchPropagatesHandlerError(t *testing.T) {
	r := NewRouter(zap.NewNop())
	sentinel := errors.New("boom")
	r.Register(CommandDefinition{Name: "kick"}, func(_ CommandContext) (*CommandResponse, error) {
		return nil, sentinel
	})

	_, err := r.Dispatch(CommandContext{Command: "kick", Ctx: context.Background()})
	assert.ErrorIs(t, err, sentinel)
}

// TestRouter_HandleEventDoesNotExecute verifies CRIT-8: the event-bus
// subscriber is now a no-op for observability only. Combined with
// BotHandler.InvokeCommand calling Dispatch, this prevents double-execution.
func TestRouter_HandleEventDoesNotExecute(t *testing.T) {
	r := NewRouter(zap.NewNop())

	var calls int32
	r.Register(CommandDefinition{Name: "purge"}, func(_ CommandContext) (*CommandResponse, error) {
		atomic.AddInt32(&calls, 1)
		return &CommandResponse{}, nil
	})

	evt := events.Event{
		Type: events.CommandInvoke,
		Data: map[string]interface{}{
			"command_name":   "purge",
			"interaction_id": "abc-123",
		},
	}

	err := r.HandleEvent(evt)
	assert.NoError(t, err)

	// The handler MUST NOT be invoked through the bus subscriber path.
	assert.Equal(t, int32(0), atomic.LoadInt32(&calls),
		"router.HandleEvent must not dispatch — that's now BotHandler's job")
}

// TestRouter_DispatchEnsuresNonNilContext verifies CRIT-11: a CommandContext
// with a nil Ctx field gets a default context.Background() so handlers
// downstream can call context.WithTimeout safely.
func TestRouter_DispatchEnsuresNonNilContext(t *testing.T) {
	r := NewRouter(zap.NewNop())

	var sawCtx context.Context
	r.Register(CommandDefinition{Name: "ping"}, func(c CommandContext) (*CommandResponse, error) {
		sawCtx = c.Ctx
		return &CommandResponse{}, nil
	})

	_, err := r.Dispatch(CommandContext{Command: "ping"}) // Ctx omitted
	assert.NoError(t, err)
	assert.NotNil(t, sawCtx, "Dispatch should default Ctx to context.Background()")
}

// TestRouter_SubCommandDispatch verifies the parent/sub key resolution.
func TestRouter_SubCommandDispatch(t *testing.T) {
	r := NewRouter(zap.NewNop())

	r.Register(CommandDefinition{Name: "ticket"}, func(_ CommandContext) (*CommandResponse, error) {
		return &CommandResponse{Content: "parent"}, nil
	})
	r.RegisterSub("ticket", "close", func(_ CommandContext) (*CommandResponse, error) {
		return &CommandResponse{Content: "sub"}, nil
	})

	resp, err := r.Dispatch(CommandContext{
		Command:    "ticket",
		SubCommand: "close",
		Ctx:        context.Background(),
	})
	assert.NoError(t, err)
	assert.Equal(t, "sub", resp.Content)

	// Without sub, parent runs.
	resp, err = r.Dispatch(CommandContext{Command: "ticket", Ctx: context.Background()})
	assert.NoError(t, err)
	assert.Equal(t, "parent", resp.Content)
}

// TestRouter_HasReportsRegistrationStatus is a small public-API smoke check.
func TestRouter_HasReportsRegistrationStatus(t *testing.T) {
	r := NewRouter(zap.NewNop())

	assert.False(t, r.Has("kick"))
	r.Register(CommandDefinition{Name: "kick"}, func(_ CommandContext) (*CommandResponse, error) {
		return &CommandResponse{}, nil
	})
	assert.True(t, r.Has("kick"))
}

// TestParseMention checks the mention parser.
func TestParseMention(t *testing.T) {
	cases := []struct{ in, want string }{
		{"<@uuid-1234>", "uuid-1234"},
		{"<@!uuid-1234>", "uuid-1234"},
		{"  <@uuid>  ", "uuid"},
		{"plain", "plain"},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, ParseMention(c.in), "input: %q", c.in)
	}
}
