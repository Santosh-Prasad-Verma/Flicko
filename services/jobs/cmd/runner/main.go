// Package main provides the entry point for Flicko Container App Jobs.
//
// This binary dispatches to different job implementations based on the
// JOB_NAME environment variable, which is set by Azure Container App Jobs
// when triggering each job definition.
//
// Jobs:
//   - email-batch:    Send batched promotional emails via SMTP
//   - analytics-agg:  Aggregate daily analytics metrics
//   - data-cleanup:   Archive and purge old data (monthly)
//
// Usage:
//
//	JOB_NAME=email-batch ./jobs
//	JOB_NAME=analytics-agg ./jobs
//	JOB_NAME=data-cleanup ./jobs
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/jobs/internal/analytics"
	"github.com/flicko-org/flicko/services/jobs/internal/cleanup"
	"github.com/flicko-org/flicko/services/jobs/internal/emailbatch"
	"github.com/flicko-org/flicko/services/jobs/internal/shared"
)

func main() {
	// ── Logger ──────────────────────────────────────────────
	log, _ := zap.NewProduction()
	defer log.Sync() //nolint:errcheck

	jobName := os.Getenv("JOB_NAME")
	if jobName == "" {
		log.Fatal("JOB_NAME environment variable is required")
	}

	log.Info("job starting",
		zap.String("job", jobName),
		zap.String("started_at", time.Now().UTC().Format(time.RFC3339)),
	)

	// ── Context with timeout (max 30 min per job run) ───────
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	// Also handle shutdown signals.
	sigCtx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()

	// ── Shared resources ────────────────────────────────────
	deps, err := shared.NewDeps(sigCtx, log)
	if err != nil {
		log.Fatal("failed to initialize dependencies", zap.Error(err))
	}
	defer deps.Close()

	// ── Dispatch ────────────────────────────────────────────
	start := time.Now()
	switch jobName {
	case "email-batch":
		err = emailbatch.Run(sigCtx, deps, log)
	case "analytics-agg":
		err = analytics.Run(sigCtx, deps, log)
	case "data-cleanup":
		err = cleanup.Run(sigCtx, deps, log)
	default:
		err = fmt.Errorf("unknown job: %s", jobName)
	}

	elapsed := time.Since(start)

	if err != nil {
		log.Error("job failed",
			zap.String("job", jobName),
			zap.Duration("elapsed", elapsed),
			zap.Error(err),
		)
		os.Exit(1)
	}

	log.Info("job completed successfully",
		zap.String("job", jobName),
		zap.Duration("elapsed", elapsed),
	)
}
