package bots

import (
	"context"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// Bot is the interface every internal bot implements.
type Bot interface {
	// Name returns the bot identifier (e.g. "moderation", "welcome").
	Name() string

	// Register subscribes to events and sets up the bot.
	// Called once at startup after the event bus is ready.
	Register(ctx BotContext) error

	// Shutdown performs graceful cleanup (cancel timers, flush state, etc.).
	Shutdown() error
}

// BotContext provides bots with access to shared infrastructure.
type BotContext struct {
	DB       database.DatabaseClient
	EventBus *events.EventBus
	Logger   *zap.Logger
}

// Registry manages all registered bots.
type Registry struct {
	bots   []Bot
	ctx    BotContext
	logger *zap.Logger
}

// NewRegistry creates a new bot registry.
func NewRegistry(bctx BotContext) *Registry {
	return &Registry{
		ctx:    bctx,
		logger: bctx.Logger,
	}
}

// Add adds a bot to the registry.
func (r *Registry) Add(b Bot) {
	r.bots = append(r.bots, b)
}

// StartAll starts all bots in isolated recovery loops (Fix D: Bot Resilience)
func (r *Registry) StartAll() error {
	for _, bot := range r.bots {
		r.startWithRecovery(bot.Name(), bot)
	}
	r.logger.Info("all bots started with recovery loops", zap.Int("count", len(r.bots)))
	return nil
}

func (r *Registry) startWithRecovery(name string, bot Bot) {
	go func() {

		for {
			func() {
				defer func() {
					if rec := recover(); rec != nil {
						r.logger.Error("bot panicked — restarting",
							zap.String("bot", name),
							zap.Any("panic", rec),
						)
					}
				}()

				// Some bots might do continuous work, others just register callbacks.
				// Run register inside the recovery loop.
				if err := bot.Register(r.ctx); err != nil {
					r.logger.Error("bot register returned error", zap.String("bot", name), zap.Error(err))
				}
			}()
			time.Sleep(2 * time.Second)
		}
	}()
}

// ShutdownAll gracefully shuts down all bots.
func (r *Registry) ShutdownAll() {
	for _, bot := range r.bots {
		r.logger.Info("shutting down bot", zap.String("bot", bot.Name()))
		if err := bot.Shutdown(); err != nil {
			r.logger.Error("bot shutdown error",
				zap.String("bot", bot.Name()),
				zap.Error(err),
			)
		}
	}
}

// StartBackgroundTasks starts periodic background jobs (punishment expiry, etc.).
func (r *Registry) StartBackgroundTasks(ctx context.Context) {
	// Ticker for periodic tasks is handled by the individual bots
	// that subscribe to TickerMinute / TickerHour events.
	r.logger.Info("background task loop started")
}
