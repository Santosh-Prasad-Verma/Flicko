package batcher

import (
        "context"
        "time"

        "go.uber.org/zap"

        "github.com/flicko-org/flicko/services/msg-service/internal/repository"
        fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

const (
        DefaultBufferSize = 5000
        DefaultMaxBatch   = 50
        DefaultMaxWait    = 50 * time.Millisecond
        DefaultMaxRetries = 3
)

type Config struct {
        BufferSize int
        MaxBatch   int
        MaxWait    time.Duration
        MaxRetries int
}

func DefaultConfig() Config {
        return Config{
                BufferSize: DefaultBufferSize,
                MaxBatch:   DefaultMaxBatch,
                MaxWait:    DefaultMaxWait,
                MaxRetries: DefaultMaxRetries,
        }
}

type BatchItem struct {
        Msg       *repository.Message
        OnFlushed func()
}

type MessageBatcher struct {
        repo   repository.MessageRepository
        dlq    *DeadLetterQueue
        buffer chan BatchItem
        cfg    Config
        log    *zap.Logger
        Met    Metrics
}

func NewMessageBatcher(
        repo repository.MessageRepository,
        dlq *DeadLetterQueue,
        cfg Config,
        log *zap.Logger,
) *MessageBatcher {
        if cfg.BufferSize <= 0 {
                cfg.BufferSize = DefaultBufferSize
        }
        if cfg.MaxBatch <= 0 {
                cfg.MaxBatch = DefaultMaxBatch
        }
        if cfg.MaxWait <= 0 {
                cfg.MaxWait = DefaultMaxWait
        }
        if cfg.MaxRetries <= 0 {
                cfg.MaxRetries = DefaultMaxRetries
        }

        b := &MessageBatcher{
                repo:   repo,
                dlq:    dlq,
                buffer: make(chan BatchItem, cfg.BufferSize),
                cfg:    cfg,
                log:    log.Named("batcher"),
        }
        b.Met.BufferCap.Store(int64(cfg.BufferSize))
        return b
}

func (b *MessageBatcher) Submit(msg *repository.Message, onFlushed func()) error {
        b.Met.MessagesSubmitted.Add(1)
        item := BatchItem{Msg: msg, OnFlushed: onFlushed}
        select {
        case b.buffer <- item:
                return nil
        default:
                b.Met.Dropped.Add(1)
                return fkerr.ErrBackpressure()
        }
}

func (b *MessageBatcher) Run(ctx context.Context) {
        batch := make([]BatchItem, 0, b.cfg.MaxBatch)
        timer := time.NewTimer(b.cfg.MaxWait)
        defer timer.Stop()

        for {
                select {
                case item := <-b.buffer:
                        batch = append(batch, item)
                        b.Met.BufferLen.Store(int64(len(b.buffer)))

                        if len(batch) >= b.cfg.MaxBatch {
                                b.flush(ctx, batch)
                                batch = make([]BatchItem, 0, b.cfg.MaxBatch)
                                timer.Reset(b.cfg.MaxWait)
                        }

                case <-timer.C:
                        if len(batch) > 0 {
                                b.flush(ctx, batch)
                                batch = make([]BatchItem, 0, b.cfg.MaxBatch)
                        }
                        timer.Reset(b.cfg.MaxWait)

                case <-ctx.Done():
                        b.log.Info("batcher shutting down, draining buffer",
                                zap.Int("buffered", len(b.buffer)),
                                zap.Int("batch", len(batch)),
                        )
                        b.drain(batch)
                        return
                }
        }
}

func (b *MessageBatcher) drain(current []BatchItem) {
        if len(current) > 0 {
                b.flush(context.Background(), current)
        }

        batch := make([]BatchItem, 0, b.cfg.MaxBatch)
        for {
                select {
                case item := <-b.buffer:
                        batch = append(batch, item)
                        if len(batch) >= b.cfg.MaxBatch {
                                b.flush(context.Background(), batch)
                                batch = make([]BatchItem, 0, b.cfg.MaxBatch)
                        }
                default:
                        if len(batch) > 0 {
                                b.flush(context.Background(), batch)
                        }
                        b.log.Info("batcher drain complete")
                        return
                }
        }
}

func (b *MessageBatcher) flush(ctx context.Context, batch []BatchItem) {
        if len(batch) == 0 {
                return
        }

        msgs := make([]*repository.Message, len(batch))
        for i, item := range batch {
                msgs[i] = item.Msg
        }

        start := time.Now()
        var err error
        backoff := 10 * time.Millisecond

        for attempt := range b.cfg.MaxRetries {
                err = b.repo.BulkInsert(ctx, msgs)
                if err == nil {
                        dur := time.Since(start)
                        b.Met.MessagesInserted.Add(int64(len(batch)))
                        b.Met.BatchesFlushed.Add(1)
                        b.log.Debug("batch flushed",
                                zap.Int("size", len(batch)),
                                zap.Duration("dur", dur),
                        )
                        
                        for _, item := range batch {
                                if item.OnFlushed != nil {
                                        item.OnFlushed()
                                }
                        }
                        return
                }

                b.Met.InsertErrors.Add(1)
                b.log.Warn("batch insert failed, retrying",
                        zap.Int("attempt", attempt+1),
                        zap.Int("max", b.cfg.MaxRetries),
                        zap.Error(err),
                )

                select {
                case <-time.After(backoff):
                        backoff *= 2
                case <-ctx.Done():
                        backoff *= 2
                        continue
                }
        }

        b.log.Error("batch insert failed after all retries, dead-lettering",
                zap.Int("size", len(batch)),
                zap.Error(err),
        )
        b.Met.DeadLettered.Add(int64(len(batch)))
        if dlqErr := b.dlq.Enqueue(msgs); dlqErr != nil {
                b.log.Error("failed to enqueue to dead letter",
                        zap.Int("lost", len(batch)),
                        zap.Error(dlqErr),
                )
        }
}

func (b *MessageBatcher) MetricSnapshot() Snapshot {
        b.Met.BufferLen.Store(int64(len(b.buffer)))
        return b.Met.Snapshot(b.dlq.Depth())
}

func (b *MessageBatcher) Len() int {
        return len(b.buffer)
}
