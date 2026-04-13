package pubsub

import "sync/atomic"

// Metrics exposes runtime counters for the Pub/Sub subsystem.
// All fields are safe for concurrent access (atomics).
type Metrics struct {
// MsgsPublished is the total number of messages published to Redis.
MsgsPublished atomic.Int64

// MsgsReceived is the total number of messages received from Redis.
MsgsReceived atomic.Int64

// MsgsDropped is the total number of messages dropped because the
// worker channel was full (back-pressure).
MsgsDropped atomic.Int64

// MsgsFannedOut is the total messages delivered to FanoutToChannel.
MsgsFannedOut atomic.Int64

// ActiveSubscriptions is the current number of Redis subscriptions.
ActiveSubscriptions atomic.Int64

// WorkerQueueDepth is sampled (not continuously tracked) — call
// Snapshot() to get the current depth.
workerCh chan struct{} // placeholder, set by redis.go
}

// Snapshot returns a point-in-time copy of all metric values.
type MetricSnapshot struct {
MsgsPublished       int64
MsgsReceived        int64
MsgsDropped         int64
MsgsFannedOut       int64
ActiveSubscriptions int64
WorkerQueueDepth    int
WorkerQueueCap      int
}

// Snapshot returns a point-in-time copy of metric values.
// workerChLen and workerChCap are injected by the caller because
// Metrics doesn't own the channel.
func (m *Metrics) Snapshot(workerChLen, workerChCap int) MetricSnapshot {
return MetricSnapshot{
MsgsPublished:       m.MsgsPublished.Load(),
MsgsReceived:        m.MsgsReceived.Load(),
MsgsDropped:         m.MsgsDropped.Load(),
MsgsFannedOut:       m.MsgsFannedOut.Load(),
ActiveSubscriptions: m.ActiveSubscriptions.Load(),
WorkerQueueDepth:    workerChLen,
WorkerQueueCap:      workerChCap,
}
}
