package pubsub

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// Redis key prefixes. All Pub/Sub topics use one of these.
// Must match the msg-service publisher prefixes (rt:channel:, rt:dm:, etc.)
const (
	PrefixChannel  = "rt:channel:"
	PrefixDM       = "rt:dm:"
	PrefixTyping   = "rt:typing:"
	PrefixPresence = "rt:presence:"
	PrefixGateway  = "rt:gateway:"
)

// Start initialises the worker pool and stores the lifecycle context.
// It satisfies EventBus.Start.
func (ps *RedisPubSub) Start(ctx context.Context) error {
	ps.ctx, ps.cancel = context.WithCancel(ctx)

	for i := 0; i < ps.numWorkers; i++ {
		ps.wg.Add(1)
		go ps.worker(ps.ctx, i)
	}

	if ps.gatewayID != "" {
		if err := ps.SubscribeSingleGateway(ps.ctx); err != nil {
			ps.log.Error("failed to subscribe to gateway topic", zap.String("gateway_id", ps.gatewayID), zap.Error(err))
		}
	}

	ps.log.Info("pubsub started",
		zap.Int("workers", ps.numWorkers),
		zap.Int("worker_chan_cap", cap(ps.workerChan)),
	)
	return nil
}

func (ps *RedisPubSub) SubscribeSingleGateway(ctx context.Context) error {
	redisKey := PrefixGateway + ps.gatewayID
	return ps.subscribeSingle(ctx, "gateway:"+ps.gatewayID, redisKey)
}

// Stop cancels the lifecycle context, waits for workers to drain,
// and closes every Redis subscription. Satisfies EventBus.Stop.
func (ps *RedisPubSub) Stop() error {
	if ps.cancel != nil {
		ps.cancel()
	}

	// Wait for worker goroutines to exit.
	ps.wg.Wait()

	// Close all subscriber goroutines and Redis PubSub objects.
	ps.subscribers.Range(func(key, val any) bool {
		s := val.(*subscription)
		s.cancel()
		if err := s.sub.Close(); err != nil {
			ps.log.Warn("close subscription on stop",
				zap.String("topic", key.(string)),
				zap.Error(err),
			)
		}
		ps.subscribers.Delete(key)
		return true
	})

	ps.log.Info("pubsub stopped")
	return nil
}

// worker is a long-lived goroutine that pulls messages from workerChan
// and delivers them to FanoutFunc. It exits when ctx is cancelled.
func (ps *RedisPubSub) worker(ctx context.Context, id int) {
	defer ps.wg.Done()
	ps.log.Debug("worker started", zap.Int("id", id))

	for {
		select {
		case msg, ok := <-ps.workerChan:
			if !ok {
				return // channel closed
			}
			ps.dispatch(msg)

		case <-ctx.Done():
			// Drain remaining messages before exit.
			for {
				select {
				case msg, ok := <-ps.workerChan:
					if !ok {
						return
					}
					ps.dispatch(msg)
				default:
					return
				}
			}
		}
	}
}

// dispatch routes a single Redis message to FanoutFunc or UserFanoutFunc.
func (ps *RedisPubSub) dispatch(msg *goredis.Message) {
	start := time.Now()
	topic := extractID(msg.Channel)

	if strings.HasPrefix(msg.Channel, PrefixGateway) {
		var target struct {
			UserID  string `json:"user_id"`
			Payload string `json:"payload"`
		}
		if err := json.Unmarshal([]byte(msg.Payload), &target); err != nil {
			ps.log.Error("failed to decode gateway-directed message", zap.Error(err))
			return
		}
		if ps.userFanout != nil {
			ps.userFanout(target.UserID, []byte(target.Payload))
		}
	} else {
		ps.fanout(topic, []byte(msg.Payload), "")
	}

	ps.Met.MsgsFannedOut.Add(1)

	if dur := time.Since(start); dur > 10*time.Millisecond {
		ps.log.Warn("slow fanout",
			zap.String("topic", topic),
			zap.Duration("dur", dur),
		)
	}
}

// extractID strips the key prefix (e.g. "rt:channel:abc123" → "abc123").
func extractID(redisChan string) string {
	for _, prefix := range []string{PrefixChannel, PrefixDM, PrefixTyping, PrefixPresence} {
		if strings.HasPrefix(redisChan, prefix) {
			return redisChan[len(prefix):]
		}
	}
	return redisChan
}
