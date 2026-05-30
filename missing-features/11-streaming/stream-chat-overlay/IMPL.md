# IMPL — Stream Chat Overlay

## 1. Repo Layout

```
backend/
  internal/streaming/chat/
    api.go              // HTTP handlers
    publish.go          // publish + validate
    moderate.go         // mod actions
    modes.go            // slowmode/emote-only/follower-only
    persist.go          // batched COPY worker
    overlay_token.go    // JWT signer
    centrifugo.go       // client wrapper
    repo.go             // sqlc-backed repository
    rate_limit.go       // Redis token bucket

  cmd/chat-api/main.go  // service entrypoint

  internal/centrifugo/proxy/
    publish_proxy.go    // HTTP proxy hook for persistence

overlay-web/
  src/main.ts
  src/render.ts
  src/themes/*.css
  esbuild.config.mjs

migrations/
  232_stream_chat.up.sql
  232_stream_chat.down.sql
```

## 2. Configuration

```yaml
# config/chat.yaml
chat:
  centrifugo:
    api_url: "https://centrifugo.flicko.app/api"
    api_key: "${CENTRIFUGO_API_KEY}"
    hmac_secret: "${CENTRIFUGO_HMAC_SECRET}"
    namespace: "stream-chat"
  redis:
    addr: "redis-chat.flicko.internal:6379"
    pool_size: 64
  rate_limits:
    default_per_10s: 5
    moderator_per_10s: 30
    emote_max_per_message: 20
  persistence:
    batch_size: 256
    flush_ms: 250
  overlay:
    token_ttl: "24h"
    allowed_referrers:
      - "obs-browser://"
      - "https://*.flicko.app"
```

## 3. Publish Handler

```go
// backend/internal/streaming/chat/publish.go

func (h *Handler) Publish(c *gin.Context) {
    streamID := c.Param("id")
    var req PublishRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "invalid_body"}); return
    }
    userID := auth.UserID(c)

    // 1. Check ban cache
    if banned, _ := h.cache.IsBanned(c, streamID, userID); banned {
        c.JSON(403, gin.H{"error": "banned"}); return
    }

    // 2. Mode checks
    modes, _ := h.modes.Get(c, streamID)
    if modes.EmoteOnly && !isEmoteOnly(req.Text) {
        c.JSON(403, gin.H{"error": "emote_only"}); return
    }
    if modes.FollowOnlyMinutes > 0 {
        if !h.followCheck(c, userID, streamID, modes.FollowOnlyMinutes) {
            c.JSON(403, gin.H{"error": "follow_only"}); return
        }
    }

    // 3. Slowmode + rate limit
    if !h.rl.Allow(c, streamID, userID) {
        c.JSON(429, gin.H{"error": "rate_limited"}); return
    }
    if modes.SlowSeconds > 0 {
        if ok, retryIn := h.rl.AllowSlow(c, streamID, userID, modes.SlowSeconds); !ok {
            c.JSON(429, gin.H{"error": "slow_mode", "retry_after": retryIn}); return
        }
    }

    // 4. Build payload
    msg := chat.Message{
        ID:       uuid.New(),
        StreamID: streamID,
        UserID:   userID,
        Username: auth.Username(c),
        Body:     sanitize(req.Text),
        Tokens:   tokenize(req.Text),
        Badges:   h.badges(c, userID, streamID),
        TS:       time.Now().UnixMilli(),
    }

    // 5. Publish to Centrifugo (persist hook fires asynchronously)
    if err := h.cf.Publish(c, "stream-chat:"+streamID, msg); err != nil {
        c.JSON(503, gin.H{"error": "publish_failed"}); return
    }
    c.JSON(200, gin.H{"message_id": msg.ID, "ts": msg.TS})
}
```

## 4. Rate Limit Lua

```lua
-- rate_limit.lua: KEYS = window key, slow key; ARGV = limit, window_s, slow_s
local cnt = redis.call('INCR', KEYS[1])
if cnt == 1 then redis.call('EXPIRE', KEYS[1], ARGV[2]) end
if cnt > tonumber(ARGV[1]) then return {0, redis.call('TTL', KEYS[1])} end
if tonumber(ARGV[3]) > 0 then
    local set = redis.call('SET', KEYS[2], '1', 'NX', 'EX', ARGV[3])
    if not set then return {0, redis.call('TTL', KEYS[2])} end
end
return {1, 0}
```

## 5. Persistence Worker

```go
// backend/internal/streaming/chat/persist.go

func (w *PersistWorker) run(ctx context.Context) {
    ticker := time.NewTicker(250 * time.Millisecond)
    defer ticker.Stop()
    var buf []chat.Message
    for {
        select {
        case m := <-w.in:
            buf = append(buf, m)
            if len(buf) >= 256 { w.flush(ctx, buf); buf = buf[:0] }
        case <-ticker.C:
            if len(buf) > 0 { w.flush(ctx, buf); buf = buf[:0] }
        case <-ctx.Done():
            if len(buf) > 0 { w.flush(context.Background(), buf) }
            return
        }
    }
}

func (w *PersistWorker) flush(ctx context.Context, msgs []chat.Message) {
    rows := make([][]any, len(msgs))
    for i, m := range msgs {
        rows[i] = []any{m.ID, m.StreamID, m.ChannelID, m.UserID, m.ClientID,
            m.Body, m.Tokens, m.Badges, m.TS}
    }
    _, err := w.pg.CopyFrom(ctx, pgx.Identifier{"stream_chat_messages"},
        []string{"id","stream_id","channel_id","user_id","client_id","body","body_tokens","badges","created_at"},
        pgx.CopyFromRows(rows))
    if err != nil {
        for _, m := range msgs { w.dlq.Publish("chat.persist.dlq", m) }
        chatPersistErrors.Inc()
    }
}
```

## 6. Overlay JWT

```go
// backend/internal/streaming/chat/overlay_token.go
func (s *OverlaySigner) Sign(streamID, ip string) (string, error) {
    claims := jwt.MapClaims{
        "sub": "overlay:" + streamID,
        "channels": []string{"stream-chat:"+streamID, "stream-chat-ctrl:"+streamID},
        "exp": time.Now().Add(24*time.Hour).Unix(),
        "ip_class": ipClass(ip),
    }
    return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(s.secret)
}
```

## 7. Overlay Web

```typescript
// overlay-web/src/main.ts
import { Centrifuge } from 'centrifuge';
import { renderBubble, removeBubble, applyTheme } from './render';

const params = new URLSearchParams(location.search);
const streamId = location.pathname.split('/').pop()!;
const token = params.get('token')!;
applyTheme(params.get('theme') ?? 'default');

const cf = new Centrifuge('wss://centrifugo.flicko.app/connection/websocket', { token });
const sub = cf.newSubscription(`stream-chat:${streamId}`, { recover: true });
const ctrl = cf.newSubscription(`stream-chat-ctrl:${streamId}`);

sub.on('publication', e => renderBubble(e.data, parseInt(params.get('fade') ?? '30000')));
ctrl.on('publication', e => {
    if (e.data.op === 'delete') removeBubble(e.data.message_id);
    if (e.data.op === 'pin') renderPinned(e.data);
});

sub.subscribe(); ctrl.subscribe(); cf.connect();
```

## 8. Centrifugo Publish Proxy

```go
// backend/internal/centrifugo/proxy/publish_proxy.go
func (p *PublishProxy) Handle(c *gin.Context) {
    var req CentrifugoPublishRequest
    _ = c.ShouldBindJSON(&req)
    if strings.HasPrefix(req.Channel, "stream-chat:") {
        var msg chat.Message
        _ = json.Unmarshal(req.Data, &msg)
        p.persistIn <- msg
    }
    c.JSON(200, gin.H{"result": gin.H{}})
}
```

## 9. Tests

```go
// backend/internal/streaming/chat/publish_test.go
func TestPublish_Slowmode(t *testing.T) {
    h := newTestHandler(t)
    h.modes.Set("s1", chat.Modes{SlowSeconds: 30})
    rec1 := h.do(t, "s1", "u1", "hello")
    require.Equal(t, 200, rec1.Code)
    rec2 := h.do(t, "s1", "u1", "again")
    require.Equal(t, 429, rec2.Code)
}

func TestPublish_EmoteOnly(t *testing.T) {
    h := newTestHandler(t)
    h.modes.Set("s1", chat.Modes{EmoteOnly: true})
    require.Equal(t, 403, h.do(t, "s1", "u1", "hello").Code)
    require.Equal(t, 200, h.do(t, "s1", "u1", ":wave:").Code)
}
```

Load test with `k6 run scripts/chat-load.js` simulating 5,000 connections, 100 publishers at 1 msg/s each.

## 10. Rollout

- Week 1: ship migration 232 to staging, run shadow traffic from production chat.
- Week 2: enable feature flag `chat_overlay_v1` for 10 partner channels.
- Week 3: open beta to all Pro creators.
- Week 4: GA after two clean weekly load tests at 5k CCU.
- Rollback: disable flag → clients fall back to legacy channel chat; Centrifugo namespace can stay live without harm.

## 11. Runbook

- Centrifugo node down: NLB health check ejects within 10s; clients reconnect to remaining nodes.
- Redis cluster down: rate-limit fails open, alert paged. Restore from snapshot, mode flags resync from Postgres `stream_chat_settings` table.
- Persistence DLQ growing: replay with `chat-persist replay --since 1h`.
- Spike in 429s: check AutoMod thresholds, examine `chat_drop_total{reason}`.
