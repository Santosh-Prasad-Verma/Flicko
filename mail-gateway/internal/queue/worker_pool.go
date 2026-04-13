package queue

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/flicko-org/mail-gateway/internal/mailer"
	"github.com/flicko-org/mail-gateway/internal/models"
)

// WorkerPool manages a pool of worker goroutines that consume email jobs
// from the queue, render templates, and send emails via the mailer.
// Uses sync.WaitGroup for clean shutdown — all in-progress jobs finish before exit.
type WorkerPool struct {
	queue      *EmailQueue    // source of email jobs
	mailer     mailer.Mailer  // email sender implementation
	workers    int            // number of concurrent worker goroutines
	maxRetries int            // max send attempts per job
	wg         sync.WaitGroup // tracks running workers for graceful shutdown
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewWorkerPool creates a pool of workers connected to the given queue and mailer.
func NewWorkerPool(q *EmailQueue, m mailer.Mailer, workers, maxRetries int) *WorkerPool {
	if workers <= 0 {
		workers = 3
	}
	if maxRetries <= 0 {
		maxRetries = 3
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &WorkerPool{
		queue:      q,
		mailer:     m,
		workers:    workers,
		maxRetries: maxRetries,
		ctx:        ctx,
		cancel:     cancel,
	}
}

// Start launches all worker goroutines. Each worker runs an infinite loop
// consuming jobs from the queue channel until the context is cancelled
// or the channel is closed.
func (wp *WorkerPool) Start() {
	slog.Info("starting worker pool",
		"workers", wp.workers,
		"max_retries", wp.maxRetries,
	)

	for i := 1; i <= wp.workers; i++ {
		wp.wg.Add(1)
		go wp.runWorker(i)
	}
}

// Stop signals all workers to stop and waits for in-progress jobs to complete.
// Call queue.Close() before this to ensure workers drain remaining jobs.
func (wp *WorkerPool) Stop() {
	slog.Info("stopping worker pool, waiting for in-progress jobs...")
	wp.cancel()
	wp.wg.Wait()
	slog.Info("worker pool stopped, all jobs drained")
}

// Wait blocks until all workers have finished. Use this during graceful shutdown
// after closing the queue to ensure all in-flight emails are sent.
func (wp *WorkerPool) Wait() {
	wp.wg.Wait()
}

// WorkerCount returns the number of workers in the pool.
func (wp *WorkerPool) WorkerCount() int {
	return wp.workers
}

// runWorker is the main loop for a single worker goroutine.
// It reads jobs from the queue channel and processes each with retry logic.
// Exits cleanly when the channel is closed (after queue.Close()).
func (wp *WorkerPool) runWorker(id int) {
	defer wp.wg.Done()

	slog.Info("worker started", "worker_id", id)

	for job := range wp.queue.Jobs() {
		select {
		case <-wp.ctx.Done():
			slog.Info("worker received shutdown signal, processing remaining job",
				"worker_id", id,
				"job_id", job.ID,
			)
			wp.processWithRetry(id, job)
			return
		default:
			wp.processWithRetry(id, job)
		}
	}

	slog.Info("worker exiting, queue channel closed", "worker_id", id)
}

// processWithRetry attempts to send an email job up to maxRetries times
// with exponential backoff (1s, 2s, 4s, ...). Logs each attempt and
// discards the job after all retries are exhausted (no crash).
func (wp *WorkerPool) processWithRetry(workerID int, job models.EmailJob) {
	for attempt := 1; attempt <= wp.maxRetries; attempt++ {
		slog.Info("processing email job",
			"worker_id", workerID,
			"job_id", job.ID,
			"to", job.To,
			"template", job.TemplateName,
			"attempt", fmt.Sprintf("%d/%d", attempt, wp.maxRetries),
		)

		err := wp.mailer.Send(job.To, job.Subject, job.TemplateName, job.Data)
		if err == nil {
			slog.Info("email sent successfully",
				"worker_id", workerID,
				"job_id", job.ID,
				"to", job.To,
				"attempts_used", attempt,
			)
			return
		}

		slog.Error("email send failed",
			"worker_id", workerID,
			"job_id", job.ID,
			"to", job.To,
			"attempt", fmt.Sprintf("%d/%d", attempt, wp.maxRetries),
			"error", err,
		)

		// Don't sleep after the last failed attempt
		if attempt < wp.maxRetries {
			backoff := time.Duration(1<<uint(attempt-1)) * time.Second // 1s, 2s, 4s
			slog.Info("retrying after backoff",
				"worker_id", workerID,
				"job_id", job.ID,
				"backoff", backoff.String(),
			)

			select {
			case <-time.After(backoff):
				// Continue to next attempt
			case <-wp.ctx.Done():
				slog.Warn("shutdown during backoff, abandoning retry",
					"worker_id", workerID,
					"job_id", job.ID,
				)
				return
			}
		}
	}

	slog.Error("email permanently failed after all retries, discarding job",
		"worker_id", workerID,
		"job_id", job.ID,
		"to", job.To,
		"template", job.TemplateName,
		"max_retries", wp.maxRetries,
	)
}
