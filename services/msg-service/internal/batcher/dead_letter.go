package batcher

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
)

// DeadLetterQueue stores messages that failed all insert retries to
// disk as JSON-lines files for later reprocessing.
//
// Layout: {dir}/messages_{unix_nano}.jsonl
// Each line is one JSON-encoded repository.Message.
//
// A background goroutine periodically scans the directory and
// attempts to re-insert failed messages via BulkInsert.
type DeadLetterQueue struct {
	dir    string
	repo   repository.MessageRepository
	log    *zap.Logger
	depth  atomic.Int64
	stopCh chan struct{}
	once   sync.Once
}

const (
	// retryInterval is how often the DLQ goroutine attempts re-insert.
	retryInterval = 5 * time.Minute
	// dlqFileMode is the file permission for DLQ JSONL files.
	dlqFileMode = 0o644
	// dlqDirMode is the directory permission.
	dlqDirMode = 0o755
)

// NewDeadLetterQueue creates a DLQ that persists to dir.
// Call Start(ctx) to launch the retry goroutine.
func NewDeadLetterQueue(dir string, repo repository.MessageRepository, log *zap.Logger) *DeadLetterQueue {
	return &DeadLetterQueue{
		dir:    dir,
		repo:   repo,
		log:    log.Named("dlq"),
		stopCh: make(chan struct{}),
	}
}

// Enqueue writes a batch of failed messages to a new JSONL file.
func (q *DeadLetterQueue) Enqueue(msgs []*repository.Message) error {
	if len(msgs) == 0 {
		return nil
	}

	if err := os.MkdirAll(q.dir, dlqDirMode); err != nil {
		return fmt.Errorf("dlq: mkdir %s: %w", q.dir, err)
	}

	name := fmt.Sprintf("messages_%d.jsonl", time.Now().UnixNano())
	path := filepath.Join(q.dir, name)

	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_EXCL, dlqFileMode)
	if err != nil {
		return fmt.Errorf("dlq: create %s: %w", path, err)
	}
	defer f.Close()

	enc := json.NewEncoder(f)
	for _, m := range msgs {
		if err := enc.Encode(m); err != nil {
			q.log.Error("dlq: encode message", zap.Error(err))
		}
	}

	q.depth.Add(int64(len(msgs)))
	q.log.Warn("messages dead-lettered",
		zap.Int("count", len(msgs)),
		zap.String("file", name),
	)
	return nil
}

// Depth returns the current number of dead-lettered messages.
func (q *DeadLetterQueue) Depth() int64 {
	return q.depth.Load()
}

// Start launches the periodic retry goroutine.
func (q *DeadLetterQueue) Start(ctx context.Context) {
	go q.retryLoop(ctx)
}

// Stop signals the retry goroutine to exit. Safe to call multiple times.
func (q *DeadLetterQueue) Stop() {
	q.once.Do(func() { close(q.stopCh) })
}

// retryLoop periodically scans DLQ files and attempts re-insert.
func (q *DeadLetterQueue) retryLoop(ctx context.Context) {
	ticker := time.NewTicker(retryInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			q.processAll(ctx)
		case <-ctx.Done():
			return
		case <-q.stopCh:
			return
		}
	}
}

// processAll reads every .jsonl file in the DLQ directory and attempts
// re-insert. On success the file is deleted.
func (q *DeadLetterQueue) processAll(ctx context.Context) {
	entries, err := os.ReadDir(q.dir)
	if err != nil {
		if os.IsNotExist(err) {
			return
		}
		q.log.Error("dlq: read dir", zap.Error(err))
		return
	}

	for _, e := range entries {
		if e.IsDir() || filepath.Ext(e.Name()) != ".jsonl" {
			continue
		}
		path := filepath.Join(q.dir, e.Name())
		if err := q.processFile(ctx, path); err != nil {
			q.log.Warn("dlq: retry failed, will try again later",
				zap.String("file", e.Name()),
				zap.Error(err),
			)
		}
	}
}

// processFile reads a JSONL file, bulk-inserts, and removes on success.
func (q *DeadLetterQueue) processFile(ctx context.Context, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read: %w", err)
	}

	var msgs []*repository.Message
	dec := json.NewDecoder(newBytesReader(data))
	for dec.More() {
		var m repository.Message
		if err := dec.Decode(&m); err != nil {
			q.log.Warn("dlq: skip malformed line", zap.String("file", path), zap.Error(err))
			continue
		}
		msgs = append(msgs, &m)
	}

	if len(msgs) == 0 {
		os.Remove(path)
		return nil
	}

	if err := q.repo.BulkInsert(ctx, msgs); err != nil {
		return fmt.Errorf("bulk insert: %w", err)
	}

	q.depth.Add(-int64(len(msgs)))
	if err := os.Remove(path); err != nil {
		q.log.Warn("dlq: remove file after success", zap.Error(err))
	}

	q.log.Info("dlq: retried successfully",
		zap.Int("count", len(msgs)),
		zap.String("file", filepath.Base(path)),
	)
	return nil
}

// bytesReader wraps raw bytes so json.NewDecoder can parse newline-
// delimited JSON objects. It properly returns io.EOF when exhausted.
type bytesReader struct{ data []byte }

func newBytesReader(data []byte) *bytesReader {
	return &bytesReader{data: data}
}

func (r *bytesReader) Read(p []byte) (int, error) {
	if len(r.data) == 0 {
		return 0, io.EOF
	}
	n := copy(p, r.data)
	r.data = r.data[n:]
	return n, nil
}
