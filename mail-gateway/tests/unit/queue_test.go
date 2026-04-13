package unit

import (
	"sync"
	"testing"
	"time"

	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/queue"
)

// makeTestJob creates a test EmailJob with the given ID.
func makeTestJob(id string) models.EmailJob {
	return models.EmailJob{
		ID:           id,
		To:           "test@example.com",
		Subject:      "Test Subject",
		TemplateName: "verify",
		Data: models.EmailData{
			To:        "test@example.com",
			ActionURL: "http://localhost/verify?token=abc",
			AppName:   "TestApp",
			AppURL:    "http://localhost",
			ValidFor:  "24 hours",
			Year:      2026,
		},
		CreatedAt: time.Now(),
	}
}

// TestEnqueue_Success tests that jobs are successfully added to the queue.
func TestEnqueue_Success(t *testing.T) {
	q := queue.NewEmailQueue(10)
	defer q.Close()

	job := makeTestJob("test-001")
	err := q.Enqueue(job)

	if err != nil {
		t.Fatalf("expected nil error, got: %v", err)
	}
	if q.Pending() != 1 {
		t.Errorf("expected 1 pending job, got %d", q.Pending())
	}
}

// TestEnqueue_Multiple tests enqueueing multiple jobs.
func TestEnqueue_Multiple(t *testing.T) {
	q := queue.NewEmailQueue(10)
	defer q.Close()

	for i := 0; i < 5; i++ {
		job := makeTestJob("test-" + string(rune('A'+i)))
		if err := q.Enqueue(job); err != nil {
			t.Fatalf("enqueue %d failed: %v", i, err)
		}
	}

	if q.Pending() != 5 {
		t.Errorf("expected 5 pending jobs, got %d", q.Pending())
	}
}

// TestEnqueue_Full tests that enqueuing to a full queue returns an error.
func TestEnqueue_Full(t *testing.T) {
	q := queue.NewEmailQueue(2) // Tiny queue
	defer q.Close()

	// Fill the queue
	q.Enqueue(makeTestJob("job-1"))
	q.Enqueue(makeTestJob("job-2"))

	// Third should fail
	err := q.Enqueue(makeTestJob("job-3"))
	if err == nil {
		t.Error("expected error when queue is full, got nil")
	}
}

// TestEnqueue_AfterClose tests that enqueuing after close returns an error.
func TestEnqueue_AfterClose(t *testing.T) {
	q := queue.NewEmailQueue(10)
	q.Close()

	err := q.Enqueue(makeTestJob("job-after-close"))
	if err == nil {
		t.Error("expected error when enqueuing to closed queue, got nil")
	}
}

// TestQueue_DrainOnClose tests that all jobs are available for processing after close.
func TestQueue_DrainOnClose(t *testing.T) {
	q := queue.NewEmailQueue(10)

	// Enqueue 5 jobs
	for i := 0; i < 5; i++ {
		q.Enqueue(makeTestJob("drain-" + string(rune('0'+i))))
	}

	// Close the queue
	q.Close()

	// Drain all jobs from the channel
	count := 0
	for range q.Jobs() {
		count++
	}

	if count != 5 {
		t.Errorf("expected to drain 5 jobs, got %d", count)
	}
}

// TestQueue_ConcurrentEnqueue tests thread safety of concurrent enqueuing.
func TestQueue_ConcurrentEnqueue(t *testing.T) {
	q := queue.NewEmailQueue(100)
	defer q.Close()

	var wg sync.WaitGroup
	errors := make([]error, 0)
	var mu sync.Mutex

	// Launch 50 goroutines each trying to enqueue
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			job := makeTestJob("concurrent-" + string(rune('A'+id%26)))
			if err := q.Enqueue(job); err != nil {
				mu.Lock()
				errors = append(errors, err)
				mu.Unlock()
			}
		}(i)
	}

	wg.Wait()

	if len(errors) > 0 {
		t.Errorf("expected no errors, got %d errors", len(errors))
	}
	if q.Pending() != 50 {
		t.Errorf("expected 50 pending jobs, got %d", q.Pending())
	}
}

// TestQueue_Capacity tests that the Capacity method returns correct value.
func TestQueue_Capacity(t *testing.T) {
	q := queue.NewEmailQueue(42)
	defer q.Close()

	if q.Capacity() != 42 {
		t.Errorf("expected capacity 42, got %d", q.Capacity())
	}
}

// TestQueue_IsClosed tests the IsClosed state tracking.
func TestQueue_IsClosed(t *testing.T) {
	q := queue.NewEmailQueue(10)

	if q.IsClosed() {
		t.Error("queue should not be closed initially")
	}

	q.Close()

	if !q.IsClosed() {
		t.Error("queue should be closed after Close()")
	}
}

// TestQueue_DoubleClose tests that closing twice doesn't panic.
func TestQueue_DoubleClose(t *testing.T) {
	q := queue.NewEmailQueue(10)

	// Should not panic
	q.Close()
	q.Close()
}

// TestQueue_DefaultSize tests that invalid size defaults to 100.
func TestQueue_DefaultSize(t *testing.T) {
	q := queue.NewEmailQueue(0)
	defer q.Close()

	if q.Capacity() != 100 {
		t.Errorf("expected default capacity 100, got %d", q.Capacity())
	}
}
