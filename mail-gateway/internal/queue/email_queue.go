// Package queue provides an in-memory buffered email queue using Go channels.
// It decouples the webhook handler from SMTP sending for non-blocking responses.
package queue

import (
	"fmt"
	"log/slog"
	"sync"

	"github.com/flicko-org/mail-gateway/internal/models"
)

// EmailQueue is a thread-safe buffered channel queue for email jobs.
// The handler pushes jobs in, workers pull jobs out asynchronously.
type EmailQueue struct {
	jobs   chan models.EmailJob // buffered channel for job processing
	size   int                  // max capacity of the channel
	closed bool                 // whether the queue has been closed
	mu     sync.RWMutex         // protects the closed flag
}

// NewEmailQueue creates a new buffered email queue with the specified capacity.
// Typical production size: 100 jobs.
func NewEmailQueue(size int) *EmailQueue {
	if size <= 0 {
		size = 100
	}

	slog.Info("email queue initialized",
		"buffer_size", size,
	)

	return &EmailQueue{
		jobs: make(chan models.EmailJob, size),
		size: size,
	}
}

// Enqueue adds an email job to the queue. Uses non-blocking select so the
// webhook handler returns immediately. Returns false if the queue is full,
// which signals the handler to return 503 (triggering Supabase retry).
func (q *EmailQueue) Enqueue(job models.EmailJob) error {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if q.closed {
		return fmt.Errorf("email_queue: queue is closed, cannot accept job %s", job.ID)
	}

	select {
	case q.jobs <- job:
		slog.Info("job enqueued",
			"job_id", job.ID,
			"to", job.To,
			"template", job.TemplateName,
			"queue_depth", len(q.jobs),
		)
		return nil
	default:
		slog.Warn("queue full, rejecting job",
			"job_id", job.ID,
			"to", job.To,
			"queue_size", q.size,
		)
		return fmt.Errorf("email_queue: queue is full (capacity=%d)", q.size)
	}
}

// Jobs returns a read-only channel that workers consume from.
// When the queue is closed and drained, the channel will be closed.
func (q *EmailQueue) Jobs() <-chan models.EmailJob {
	return q.jobs
}

// Close stops the queue from accepting new jobs and closes the channel.
// Workers will drain any remaining jobs before exiting.
func (q *EmailQueue) Close() {
	q.mu.Lock()
	defer q.mu.Unlock()

	if q.closed {
		return
	}

	q.closed = true
	close(q.jobs)

	slog.Info("email queue closed",
		"remaining_jobs", len(q.jobs),
	)
}

// Pending returns the number of jobs currently waiting in the queue.
func (q *EmailQueue) Pending() int {
	return len(q.jobs)
}

// Capacity returns the maximum buffer size of the queue.
func (q *EmailQueue) Capacity() int {
	return q.size
}

// IsClosed returns whether the queue has been closed.
func (q *EmailQueue) IsClosed() bool {
	q.mu.RLock()
	defer q.mu.RUnlock()
	return q.closed
}
