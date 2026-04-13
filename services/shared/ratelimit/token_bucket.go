package ratelimit

import (
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/time/rate"
)

// bucketEntry pairs a token-bucket limiter with a last-access timestamp
// for stale-entry eviction.
type bucketEntry struct {
	limiter  *rate.Limiter
	lastSeen atomic.Int64 // UnixNano
}

// BucketStore is an in-memory token-bucket rate limiter.
//
// It keeps one *rate.Limiter per key (user, IP, etc.) in a sync.Map
// and runs a background goroutine that evicts entries idle for longer
// than StaleAfter (default 5 min).
//
// Use this as the fast local fallback when Redis is unreachable.
type BucketStore struct {
	buckets   sync.Map // string → *bucketEntry
	staleAge  time.Duration
	stopOnce  sync.Once
	stopCh    chan struct{}
}

const (
	// DefaultStaleAge is how long a bucket can be idle before eviction.
	DefaultStaleAge = 5 * time.Minute
	// cleanupInterval is how often the janitor runs.
	cleanupInterval = 1 * time.Minute
)

// NewBucketStore creates a BucketStore and starts its cleanup goroutine.
// Call Stop() to release the goroutine.
func NewBucketStore() *BucketStore {
	bs := &BucketStore{
		staleAge: DefaultStaleAge,
		stopCh:   make(chan struct{}),
	}
	go bs.janitor()
	return bs
}

// Allow checks whether key has a token available.
//
//   - ratePerSec: sustained token refill rate.
//   - burst:      maximum burst size.
//
// A new limiter is created lazily on the first call for a given key.
func (bs *BucketStore) Allow(key string, ratePerSec float64, burst int) bool {
	now := time.Now().UnixNano()

	val, loaded := bs.buckets.Load(key)
	if loaded {
		entry := val.(*bucketEntry)
		entry.lastSeen.Store(now)
		return entry.limiter.Allow()
	}

	// First time — create limiter.
	entry := &bucketEntry{
		limiter: rate.NewLimiter(rate.Limit(ratePerSec), burst),
	}
	entry.lastSeen.Store(now)

	actual, loaded := bs.buckets.LoadOrStore(key, entry)
	if loaded {
		// Lost the race — use the winner's limiter.
		winner := actual.(*bucketEntry)
		winner.lastSeen.Store(now)
		return winner.limiter.Allow()
	}
	return entry.limiter.Allow()
}

// Stop halts the cleanup goroutine. Safe to call multiple times.
func (bs *BucketStore) Stop() {
	bs.stopOnce.Do(func() { close(bs.stopCh) })
}

// Len returns the number of active buckets (for metrics/testing).
func (bs *BucketStore) Len() int {
	n := 0
	bs.buckets.Range(func(_, _ any) bool { n++; return true })
	return n
}

// janitor periodically evicts idle buckets.
func (bs *BucketStore) janitor() {
	ticker := time.NewTicker(cleanupInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			bs.evictStale()
		case <-bs.stopCh:
			return
		}
	}
}

// evictStale removes entries older than staleAge.
func (bs *BucketStore) evictStale() {
	cutoff := time.Now().Add(-bs.staleAge).UnixNano()
	bs.buckets.Range(func(key, val any) bool {
		entry := val.(*bucketEntry)
		if entry.lastSeen.Load() < cutoff {
			bs.buckets.Delete(key)
		}
		return true
	})
}
