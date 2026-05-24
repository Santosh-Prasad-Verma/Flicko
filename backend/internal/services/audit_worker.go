package services

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type AuditWorker struct {
	db        database.DatabaseClient
	cache     cache.CacheLayer
	logger    *zap.Logger
	batchSize int
	interval  time.Duration
	stopChan  chan struct{}
	wg        sync.WaitGroup
}

func NewAuditWorker(db database.DatabaseClient, cache cache.CacheLayer, logger *zap.Logger) *AuditWorker {
	return &AuditWorker{
		db:        db,
		cache:     cache,
		logger:    logger,
		batchSize: 100,
		interval:  2 * time.Second,
		stopChan:  make(chan struct{}),
	}
}

func (w *AuditWorker) Start(ctx context.Context) {
	w.logger.Info("starting background audit worker")
	w.wg.Add(1)
	go func() {
		defer w.wg.Done()
		w.runLoop()
	}()
}

func (w *AuditWorker) Stop() {
	w.logger.Info("stopping background audit worker, flushing remaining logs...")
	close(w.stopChan)
	w.wg.Wait()
	w.logger.Info("audit worker stopped cleanly")
}

func (w *AuditWorker) runLoop() {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	var batch []*models.AuditLog

	for {
		select {
		case <-w.stopChan:
			// Flush remaining in batch
			w.flushBatch(batch)
			// Flush any remaining items in Redis
			w.flushRemainingQueue()
			return
		case <-ticker.C:
			if len(batch) > 0 {
				w.flushBatch(batch)
				batch = nil
			}
		default:
			// Pop from Redis
			redisClient := w.cache.GetRedisClient()
			ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
			val, err := redisClient.RPop(ctx, "flicko:audit:queue").Result()
			cancel()

			if err != nil {
				// No items or connection error
				if err.Error() != "redis: nil" {
					w.logger.Debug("error popping from audit queue", zap.Error(err))
				}
				// Sleep briefly to avoid busy-wait tight loop
				time.Sleep(100 * time.Millisecond)
				continue
			}

			var log models.AuditLog
			if err := json.Unmarshal([]byte(val), &log); err != nil {
				w.logger.Error("failed to deserialize queued audit log", zap.Error(err), zap.String("payload", val))
				continue
			}

			batch = append(batch, &log)
			if len(batch) >= w.batchSize {
				w.flushBatch(batch)
				batch = nil
			}
		}
	}
}

func (w *AuditWorker) flushBatch(batch []*models.AuditLog) {
	if len(batch) == 0 {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Bulk insert query
	// INSERT INTO public.audit_logs (id, server_id, actor_id, action_type, target_type, target_id, reason, changes, created_at)
	// VALUES ($1, $2, ...), ($10, $11, ...)
	query := "INSERT INTO public.audit_logs (id, server_id, actor_id, action_type, target_type, target_id, reason, changes, created_at) VALUES "
	args := []interface{}{}
	placeholderIdx := 1

	for i, log := range batch {
		if i > 0 {
			query += ", "
		}

		serverUUID, err1 := uuid.Parse(log.ServerID)
		var actorUUID *uuid.UUID
		if log.ActorID != nil {
			id, err := uuid.Parse(*log.ActorID)
			if err1 == nil && err == nil {
				actorUUID = &id
			}
		}
		var targetUUID *uuid.UUID
		if log.TargetID != nil {
			id, err := uuid.Parse(*log.TargetID)
			if err1 == nil && err == nil {
				targetUUID = &id
			}
		}

		var changesJSON []byte
		if log.Changes != nil {
			changesJSON, _ = json.Marshal(log.Changes)
		}

		query += fmt.Sprintf("($%d, $%d, $%d, $%d, $%d, $%d, $%d, $%d, $%d)",
			placeholderIdx, placeholderIdx+1, placeholderIdx+2, placeholderIdx+3, placeholderIdx+4, placeholderIdx+5, placeholderIdx+6, placeholderIdx+7, placeholderIdx+8)

		args = append(args,
			log.ID,
			serverUUID,
			actorUUID,
			log.ActionType,
			log.TargetType,
			targetUUID,
			log.Reason,
			changesJSON,
			log.CreatedAt,
		)
		placeholderIdx += 9
	}

	_, err := w.db.Exec(ctx, query, args...)
	if err != nil {
		w.logger.Error("failed to bulk insert audit logs batch", zap.Error(err), zap.Int("batch_size", len(batch)))
		return
	}

	w.logger.Debug("successfully flushed audit logs batch", zap.Int("batch_size", len(batch)))
}

func (w *AuditWorker) flushRemainingQueue() {
	redisClient := w.cache.GetRedisClient()
	var batch []*models.AuditLog

	for {
		ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
		val, err := redisClient.RPop(ctx, "flicko:audit:queue").Result()
		cancel()

		if err != nil {
			break
		}

		var log models.AuditLog
		if err := json.Unmarshal([]byte(val), &log); err == nil {
			batch = append(batch, &log)
		}

		if len(batch) >= w.batchSize {
			w.flushBatch(batch)
			batch = nil
		}
	}

	if len(batch) > 0 {
		w.flushBatch(batch)
	}
}
