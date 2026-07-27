package workers

import (
	"context"
	"encoding/json"
	"time"

	"go.uber.org/zap"
)

type VectorMessagePayload struct {
	Event     string `json:"event"`
	ServerID  string `json:"server_id"`
	ChannelID string `json:"channel_id"`
	UserID    string `json:"user_id"`
	Data      struct {
		MessageID string `json:"message_id"`
		Content   string `json:"content"`
		AuthorID  string `json:"author_id"`
	} `json:"data"`
}

type VectorSyncWorker struct {
	astraEndpoint string
	astraToken    string
	logger        *zap.Logger
	queue         chan VectorMessagePayload
}

func NewVectorSyncWorker(endpoint, token string, logger *zap.Logger) *VectorSyncWorker {
	return &VectorSyncWorker{
		astraEndpoint: endpoint,
		astraToken:    token,
		logger:        logger.Named("worker.vector_sync"),
		queue:         make(chan VectorMessagePayload, 1000),
	}
}

func (w *VectorSyncWorker) Start(ctx context.Context) {
	w.logger.Info("vector sync worker started")
	go func() {
		for {
			select {
			case <-ctx.Done():
				w.logger.Info("vector sync worker stopping")
				return
			case payload := <-w.queue:
				w.processMessage(ctx, payload)
			}
		}
	}()
}

func (w *VectorSyncWorker) Enqueue(eventData []byte) error {
	var payload VectorMessagePayload
	if err := json.Unmarshal(eventData, &payload); err != nil {
		return err
	}
	if payload.Event != "MESSAGE_CREATE" || payload.Data.Content == "" {
		return nil
	}

	select {
	case w.queue <- payload:
	default:
		w.logger.Warn("vector sync queue full, dropping payload", zap.String("message_id", payload.Data.MessageID))
	}
	return nil
}

func (w *VectorSyncWorker) processMessage(ctx context.Context, payload VectorMessagePayload) {
	// Best-effort processing with retry log
	reqCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	w.logger.Debug("syncing message vector to Astra DB",
		zap.String("message_id", payload.Data.MessageID),
		zap.String("channel_id", payload.ChannelID),
	)

	// Placeholder for Astra DB API vector upsert HTTP call
	_ = reqCtx
}
