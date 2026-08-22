package pubsub

import (
"context"
"sync"

goredis "github.com/redis/go-redis/v9"
"go.uber.org/zap"
)

// FanoutFunc is the callback invoked by the worker pool to deliver
// messages to locally connected WebSocket clients. The third argument
// (excludeClientID) is empty for messages arriving from Redis because
// the originating client is on a different gateway instance.
type FanoutFunc func(channelID string, message []byte, excludeClientID string)

// UserFanoutFunc is the callback invoked to deliver a message directly
// to a specific user's connection(s) on this gateway.
type UserFanoutFunc func(userID string, message []byte)

// Default configuration.
const (
DefaultNumWorkers = 16
DefaultWorkerChanSize = 10_000
)

// subscription tracks a single Redis Pub/Sub subscription and the
// cancel function for its reader goroutine.
type subscription struct {
	sub       *goredis.PubSub
	cancel    context.CancelFunc
	pattern   string
	isPattern bool
}

// RedisPubSub implements EventBus using Redis Pub/Sub.
//
// Thread-safety: subscribers is a sync.Map (lock-free reads);
// workerChan is a buffered channel (inherently safe); Metrics
// uses atomics. No external locking required.
type RedisPubSub struct {
rdb        *goredis.Client
fanout     FanoutFunc
userFanout UserFanoutFunc
gatewayID  string
log        *zap.Logger

// Worker pool.
numWorkers int
workerChan chan *goredis.Message

// Active subscriptions: channelID → *subscription.
subscribers sync.Map

// Lifecycle.
ctx    context.Context
cancel context.CancelFunc
wg     sync.WaitGroup // tracks worker goroutines

// Observable counters.
Met Metrics
}

// NewRedisPubSub creates a RedisPubSub ready for Start().
//
//   - rdb:        connected go-redis client
//   - fanout:     typically manager.FanoutToChannel
//   - userFanout: callback for user-targeted messages
//   - gatewayID:  the unique ID of this gateway instance
//   - numWorkers: worker pool size; 0 → DefaultNumWorkers (16)
func NewRedisPubSub(rdb *goredis.Client, fanout FanoutFunc, userFanout UserFanoutFunc, gatewayID string, numWorkers int, log *zap.Logger) *RedisPubSub {
if numWorkers <= 0 {
numWorkers = DefaultNumWorkers
}
return &RedisPubSub{
rdb:        rdb,
fanout:     fanout,
userFanout: userFanout,
gatewayID:  gatewayID,
log:        log.Named("pubsub"),
numWorkers: numWorkers,
workerChan: make(chan *goredis.Message, DefaultWorkerChanSize),
}
}

// MetricSnapshot returns a point-in-time snapshot of all counters.
func (ps *RedisPubSub) MetricSnapshot() MetricSnapshot {
return ps.Met.Snapshot(len(ps.workerChan), cap(ps.workerChan))
}
