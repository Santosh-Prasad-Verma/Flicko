package delivery

import (
	"context"
	crand "crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"
)

type RetryConfig struct {
	MaxAttempts int
	BaseDelay   time.Duration
	MaxDelay    time.Duration
	Multiplier  float64
	Jitter      float64
}

var DefaultRetryConfig = RetryConfig{
	MaxAttempts: 5,
	BaseDelay:   2 * time.Second,
	MaxDelay:    10 * time.Minute,
	Multiplier:  2.5,
	Jitter:      0.3,
}

func RetryWithBackoff(ctx context.Context, cfg RetryConfig, fn func(attempt int) error) error {
	var lastErr error
	delay := cfg.BaseDelay

	for attempt := 0; attempt < cfg.MaxAttempts; attempt++ {
		if attempt > 0 {
			maxDelay := time.Duration(float64(delay) * cfg.Multiplier)
			if maxDelay > cfg.MaxDelay {
				maxDelay = cfg.MaxDelay
			}

			diff := maxDelay - cfg.BaseDelay
			var jitterFactor float64 = 0.5
			if diff > 0 {
				n, err := crand.Int(crand.Reader, big.NewInt(10000))
				if err == nil {
					jitterFactor = float64(n.Int64()) / 10000.0
				}
			}
			jitteredDelay := cfg.BaseDelay + time.Duration(jitterFactor*float64(diff))
			delay = jitteredDelay

			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(jitteredDelay):
			}
		}

		if err := fn(attempt); err != nil {
			lastErr = err
			if IsNonRetryable(err) {
				return err
			}
			continue
		}
		return nil
	}
	return fmt.Errorf("all %d attempts failed, last error: %w", cfg.MaxAttempts, lastErr)
}

type DeliveryError struct {
	StatusCode int
	Err        error
}

func (e *DeliveryError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("status %d: %v", e.StatusCode, e.Err)
	}
	return fmt.Sprintf("status %d", e.StatusCode)
}

func IsNonRetryable(err error) bool {
	var delivErr *DeliveryError
	if errors.As(err, &delivErr) {
		return delivErr.StatusCode >= 400 && delivErr.StatusCode < 500 && delivErr.StatusCode != 429
	}
	return false
}
