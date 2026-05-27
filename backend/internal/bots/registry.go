package bots

import (
	"context"
	"sync"
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
	// Called EXACTLY ONCE at startup after the event bus is ready.
	// Implementations MUST be idempotent against the bus (use Subscribe with
	// a stable name; the bus dedups by (eventType, name)) but should NOT
	// rely on Register being called multiple times.
	Register(ctx BotContext) error

	// Shutdown performs graceful cleanup (cancel timers, flush state, etc.).
	Shutdown() error
}

// RunnableBot is an optional interface for bots that need a long-running
// goroutine (e.g. a periodic sweep). Run(ctx) is wrapped with a panic-recovery
// loop and called AFTER Register. It must respect ctx cancellation.
type RunnableBot interface {
	Bot
	Run(ctx context.Context) error
}

// BotContext provides bots with access to shared infrastructure.
type BotContext struct {
	DB       database.DatabaseClient
	EventBus *events.EventBus
	Logger   *zap.Logger

	// SystemUserID is the UUID of the bot/system principal used as the
	// author_id for messages emitted by bots. Lazily seeded by EnsureSystemUser.
	SystemUserID string
}

// Registry manages all registered bots.
type Registry struct {
	bots        []Bot
	ctx         BotContext
	logger      *zap.Logger
	externalMgr *ExternalBotManager

	runWG     sync.WaitGroup
	runCancel context.CancelFunc
}

// NewRegistry creates a new bot registry.
func NewRegistry(bctx BotContext) *Registry {
	externalMgr := NewExternalBotManager(bctx)
	return &Registry{
		ctx:         bctx,
		logger:      bctx.Logger.Named("bots.registry"),
		externalMgr: externalMgr,
	}
}

// Add adds a bot to the registry. Must be called before StartAll.
func (r *Registry) Add(b Bot) {
	r.bots = append(r.bots, b)
}

// StartAll registers every bot ONCE, then launches a recovery-wrapped Run loop
// for any bot that implements RunnableBot.
//
// Note: Register is intentionally NOT wrapped in a recovery-restart loop.
// A panic in Register is a programmer error; we log it and surface a fatal
// error so it can be fixed in CI rather than masked at runtime.
func (r *Registry) StartAll() error {
	for _, bot := range r.bots {
		if err := r.registerOnce(bot); err != nil {
			return err
		}
	}

	// Launch optional Run loops with panic recovery + exponential backoff.
	bgCtx, cancel := context.WithCancel(context.Background())
	r.runCancel = cancel

	for _, bot := range r.bots {
		if runnable, ok := bot.(RunnableBot); ok {
			r.runWG.Add(1)
			go r.runWithRecovery(bgCtx, runnable)
		}
	}

	// Register external bot webhook handler ONCE.
	r.externalMgr.RegisterEventHandler()

	r.logger.Info("all bots registered",
		zap.Int("count", len(r.bots)),
	)
	return nil
}

func (r *Registry) registerOnce(bot Bot) error {
	defer func() {
		if rec := recover(); rec != nil {
			r.logger.Error("bot Register panicked",
				zap.String("bot", bot.Name()),
				zap.Any("panic", rec),
			)
		}
	}()

	if err := bot.Register(r.ctx); err != nil {
		r.logger.Error("bot register returned error",
			zap.String("bot", bot.Name()),
			zap.Error(err),
		)
		return err
	}
	return nil
}

// runWithRecovery runs bot.Run in a panic-recovery loop with exponential
// backoff. If Run returns nil, we treat that as "intentional exit" and stop.
// If it returns an error or panics, we restart after a backoff capped at 30s.
func (r *Registry) runWithRecovery(ctx context.Context, bot RunnableBot) {
	defer r.runWG.Done()

	backoff := 1 * time.Second
	const maxBackoff = 30 * time.Second

	for {
		if ctx.Err() != nil {
			return
		}

		err := func() (retErr error) {
			defer func() {
				if rec := recover(); rec != nil {
					retErr = ErrPanic
					r.logger.Error("bot Run panicked",
						zap.String("bot", bot.Name()),
						zap.Any("panic", rec),
					)
				}
			}()
			return bot.Run(ctx)
		}()

		if ctx.Err() != nil {
			return
		}

		if err == nil {
			r.logger.Info("bot Run exited cleanly",
				zap.String("bot", bot.Name()),
			)
			return
		}

		r.logger.Warn("bot Run returned error, restarting",
			zap.String("bot", bot.Name()),
			zap.Duration("backoff", backoff),
			zap.Error(err),
		)

		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}

		backoff *= 2
		if backoff > maxBackoff {
			backoff = maxBackoff
		}
	}
}

// ShutdownAll gracefully shuts down all bots.
func (r *Registry) ShutdownAll() {
	if r.runCancel != nil {
		r.runCancel()
	}

	for _, bot := range r.bots {
		r.logger.Info("shutting down bot", zap.String("bot", bot.Name()))
		if err := bot.Shutdown(); err != nil {
			r.logger.Error("bot shutdown error",
				zap.String("bot", bot.Name()),
				zap.Error(err),
			)
		}
	}

	// Wait up to 10s for Run loops to drain.
	done := make(chan struct{})
	go func() {
		r.runWG.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		r.logger.Warn("bot Run loops did not drain within 10s")
	}
}

// StartBackgroundTasks is retained for API compatibility. The actual
// periodic work is now driven by the TickerMinute/TickerHour events
// published from main.go.
func (r *Registry) StartBackgroundTasks(ctx context.Context) {
	r.logger.Debug("background task loop started (driven by TickerMinute/TickerHour events)")
}

// GetExternalBotManager returns the external bot manager.
func (r *Registry) GetExternalBotManager() *ExternalBotManager {
	return r.externalMgr
}
