package commands

import (
	"context"

	"fmt"
	"strings"
	"sync"

	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// CommandHandler processes a slash command and returns a response.
type CommandHandler func(ctx CommandContext) (*CommandResponse, error)

// CommandContext provides all data needed to execute a command.
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

// Router dispatches slash commands to the appropriate handler.
type Router struct {
	mu          sync.RWMutex
	handlers    map[string]CommandHandler // "command" or "command/subcommand"
	definitions []CommandDefinition
	logger      *zap.Logger
}

// NewRouter creates a new command router.
func NewRouter(logger *zap.Logger) *Router {
	return &Router{
		handlers: make(map[string]CommandHandler),
		logger:   logger,
	}
}

// Register adds a command handler.
func (r *Router) Register(def CommandDefinition, handler CommandHandler) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.handlers[def.Name] = handler
	r.definitions = append(r.definitions, def)
	r.logger.Debug("command registered", zap.String("command", def.Name))
}

// RegisterSub adds a sub-command handler under a parent command.
func (r *Router) RegisterSub(parent string, sub string, handler CommandHandler) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := parent + "/" + sub
	r.handlers[key] = handler
	r.logger.Debug("sub-command registered", zap.String("command", key))
}

// GetDefinitions returns all registered command definitions.
func (r *Router) GetDefinitions() []CommandDefinition {
	r.mu.RLock()
	defer r.mu.RUnlock()
	defs := make([]CommandDefinition, len(r.definitions))
	copy(defs, r.definitions)
	return defs
}

// HandleEvent processes a COMMAND_INVOKE event.
func (r *Router) HandleEvent(evt events.Event) error {
	cmdName, _ := evt.Data["command_name"].(string)
	if cmdName == "" {
		return nil
	}

	// Extract sub-command from options if present
	subCmd := ""
	options, _ := evt.Data["options"].(map[string]interface{})
	if sub, ok := options["subcommand"].(string); ok {
		subCmd = sub
	}

	ctx := CommandContext{
		Command:       cmdName,
		SubCommand:    subCmd,
		Options:       options,
		UserID:        evt.UserID,
		ServerID:      evt.ServerID,
		ChannelID:     evt.ChannelID,
		InteractionID: evt.Data["interaction_id"].(string),
	}

	r.mu.RLock()
	// Try sub-command first, then parent
	key := cmdName
	if subCmd != "" {
		key = cmdName + "/" + subCmd
	}
	handler, ok := r.handlers[key]
	if !ok && subCmd != "" {
		// Fallback to parent handler
		handler, ok = r.handlers[cmdName]
	}
	r.mu.RUnlock()

	if !ok {
		r.logger.Warn("unknown command",
			zap.String("command", cmdName),
			zap.String("sub", subCmd),
		)
		return fmt.Errorf("unknown command: %s", cmdName)
	}

	resp, err := handler(ctx)
	if err != nil {
		r.logger.Error("command execution error",
			zap.String("command", key),
			zap.Error(err),
		)
		return err
	}

	if resp != nil {
		// Store the response in the event data so it can be sent back to the client
		evt.Data["response"] = resp
	}

	return nil
}

// ParseMention extracts a user ID from a mention string like "<@uuid>".
func ParseMention(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "<@")
	s = strings.TrimSuffix(s, ">")
	return s
}
