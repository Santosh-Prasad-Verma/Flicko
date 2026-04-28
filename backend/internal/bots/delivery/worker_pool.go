package delivery

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots/auth"
	"github.com/flicko-org/flicko-backend/internal/bots/ratelimit"
)

type Event struct {
	EventType string                 `json:"event_type"`
	Data      map[string]interface{} `json:"data"`
}

type DeliveryJob struct {
	BotID      string
	WebhookURL string
	Secret     string
	Event      Event
	Attempt    int
	CreatedAt  time.Time
}

type DeliveryResult struct {
	Job        DeliveryJob
	Success    bool
	StatusCode int
	Latency    time.Duration
	Error      error
}

type WorkerPool struct {
	jobs        chan DeliveryJob
	results     chan DeliveryResult
	workerCount int
	wg          sync.WaitGroup

	breakers map[string]*CircuitBreaker
	mu       sync.RWMutex

	signer   *auth.Signer
	retryCfg RetryConfig
	limiter  *ratelimit.MultiTierLimiter
}

func NewWorkerPool(workerCount, queueSize int, signer *auth.Signer, limiter *ratelimit.MultiTierLimiter) *WorkerPool {
	return &WorkerPool{
		jobs:        make(chan DeliveryJob, queueSize),
		results:     make(chan DeliveryResult, queueSize),
		workerCount: workerCount,
		breakers:    make(map[string]*CircuitBreaker),
		signer:      signer,
		retryCfg:    DefaultRetryConfig,
		limiter:     limiter,
	}
}

func (wp *WorkerPool) Start(ctx context.Context) {
	for i := 0; i < wp.workerCount; i++ {
		wp.wg.Add(1)
		go wp.worker(ctx, i)
	}
}

func (wp *WorkerPool) Stop() {
	close(wp.jobs)
	wp.wg.Wait()
	close(wp.results)
}

func (wp *WorkerPool) Enqueue(job DeliveryJob) bool {
	select {
	case wp.jobs <- job:
		return true
	default:
		slog.Warn("delivery queue full, dropping job", "bot_id", job.BotID, "event_type", job.Event.EventType)
		return false
	}
}

func (wp *WorkerPool) worker(ctx context.Context, id int) {
	defer wp.wg.Done()

	for {
		select {
		case job, ok := <-wp.jobs:
			if !ok {
				return
			}
			result := wp.deliver(ctx, job)
			select {
			case wp.results <- result:
			default:
			}
		case <-ctx.Done():
			return
		}
	}
}

func (wp *WorkerPool) deliver(ctx context.Context, job DeliveryJob) DeliveryResult {
	cb := wp.getOrCreateBreaker(job.BotID)
	start := time.Now()

	if err := cb.Allow(); err != nil {
		return DeliveryResult{Job: job, Error: err}
	}

	if err := wp.limiter.Check(ctx, job.BotID); err != nil {
		return DeliveryResult{Job: job, Error: err}
	}

	var statusCode int
	err := RetryWithBackoff(ctx, wp.retryCfg, func(attempt int) error {
		body, err := marshalEvent(job.Event)
		if err != nil {
			return err
		}

		headers, err := wp.signer.Sign(job.Secret, body)
		if err != nil {
			return err
		}

		code, err := postWebhook(ctx, job.WebhookURL, body, headers)
		statusCode = code
		return err
	})

	latency := time.Since(start)

	if err != nil {
		cb.RecordFailure()
	} else {
		cb.RecordSuccess()
	}

	return DeliveryResult{
		Job:        job,
		Success:    err == nil,
		StatusCode: statusCode,
		Latency:    latency,
		Error:      err,
	}
}

func (wp *WorkerPool) getOrCreateBreaker(botID string) *CircuitBreaker {
	wp.mu.RLock()
	if cb, ok := wp.breakers[botID]; ok {
		wp.mu.RUnlock()
		return cb
	}
	wp.mu.RUnlock()

	wp.mu.Lock()
	defer wp.mu.Unlock()

	if cb, ok := wp.breakers[botID]; ok {
		return cb
	}

	cb := NewCircuitBreaker(5, 2, 30*time.Second, 10*time.Second)
	wp.breakers[botID] = cb
	return cb
}

func marshalEvent(event Event) ([]byte, error) {
	return json.Marshal(event)
}

func postWebhook(ctx context.Context, url string, body []byte, headers map[string]string) (int, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return resp.StatusCode, &DeliveryError{StatusCode: resp.StatusCode}
	}
	return resp.StatusCode, nil
}
