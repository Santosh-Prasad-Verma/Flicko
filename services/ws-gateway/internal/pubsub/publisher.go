package pubsub

import (
"context"

"go.uber.org/zap"
)

// Publish sends a message to the "ch:{channelID}" Redis topic.
// Fire-and-forget: errors are logged and counted but never block.
//
// Satisfies EventBus.Publish (topic = channelID).
func (ps *RedisPubSub) Publish(ctx context.Context, channelID string, message []byte) error {
key := PrefixChannel + channelID
if err := ps.rdb.Publish(ctx, key, message).Err(); err != nil {
ps.log.Error("publish failed",
zap.String("key", key),
zap.Error(err),
)
return err
}
ps.Met.MsgsPublished.Add(1)
return nil
}

// PublishTyping publishes a typing indicator to "typing:{channelID}".
// Ephemeral: no persistence, no acknowledgement required.
func (ps *RedisPubSub) PublishTyping(ctx context.Context, channelID string, payload []byte) error {
key := PrefixTyping + channelID
if err := ps.rdb.Publish(ctx, key, payload).Err(); err != nil {
ps.log.Error("publish typing failed",
zap.String("key", key),
zap.Error(err),
)
return err
}
ps.Met.MsgsPublished.Add(1)
return nil
}

// PublishPresence publishes a presence update to "presence:{guildID}".
func (ps *RedisPubSub) PublishPresence(ctx context.Context, guildID string, payload []byte) error {
key := PrefixPresence + guildID
if err := ps.rdb.Publish(ctx, key, payload).Err(); err != nil {
ps.log.Error("publish presence failed",
zap.String("key", key),
zap.Error(err),
)
return err
}
ps.Met.MsgsPublished.Add(1)
return nil
}
