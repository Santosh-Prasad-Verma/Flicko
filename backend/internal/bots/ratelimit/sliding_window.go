package ratelimit

import (
	"sync"
	"time"
)

type SlidingWindowCounter struct {
	mu         sync.Mutex
	buckets    []int64
	timestamps []time.Time
	bucketSize time.Duration
	windowSize time.Duration
	numBuckets int
	current    int
	limit      int64
}

func NewSlidingWindowCounter(limit int64, window time.Duration, resolution int) *SlidingWindowCounter {
	bucketSize := window / time.Duration(resolution)
	return &SlidingWindowCounter{
		buckets:    make([]int64, resolution),
		timestamps: make([]time.Time, resolution),
		bucketSize: bucketSize,
		windowSize: window,
		numBuckets: resolution,
		limit:      limit,
	}
}

func (sw *SlidingWindowCounter) Allow() (bool, int64) {
	sw.mu.Lock()
	defer sw.mu.Unlock()

	now := time.Now()
	sw.evict(now)

	var total int64
	for _, c := range sw.buckets {
		total += c
	}

	if total >= sw.limit {
		return false, total
	}

	if sw.timestamps[sw.current].IsZero() ||
		now.Sub(sw.timestamps[sw.current]) >= sw.bucketSize {
		sw.current = (sw.current + 1) % sw.numBuckets
		sw.buckets[sw.current] = 0
		sw.timestamps[sw.current] = now
	}
	sw.buckets[sw.current]++
	return true, total + 1
}

func (sw *SlidingWindowCounter) evict(now time.Time) {
	cutoff := now.Add(-sw.windowSize)
	for i, ts := range sw.timestamps {
		if !ts.IsZero() && ts.Before(cutoff) {
			sw.buckets[i] = 0
			sw.timestamps[i] = time.Time{}
		}
	}
}
