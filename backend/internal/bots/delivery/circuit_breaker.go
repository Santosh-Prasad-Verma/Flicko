package delivery

import (
	"errors"
	"fmt"
	"sync"
	"time"
)

type State int

const (
	StateClosed   State = iota
	StateOpen
	StateHalfOpen
)

var ErrCircuitOpen = errors.New("circuit breaker is open")

type CircuitBreaker struct {
	mu sync.RWMutex

	state         State
	failureCount  int
	successCount  int
	lastFailure   time.Time
	nextProbeTime time.Time

	failureThreshold int
	successThreshold int
	openDuration     time.Duration
	halfOpenTimeout  time.Duration
}

func NewCircuitBreaker(failureThreshold, successThreshold int, openDuration, halfOpenTimeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:            StateClosed,
		failureThreshold: failureThreshold,
		successThreshold: successThreshold,
		openDuration:     openDuration,
		halfOpenTimeout:  halfOpenTimeout,
	}
}

func (cb *CircuitBreaker) Allow() error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	now := time.Now()

	switch cb.state {
	case StateClosed:
		return nil

	case StateOpen:
		if now.After(cb.nextProbeTime) {
			cb.state = StateHalfOpen
			cb.successCount = 0
			cb.nextProbeTime = now.Add(cb.halfOpenTimeout)
			return nil
		}
		return fmt.Errorf("%w: next probe at %v", ErrCircuitOpen, cb.nextProbeTime)

	case StateHalfOpen:
		if now.After(cb.nextProbeTime) {
			return nil
		}
		return fmt.Errorf("%w: in half-open probe window", ErrCircuitOpen)
	}
	return nil
}

func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failureCount = 0

	if cb.state == StateHalfOpen {
		cb.successCount++
		if cb.successCount >= cb.successThreshold {
			cb.state = StateClosed
		}
	}
}

func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failureCount++
	cb.lastFailure = time.Now()

	if cb.state == StateHalfOpen {
		cb.state = StateOpen
		cb.nextProbeTime = time.Now().Add(cb.openDuration)
		return
	}

	if cb.failureCount >= cb.failureThreshold {
		cb.state = StateOpen
		factor := 1 << (cb.failureCount - cb.failureThreshold)
		if factor > 32 {
			factor = 32
		}
		cb.nextProbeTime = time.Now().Add(time.Duration(factor) * cb.openDuration)
	}
}

func (cb *CircuitBreaker) State() State {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}