package pubsub

import (
	"context"
	"strings"
	"time"

	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// Subscribe begins listening on the given topic. Uses a single Redis
// PSUBSCRIBE with a pattern that covers the channel, DM, and typing
// topics, reducing the number of Redis connections from 3 per channel
// to 1 per channel.
//
// Idempotent: calling Subscribe twice for the same topic is a no-op.
// Satisfies EventBus.Subscribe.
func (ps *RedisPubSub) Subscribe(ctx context.Context, topic string) error {
	// Use PSUBSCRIBE with a pattern that matches all three prefixes for this channel:
	//   rt:channel:{topic}, rt:dm:{topic}, rt:typing:{topic}
	// The pattern rt:*:{topic} consolidates all three into one subscription + one reader goroutine.
	return ps.psubscribeSingle(ctx, topic, "rt:*:"+topic)
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
	s := &subscription{sub: sub, cancel: readerCancel, pattern: redisKey, isPattern: false}

	// LoadOrStore handles the race where two goroutines try to subscribe
	// to the same channel concurrently.
	if _, loaded := ps.subscribers.LoadOrStore(storeKey, s); loaded {
		// Another goroutine won — clean up ours.
		readerCancel()
		sub.Close()
		return nil
	}

	ps.Met.ActiveSubscriptions.Add(1)
	go ps.reader(readerCtx, storeKey, sub, redisKey, false)

	ps.log.Debug("subscribed", zap.String("topic", storeKey))
	return nil
}

// psubscribeSingle creates a single Redis Pub/Sub pattern subscription.
// Uses PSUBSCRIBE instead of SUBSCRIBE, allowing wildcard patterns like
// "rt:*:{channelID}" to match multiple Redis channels in one subscription.
func (ps *RedisPubSub) psubscribeSingle(ctx context.Context, storeKey, pattern string) error {
	// Fast path: already subscribed.
	if _, loaded := ps.subscribers.Load(storeKey); loaded {
		return nil
	}

	// Create Redis pattern subscription.
	sub := ps.rdb.PSubscribe(ctx, pattern)

	// Validate the subscription was created successfully.
	_, err := sub.Receive(ctx)
	if err != nil {
		sub.Close()
		ps.log.Error("psubscribe failed",
			zap.String("topic", storeKey),
			zap.String("pattern", pattern),
			zap.Error(err),
		)
		return err
	}

	readerCtx, readerCancel := context.WithCancel(ps.ctx)
	s := &subscription{sub: sub, cancel: readerCancel, pattern: pattern, isPattern: true}

	if _, loaded := ps.subscribers.LoadOrStore(storeKey, s); loaded {
		readerCancel()
		sub.Close()
		return nil
	}

	ps.Met.ActiveSubscriptions.Add(1)
	go ps.reader(readerCtx, storeKey, sub, pattern, true)

	ps.log.Debug("psubscribed", zap.String("topic", storeKey), zap.String("pattern", pattern))
	return nil
}

// Unsubscribe stops listening on the given topic. With the consolidated
// PSUBSCRIBE approach, there is only one subscription per channel (the
// pattern subscription), so we only need to clean up one entry.
//
// Satisfies EventBus.Unsubscribe.
func (ps *RedisPubSub) Unsubscribe(topic string) error {
	ps.unsubscribeSingle(topic)
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
func (ps *RedisPubSub) reader(ctx context.Context, topic string, sub *goredis.PubSub, pattern string, isPattern bool) {
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
					zap.String("pattern", pattern),
					zap.Bool("is_pattern", isPattern),
				)
				sub.Close()

				backoff := 1 * time.Second
				for attempt := 0; attempt < maxAttempts; attempt++ {
					select {
					case <-ctx.Done():
						return
					case <-time.After(backoff):
					}

					var newSub *goredis.PubSub
					if isPattern {
						newSub = ps.rdb.PSubscribe(ctx, pattern)
					} else {
						newSub = ps.rdb.Subscribe(ctx, pattern)
					}

					if _, err := newSub.Receive(ctx); err != nil {
						newSub.Close()
						ps.log.Warn("reconnect attempt failed",
							zap.String("topic", topic),
							zap.String("pattern", pattern),
							zap.Bool("is_pattern", isPattern),
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
					newS := &subscription{sub: newSub, cancel: readerCancel, pattern: pattern, isPattern: isPattern}
					ps.subscribers.Store(topic, newS)
					sub = newSub
					ch = sub.Channel()

					ps.log.Info("reconnected to topic",
						zap.String("topic", topic),
						zap.String("pattern", pattern),
						zap.Bool("is_pattern", isPattern),
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
