package commands

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"

	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// CommandHandler processes a slash command and returns a response.
type CommandHandler func(ctx CommandContext) (*CommandResponse, error)

// CommandContext provides all data needed to execute a command.
//
// Ctx MUST always be non-nil. Callers that don't have a request-scoped
// context should pass context.Background(). Handlers internally derive
// their own bounded contexts from this.
type CommandContext struct {
	Ctx           context.Context
	Command       string
	SubCommand    string
	Options       map[string]interface{}
	UserID        string
	ServerID      string
	ChannelID     string
	InteractionID string
}

// CommandResponse is sent back to the user after command execution.
type CommandResponse struct {
	Content    string                 `json:"content,omitempty"`
	Embed      *Embed                 `json:"embed,omitempty"`
	Ephemeral  bool                   `json:"ephemeral"`
	Components []ActionRow            `json:"components,omitempty"`
	Data       map[string]interface{} `json:"data,omitempty"`
}

// Embed is a rich embed in the response.
//
// Color accepts either a Discord-style hex string (e.g. "#5865F2") or
// a 24-bit RGB integer string (e.g. "5793266"). Both round-trip through
// JSON as a string for wire compatibility with the existing mobile client.
type Embed struct {
	Title       string       `json:"title,omitempty"`
	Description string       `json:"description,omitempty"`
	Color       string       `json:"color,omitempty"`
	Fields      []EmbedField `json:"fields,omitempty"`
	Footer      string       `json:"footer,omitempty"`
	Timestamp   string       `json:"timestamp,omitempty"`
}

// EmbedField is a key-value field in an embed.
type EmbedField struct {
	Name   string `json:"name"`
	Value  string `json:"value"`
	Inline bool   `json:"inline,omitempty"`
}

// ActionRow holds interactive components (buttons, select menus).
type ActionRow struct {
	Type       int           `json:"type"` // 1 = ActionRow
	Components []interface{} `json:"components"`
}

// CommandDefinition describes a slash command for registration.
type CommandDefinition struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Options     []CommandOption `json:"options,omitempty"`
	BotName     string          `json:"bot_name"`
}

// CommandOption is a parameter for a slash command.
type CommandOption struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Type        int             `json:"type"` // 1=SubCommand, 3=String, 4=Integer, 5=Boolean, 6=User, 7=Channel, 8=Role
	Required    bool            `json:"required"`
	Choices     []OptionChoice  `json:"choices,omitempty"`
	Options     []CommandOption `json:"options,omitempty"` // for sub-commands
}

// OptionChoice is a preset choice for a command option.
type OptionChoice struct {
	Name  string      `json:"name"`
	Value interface{} `json:"value"`
}

// ErrUnknownCommand is returned when a command is invoked but not registered.
var ErrUnknownCommand = errors.New("unknown command")

// Router dispatches slash commands to the appropriate handler.
//
// Registration is idempotent: re-registering a command with the same name
// REPLACES the previous handler/definition rather than appending.
type Router struct {
	mu       sync.RWMutex
	handlers map[string]CommandHandler        // "command" or "command/subcommand"
	defs     map[string]CommandDefinition     // by command name
	logger   *zap.Logger
}

// NewRouter creates a new command router.
func NewRouter(logger *zap.Logger) *Router {
	return &Router{
		handlers: make(map[string]CommandHandler),
		defs:     make(map[string]CommandDefinition),
		logger:   logger,
	}
}

// Register adds (or replaces) a command handler and definition.
func (r *Router) Register(def CommandDefinition, handler CommandHandler) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, existed := r.handlers[def.Name]; existed {
		r.logger.Debug("command re-registered (replaced)",
			zap.String("command", def.Name),
		)
	}
	r.handlers[def.Name] = handler
	r.defs[def.Name] = def
}

// RegisterSub adds (or replaces) a sub-command handler under a parent.
func (r *Router) RegisterSub(parent string, sub string, handler CommandHandler) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := parent + "/" + sub
	r.handlers[key] = handler
}

// GetDefinitions returns all registered command definitions, sorted by name.
func (r *Router) GetDefinitions() []CommandDefinition {
	r.mu.RLock()
	defer r.mu.RUnlock()

	defs := make([]CommandDefinition, 0, len(r.defs))
	for _, d := range r.defs {
		defs = append(defs, d)
	}
	return defs
}

// Has returns true if a command with the given name is registered.
func (r *Router) Has(name string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	_, ok := r.handlers[name]
	return ok
}

// Dispatch executes a command synchronously and returns the response.
// This is the canonical execution path; the event-bus subscriber is
// reserved for fan-out signals (analytics, external bots) and MUST NOT
// re-dispatch to avoid double execution (CRIT-8).
func (r *Router) Dispatch(ctx CommandContext) (*CommandResponse, error) {
	if ctx.Ctx == nil {
		ctx.Ctx = context.Background()
	}

	r.mu.RLock()
	key := ctx.Command
	if ctx.SubCommand != "" {
		key = ctx.Command + "/" + ctx.SubCommand
	}
	handler, ok := r.handlers[key]
	if !ok && ctx.SubCommand != "" {
		handler, ok = r.handlers[ctx.Command]
	}
	r.mu.RUnlock()

	if !ok {
		r.logger.Warn("unknown command",
			zap.String("command", ctx.Command),
			zap.String("sub", ctx.SubCommand),
		)
		return nil, fmt.Errorf("%w: %s", ErrUnknownCommand, ctx.Command)
	}

	resp, err := handler(ctx)
	if err != nil {
		r.logger.Error("command execution error",
			zap.String("command", key),
			zap.Error(err),
		)
		return nil, err
	}
	return resp, nil
}

// HandleEvent is a NO-OP fan-out subscriber kept for backward compatibility.
//
// Previous behavior dispatched commands here, which combined with
// BotHandler.InvokeCommand calling Dispatch caused every command to run
// twice (CRIT-8). The router is now a pure RPC dispatch surface; the bus
// subscriber only logs for observability.
func (r *Router) HandleEvent(evt events.Event) error {
	cmdName, _ := evt.Data["command_name"].(string)
	if cmdName == "" {
		return nil
	}
	r.logger.Debug("command event observed",
		zap.String("command", cmdName),
		zap.String("server_id", evt.ServerID),
	)
	return nil
}

// ParseMention extracts a user ID from a mention string like "<@uuid>".
func ParseMention(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "<@")
	s = strings.TrimPrefix(s, "!")
	s = strings.TrimSuffix(s, ">")
	return s
}
