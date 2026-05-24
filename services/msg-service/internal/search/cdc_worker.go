package search

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hibiken/asynq"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
)

const (
	// TypeSearchSync is the task type for search sync tasks.
	TypeSearchSync = "search:sync"
)

// SearchSyncPayload holds the payload for indexing messages.
type SearchSyncPayload struct {
	Message *repository.Message `json:"message"`
}

// EnqueueSearchSync puts a message sync task in the Asynq queue.
func EnqueueSearchSync(ctx context.Context, client *asynq.Client, msg *repository.Message, log *zap.Logger) error {
	if client == nil {
		log.Warn("asynq client is nil, bypassing search sync enqueue")
		return nil
	}

	payload, err := json.Marshal(SearchSyncPayload{Message: msg})
	if err != nil {
		return fmt.Errorf("failed to marshal search sync payload: %w", err)
	}

	task := asynq.NewTask(TypeSearchSync, payload)
	_, err = client.EnqueueContext(ctx, task,
		asynq.MaxRetry(5),
		asynq.Timeout(10*time.Second),
	)
	if err != nil {
		log.Error("failed to enqueue search sync task", zap.Error(err), zap.String("message_id", msg.ID))
		return err
	}

	return nil
}

// CDCWorker processes search sync tasks asynchronously.
type CDCWorker struct {
	meili  *MeiliSearchClient
	server *asynq.Server
	log    *zap.Logger
}

// NewCDCWorker creates a new Asynq-backed CDC worker.
func NewCDCWorker(redisURL string, meili *MeiliSearchClient, log *zap.Logger) *CDCWorker {
	opts, err := asynq.ParseRedisURI(redisURL)
	if err != nil {
		log.Error("failed to parse redis url for asynq worker", zap.Error(err))
		// Default to standard local redis option
		opts = asynq.RedisClientOpt{Addr: "localhost:6379"}
	}

	server := asynq.NewServer(
		opts,
		asynq.Config{
			Concurrency: 5,
			Queues: map[string]int{
				"default": 1,
			},
		},
	)

	return &CDCWorker{
		meili:  meili,
		server: server,
		log:    log.Named("cdc_worker"),
	}
}

// Start runs the server processing tasks.
func (w *CDCWorker) Start() error {
	mux := asynq.NewServeMux()
	mux.HandleFunc(TypeSearchSync, w.HandleSearchSyncTask)

	w.log.Info("starting search sync CDC worker")
	return w.server.Start(mux)
}

// Stop terminates the worker.
func (w *CDCWorker) Stop() {
	w.log.Info("stopping search sync CDC worker")
	w.server.Shutdown()
}

// HandleSearchSyncTask handles the message sync execution.
func (w *CDCWorker) HandleSearchSyncTask(ctx context.Context, t *asynq.Task) error {
	var payload SearchSyncPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		w.log.Error("failed to unmarshal sync payload", zap.Error(err))
		return err
	}

	if payload.Message == nil {
		return fmt.Errorf("invalid search sync payload: message is nil")
	}

	w.log.Debug("processing search sync task", zap.String("message_id", payload.Message.ID))
	err := w.meili.BatchSyncMessages(ctx, []*repository.Message{payload.Message})
	if err != nil {
		w.log.Error("failed to sync message to Meilisearch", zap.Error(err), zap.String("message_id", payload.Message.ID))
		return err
	}

	return nil
}
