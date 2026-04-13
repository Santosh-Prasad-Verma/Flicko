package pubsub

import (
	"context"
	"strings"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// Subscribe begins listening on the given topic. If this is the first
// local client for the channel the gateway creates Redis Pub/Sub
// subscriptions for both the channel topic AND the typing topic and
// launches reader goroutines for each.
//
// Idempotent: calling Subscribe twice for the same topic is a no-op.
// Satisfies EventBus.Subscribe.
func (ps *RedisPubSub) Subscribe(ctx context.Context, topic string) error {
	// Subscribe to the main channel topic (messages from msg-service).
	if err := ps.subscribeSingle(ctx, topic, PrefixChannel+topic); err != nil {
		return err
	}
	// Also subscribe to DM topic for the same channelID (DM channels
	// publish to rt:dm:{channelID}).
	_ = ps.subscribeSingle(ctx, "dm:"+topic, PrefixDM+topic)
	// Also subscribe to typing topic so cross-gateway typing events
	// reach local clients.
	_ = ps.subscribeSingle(ctx, "typing:"+topic, PrefixTyping+topic)
	return nil
}

// subscribeSingle creates a single Redis Pub/Sub subscription.
func (ps *RedisPubSub) subscribeSingle(ctx context.Context, storeKey, redisKey string) error {
	// Fast path: already subscribed.
	if _, loaded := ps.subscribers.Load(storeKey); loaded {
		return nil
	}

	// Create Redis subscription.
	sub := ps.rdb.Subscribe(ctx, redisKey)

	// Validate the subscription was created successfully by receiving
	// the confirmation message (non-blocking — go-redis buffers it).
	_, err := sub.Receive(ctx)
	if err != nil {
		sub.Close()
		ps.log.Error("subscribe failed",
			zap.String("topic", storeKey),
			zap.Error(err),
		)
		return err
	}

	readerCtx, readerCancel := context.WithCancel(ps.ctx)
	s := &subscription{sub: sub, cancel: readerCancel}

	// LoadOrStore handles the race where two goroutines try to subscribe
	// to the same channel concurrently.
	if _, loaded := ps.subscribers.LoadOrStore(storeKey, s); loaded {
		// Another goroutine won — clean up ours.
		readerCancel()
		sub.Close()
		return nil
	}

	ps.Met.ActiveSubscriptions.Add(1)
	go ps.reader(readerCtx, storeKey, sub)

	ps.log.Debug("subscribed", zap.String("topic", storeKey))
	return nil
}

// Unsubscribe stops listening on the given topic and its associated
// DM and typing subscriptions. The reader goroutines are cancelled
// and the Redis PubSub objects are closed.
//
// Satisfies EventBus.Unsubscribe.
func (ps *RedisPubSub) Unsubscribe(topic string) error {
	// Unsubscribe from the main channel, DM, and typing topics.
	for _, key := range []string{topic, "dm:" + topic, "typing:" + topic} {
		ps.unsubscribeSingle(key)
	}
	return nil
}

// unsubscribeSingle cleans up a single subscription by its store key.
func (ps *RedisPubSub) unsubscribeSingle(storeKey string) {
	val, loaded := ps.subscribers.LoadAndDelete(storeKey)
	if !loaded {
		return
	}

	s := val.(*subscription)
	s.cancel()
	if err := s.sub.Close(); err != nil {
		ps.log.Warn("unsubscribe close error",
			zap.String("topic", storeKey),
			zap.Error(err),
		)
	}

	ps.Met.ActiveSubscriptions.Add(-1)
	ps.log.Debug("unsubscribed", zap.String("topic", storeKey))
}

// reader is a per-subscription goroutine that reads from the Redis
// Pub/Sub channel and pushes messages into workerChan.
//
// Reconnect strategy: if the Redis channel closes unexpectedly (network
// blip, server restart), the reader attempts to re-subscribe with
// exponential backoff (1 s → 2 s → 4 s, capped at 30 s). This keeps
// the gateway subscribed without manual intervention.
//
// Exit paths:
//   - readerCtx cancelled (Unsubscribe or Stop)
//   - Max reconnect attempts exhausted (after ~5 min total)
func (ps *RedisPubSub) reader(ctx context.Context, topic string, sub *goredis.PubSub) {
	const maxBackoff = 30 * time.Second
	const maxAttempts = 15

	ch := sub.Channel()
	for {
		select {
		case msg, ok := <-ch:
			if !ok {
				// Channel closed — attempt reconnect.
				ps.log.Warn("reader: channel closed, attempting reconnect",
					zap.String("topic", topic),
				)
				sub.Close()

				backoff := 1 * time.Second
				for attempt := 0; attempt < maxAttempts; attempt++ {
					select {
					case <-ctx.Done():
						return
					case <-time.After(backoff):
					}

					// Figure out the Redis key from the topic store key.
					redisKey := ps.storeKeyToRedisKey(topic)
					newSub := ps.rdb.Subscribe(ctx, redisKey)
					if _, err := newSub.Receive(ctx); err != nil {
						newSub.Close()
						ps.log.Warn("reconnect attempt failed",
							zap.String("topic", topic),
							zap.Int("attempt", attempt+1),
							zap.Error(err),
						)
						backoff *= 2
						if backoff > maxBackoff {
							backoff = maxBackoff
						}
						continue
					}

					// Successfully reconnected — update the subscription store.
					readerCtx, readerCancel := context.WithCancel(ps.ctx)
					newS := &subscription{sub: newSub, cancel: readerCancel}
					ps.subscribers.Store(topic, newS)
					sub = newSub
					ch = sub.Channel()

					ps.log.Info("reconnected to topic",
						zap.String("topic", topic),
						zap.Int("attempts", attempt+1),
					)

					// Break out of reconnect loop, continue reading.
					_ = readerCtx // used by the new subscription's lifecycle
					goto reconnected
				}

				// Exhausted attempts — clean up.
				ps.log.Error("reconnect failed after max attempts, giving up",
					zap.String("topic", topic),
					zap.Int("max_attempts", maxAttempts),
				)
				ps.subscribers.Delete(topic)
				ps.Met.ActiveSubscriptions.Add(-1)
				return
			reconnected:
				continue
			}

			ps.Met.MsgsReceived.Add(1)

			// Non-blocking push: if workerChan is full → drop + metric.
			select {
			case ps.workerChan <- msg:
				// delivered
			default:
				ps.Met.MsgsDropped.Add(1)
				ps.log.Warn("worker chan full, dropping message",
					zap.String("topic", topic),
					zap.Int("depth", len(ps.workerChan)),
				)
			}

		case <-ctx.Done():
			return
		}
	}
}

// storeKeyToRedisKey converts a subscriber store key back to the full
// Redis Pub/Sub channel name that should be subscribed to.
func (ps *RedisPubSub) storeKeyToRedisKey(storeKey string) string {
	if strings.HasPrefix(storeKey, "dm:") {
		return PrefixDM + storeKey[3:]
	}
	if strings.HasPrefix(storeKey, "typing:") {
		return PrefixTyping + storeKey[7:]
	}
	// Default: channel topic.
	return PrefixChannel + storeKey
}
