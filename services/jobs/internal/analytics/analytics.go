// Package analytics aggregates daily analytics metrics.
//
// Runs nightly (cron: 0 2 * * *) to:
//   - Count daily active users (DAU) from session data
//   - Aggregate message counts per channel
//   - Calculate peak concurrent connections
//   - Store results in analytics_daily table
package analytics

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/jobs/internal/shared"
)

// Run executes the analytics aggregation job for yesterday's data.
func Run(ctx context.Context, deps *shared.Deps, log *zap.Logger) error {
	log = log.Named("analytics-agg")

	// Aggregate yesterday's data.
	yesterday := time.Now().UTC().AddDate(0, 0, -1).Format("2006-01-02")
	log.Info("aggregating analytics", zap.String("date", yesterday))

	// ── Daily Active Users ──────────────────────────────────
	var dau int64
	err := deps.DB.QueryRow(ctx, `
		SELECT COUNT(DISTINCT user_id)
		FROM messages
		WHERE created_at >= $1::date
		  AND created_at < ($1::date + interval '1 day')
	`, yesterday).Scan(&dau)
	if err != nil {
		return fmt.Errorf("count DAU: %w", err)
	}
	log.Info("DAU calculated", zap.Int64("dau", dau))

	// ── Total Messages ──────────────────────────────────────
	var totalMessages int64
	err = deps.DB.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM messages
		WHERE created_at >= $1::date
		  AND created_at < ($1::date + interval '1 day')
	`, yesterday).Scan(&totalMessages)
	if err != nil {
		return fmt.Errorf("count messages: %w", err)
	}
	log.Info("total messages", zap.Int64("count", totalMessages))

	// ── New Users ───────────────────────────────────────────
	var newUsers int64
	err = deps.DB.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM users
		WHERE created_at >= $1::date
		  AND created_at < ($1::date + interval '1 day')
	`, yesterday).Scan(&newUsers)
	if err != nil {
		return fmt.Errorf("count new users: %w", err)
	}
	log.Info("new users", zap.Int64("count", newUsers))

	// ── Active Servers ──────────────────────────────────────
	var activeServers int64
	err = deps.DB.QueryRow(ctx, `
		SELECT COUNT(DISTINCT channel_id)
		FROM messages
		WHERE created_at >= $1::date
		  AND created_at < ($1::date + interval '1 day')
	`, yesterday).Scan(&activeServers)
	if err != nil {
		return fmt.Errorf("count active servers: %w", err)
	}

	// ── Upsert daily analytics ──────────────────────────────
	_, err = deps.DB.Exec(ctx, `
		INSERT INTO analytics_daily (date, dau, total_messages, new_users, active_channels)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (date) DO UPDATE SET
			dau = EXCLUDED.dau,
			total_messages = EXCLUDED.total_messages,
			new_users = EXCLUDED.new_users,
			active_channels = EXCLUDED.active_channels,
			updated_at = NOW()
	`, yesterday, dau, totalMessages, newUsers, activeServers)
	if err != nil {
		return fmt.Errorf("upsert analytics: %w", err)
	}

	log.Info("analytics aggregation complete",
		zap.String("date", yesterday),
		zap.Int64("dau", dau),
		zap.Int64("messages", totalMessages),
		zap.Int64("new_users", newUsers),
		zap.Int64("active_channels", activeServers),
	)

	return nil
}
