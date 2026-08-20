// Package cleanup performs monthly data maintenance and purging of old temporary data.
package cleanup

import (
	"context"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/jobs/internal/shared"
)

// Run executes the data cleanup job.
func Run(ctx context.Context, deps *shared.Deps, log *zap.Logger) error {
	log = log.Named("data-cleanup")
	log.Info("starting monthly data cleanup job")

	// 1. Clean expired sessions (> 30 days)
	cutoffSessions := time.Now().AddDate(0, 0, -30)
	res, err := deps.DB.Exec(ctx, `DELETE FROM user_sessions WHERE expires_at < $1`, cutoffSessions)
	if err != nil {
		log.Warn("clean sessions warning", zap.Error(err))
	} else {
		log.Info("cleaned expired sessions", zap.Int64("deleted", res.RowsAffected()))
	}

	// 2. Clean expired rate limit / audit logs (> 90 days)
	cutoffAudit := time.Now().AddDate(0, 0, -90)
	res, err = deps.DB.Exec(ctx, `DELETE FROM audit_logs WHERE created_at < $1`, cutoffAudit)
	if err != nil {
		log.Warn("clean audit logs warning", zap.Error(err))
	} else {
		log.Info("cleaned old audit logs", zap.Int64("deleted", res.RowsAffected()))
	}

	// 3. Clean temporary upload tokens / dead letters in Redis
	iter := deps.RDB.Scan(ctx, 0, "temp:upload:*", 100).Iterator()
	var keysToDelete []string
	for iter.Next(ctx) {
		keysToDelete = append(keysToDelete, iter.Val())
	}
	if err := iter.Err(); err != nil {
		log.Warn("scan temp upload keys error", zap.Error(err))
	} else if len(keysToDelete) > 0 {
		if err := deps.RDB.Del(ctx, keysToDelete...).Err(); err != nil {
			log.Warn("delete temp upload keys error", zap.Error(err))
		} else {
			log.Info("cleaned temp upload keys from Redis", zap.Int("count", len(keysToDelete)))
		}
	}

	log.Info("data cleanup job completed successfully")
	return nil
}
