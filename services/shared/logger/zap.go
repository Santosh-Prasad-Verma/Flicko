// Package logger provides structured logging using go.uber.org/zap.
//
// Usage:
//
//	log := logger.New(true)  // development (console, debug)
//	log := logger.New(false) // production  (JSON, info)
//
//	// request-scoped logger
//	rlog := logger.WithRequest(log, requestID, userID)
package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// New returns a pre-configured *zap.Logger.
//   - isDev=true  → console encoder, debug level, caller + stacktrace.
//   - isDev=false → JSON encoder, info level, caller only.
//
// Panics if the logger cannot be built (should never happen with
// the configurations below).
func New(isDev bool) *zap.Logger {
	var cfg zap.Config
	if isDev {
		cfg = zap.NewDevelopmentConfig()
		cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	} else {
		cfg = zap.NewProductionConfig()
		cfg.EncoderConfig.TimeKey = "ts"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	}

	log, err := cfg.Build(zap.AddCallerSkip(0))
	if err != nil {
		panic("logger: " + err.Error())
	}
	return log
}

// WithRequest returns a child logger enriched with request_id and user_id
// fields. Pass an empty string for userID if the caller is unauthenticated.
func WithRequest(log *zap.Logger, requestID, userID string) *zap.Logger {
	fields := []zap.Field{zap.String("request_id", requestID)}
	if userID != "" {
		fields = append(fields, zap.String("user_id", userID))
	}
	return log.With(fields...)
}
