// Package batcher implements micro-batch DB inserts (50 messages / 50ms
// window) to reduce write amplification on PostgreSQL.
//
// At 300 msg/sec, individual INSERTs would need 300 round-trips/sec.
// Batching 50 messages drops this to 6 round-trips/sec while keeping
// message delivery latency under 50ms.
package batcher

import (
	"sync/atomic"
)

// Metrics tracks batcher health counters using atomic operations.
// All fields are safe for concurrent reads and writes.
type Metrics struct {
	// MessagesSubmitted is the total number of Submit() calls.
	MessagesSubmitted atomic.Int64

	// MessagesInserted counts messages that were successfully bulk-inserted.
	MessagesInserted atomic.Int64

	// BatchesFlushed counts successful flush operations.
	BatchesFlushed atomic.Int64

	// InsertErrors counts failed flush attempts (each retry counts).
	InsertErrors atomic.Int64

	// Dropped counts messages dropped due to full buffer (backpressure).
	Dropped atomic.Int64

	// DeadLettered counts messages sent to the dead letter queue.
	DeadLettered atomic.Int64

	// BufferLen is the current buffer channel length (updated per flush).
	BufferLen atomic.Int64

	// BufferCap is the buffer channel capacity (set once at init).
	BufferCap atomic.Int64
}

// Snapshot is a point-in-time copy of all counters.
type Snapshot struct {
	MessagesSubmitted int64   `json:"messages_submitted"`
	MessagesInserted  int64   `json:"messages_inserted"`
	BatchesFlushed    int64   `json:"batches_flushed"`
	InsertErrors      int64   `json:"insert_errors"`
	Dropped           int64   `json:"dropped"`
	DeadLettered      int64   `json:"dead_lettered"`
	BufferLen         int64   `json:"buffer_len"`
	BufferCap         int64   `json:"buffer_cap"`
	BufferUtilization float64 `json:"buffer_utilization"`
	DeadLetterDepth   int64   `json:"dead_letter_depth"`
}

// Snapshot returns a consistent point-in-time view of all metrics.
func (m *Metrics) Snapshot(deadLetterDepth int64) Snapshot {
	bl := m.BufferLen.Load()
	bc := m.BufferCap.Load()
	var util float64
	if bc > 0 {
		util = float64(bl) / float64(bc)
	}
	return Snapshot{
		MessagesSubmitted: m.MessagesSubmitted.Load(),
		MessagesInserted:  m.MessagesInserted.Load(),
		BatchesFlushed:    m.BatchesFlushed.Load(),
		InsertErrors:      m.InsertErrors.Load(),
		Dropped:           m.Dropped.Load(),
		DeadLettered:      m.DeadLettered.Load(),
		BufferLen:         bl,
		BufferCap:         bc,
		BufferUtilization: util,
		DeadLetterDepth:   deadLetterDepth,
	}
}
