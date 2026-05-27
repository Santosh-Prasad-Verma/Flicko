package events

import (
	"errors"
	"time"

	"go.uber.org/zap"
)

// ErrHandlerPanic is returned by RecoveryMiddleware when the wrapped handler
// panicked. Distinguishing this from a normal handler error lets metrics /
// alerting code escalate panics differently from regular failures.
var ErrHandlerPanic = errors.New("event handler panicked")

// RecoveryMiddleware catches panics in handlers so they don't crash the process.
// Returns ErrHandlerPanic so the bus and any metrics layer can detect that
// the handler did not run to completion (MED-1 fix).
func RecoveryMiddleware(logger *zap.Logger) Middleware {
	return func(next Handler) Handler {
		return func(evt Event) (retErr error) {
			defer func() {
				if r := recover(); r != nil {
					logger.Error("handler panicked",
						zap.String("event", string(evt.Type)),
						zap.Any("recover", r),
					)
					retErr = ErrHandlerPanic
				}
			}()
			return next(evt)
		}
	}
}

// LoggingMiddleware logs event processing time.
func LoggingMiddleware(logger *zap.Logger) Middleware {
	return func(next Handler) Handler {
		return func(evt Event) error {
			start := time.Now()
			err := next(evt)
			duration := time.Since(start)

			if duration > 500*time.Millisecond {
				logger.Warn("slow event handler",
					zap.String("event", string(evt.Type)),
					zap.Duration("duration", duration),
				)
			}
			return err
		}
	}
}

// ServerFilterMiddleware only calls the handler if the event's ServerID matches.
func ServerFilterMiddleware(serverID string) Middleware {
	return func(next Handler) Handler {
		return func(evt Event) error {
			if evt.ServerID != "" && evt.ServerID != serverID {
				return nil // skip: different server
			}
			return next(evt)
		}
	}
}
