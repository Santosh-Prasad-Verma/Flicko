package pubsub_test

import (
"context"
"sync"
"sync/atomic"
"testing"
"time"

"github.com/alicebob/miniredis/v2"
goredis "github.com/redis/go-redis/v9"
"go.uber.org/zap"

"github.com/flicko-org/flicko/services/ws-gateway/internal/pubsub"
)

// ── Helpers ─────────────────────────────────────────────────────────

// setup starts miniredis, returns a go-redis client, cleanup func, and
// a *pubsub.RedisPubSub with a recording fanout.
func setup(t *testing.T) (
*goredis.Client,
*miniredis.Miniredis,
*recorder,
) {
t.Helper()
mr := miniredis.RunT(t)
rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
t.Cleanup(func() { rdb.Close() })

rec := &recorder{}
return rdb, mr, rec
}

// newPS creates a RedisPubSub wired to a recorder fanout.
func newPS(t *testing.T, rdb *goredis.Client, rec *recorder, workers int) *pubsub.RedisPubSub {
t.Helper()
log := zap.NewNop()
ps := pubsub.NewRedisPubSub(rdb, rec.Fanout, workers, log)
return ps
}

// recorder collects messages delivered through FanoutFunc.
type recorder struct {
mu   sync.Mutex
msgs []fanoutMsg
}

type fanoutMsg struct {
ChannelID       string
Payload         string
ExcludeClientID string
}

func (r *recorder) Fanout(channelID string, message []byte, excludeClientID string) {
r.mu.Lock()
defer r.mu.Unlock()
r.msgs = append(r.msgs, fanoutMsg{
ChannelID:       channelID,
Payload:         string(message),
ExcludeClientID: excludeClientID,
})
}

func (r *recorder) Len() int {
r.mu.Lock()
defer r.mu.Unlock()
return len(r.msgs)
}

func (r *recorder) Messages() []fanoutMsg {
r.mu.Lock()
defer r.mu.Unlock()
cp := make([]fanoutMsg, len(r.msgs))
copy(cp, r.msgs)
return cp
}

// waitFor polls until cond returns true or timeout expires.
func waitFor(t *testing.T, timeout time.Duration, cond func() bool) {
t.Helper()
deadline := time.Now().Add(timeout)
for time.Now().Before(deadline) {
if cond() {
return
}
time.Sleep(10 * time.Millisecond)
}
t.Fatal("timed out waiting for condition")
}

// ── Tests ───────────────────────────────────────────────────────────

func TestNewRedisPubSub_DefaultWorkers(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 0) // 0 → default 16
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
if err := ps.Start(ctx); err != nil {
t.Fatal(err)
}
defer ps.Stop()

snap := ps.MetricSnapshot()
if snap.WorkerQueueCap != pubsub.DefaultWorkerChanSize {
t.Fatalf("want cap=%d, got %d", pubsub.DefaultWorkerChanSize, snap.WorkerQueueCap)
}
}

func TestPublishAndSubscribe(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 4)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
if err := ps.Start(ctx); err != nil {
t.Fatal(err)
}
defer ps.Stop()

// Subscribe to "test-channel".
if err := ps.Subscribe(ctx, "test-channel"); err != nil {
t.Fatal(err)
}

// Give the reader goroutine a moment to be ready.
time.Sleep(50 * time.Millisecond)

// Publish a message.
if err := ps.Publish(ctx, "test-channel", []byte("hello world")); err != nil {
t.Fatal(err)
}

// Wait for fanout delivery.
waitFor(t, 2*time.Second, func() bool { return rec.Len() >= 1 })

msgs := rec.Messages()
if len(msgs) != 1 {
t.Fatalf("want 1 message, got %d", len(msgs))
}
if msgs[0].ChannelID != "test-channel" {
t.Errorf("channelID = %q, want %q", msgs[0].ChannelID, "test-channel")
}
if msgs[0].Payload != "hello world" {
t.Errorf("payload = %q, want %q", msgs[0].Payload, "hello world")
}
if msgs[0].ExcludeClientID != "" {
t.Errorf("excludeClientID = %q, want empty", msgs[0].ExcludeClientID)
}

// Check metrics.
snap := ps.MetricSnapshot()
if snap.MsgsPublished != 1 {
t.Errorf("MsgsPublished = %d, want 1", snap.MsgsPublished)
}
if snap.MsgsReceived != 1 {
t.Errorf("MsgsReceived = %d, want 1", snap.MsgsReceived)
}
if snap.MsgsFannedOut != 1 {
t.Errorf("MsgsFannedOut = %d, want 1", snap.MsgsFannedOut)
}
if snap.ActiveSubscriptions != 1 {
t.Errorf("ActiveSubscriptions = %d, want 1", snap.ActiveSubscriptions)
}
}

func TestSubscribeIdempotent(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

// Subscribe twice — should be a no-op the second time.
ps.Subscribe(ctx, "ch1")
ps.Subscribe(ctx, "ch1")

snap := ps.MetricSnapshot()
if snap.ActiveSubscriptions != 1 {
t.Errorf("ActiveSubscriptions = %d, want 1 (idempotent)", snap.ActiveSubscriptions)
}
}

func TestUnsubscribe(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

ps.Subscribe(ctx, "ch1")
time.Sleep(50 * time.Millisecond)

// Unsubscribe.
if err := ps.Unsubscribe("ch1"); err != nil {
t.Fatal(err)
}

snap := ps.MetricSnapshot()
if snap.ActiveSubscriptions != 0 {
t.Errorf("ActiveSubscriptions = %d, want 0 after unsubscribe", snap.ActiveSubscriptions)
}

// Unsubscribe again — should be a no-op.
if err := ps.Unsubscribe("ch1"); err != nil {
t.Fatal(err)
}
}

func TestUnsubscribeStopsDelivery(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 4)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

ps.Subscribe(ctx, "ch1")
time.Sleep(50 * time.Millisecond)

// Publish one message (should be delivered).
ps.Publish(ctx, "ch1", []byte("msg1"))
waitFor(t, 2*time.Second, func() bool { return rec.Len() >= 1 })

// Unsubscribe.
ps.Unsubscribe("ch1")
time.Sleep(50 * time.Millisecond)

// Publish another message (should NOT be delivered).
ps.Publish(ctx, "ch1", []byte("msg2"))
time.Sleep(200 * time.Millisecond)

if rec.Len() != 1 {
t.Errorf("expected 1 message after unsubscribe, got %d", rec.Len())
}
}

func TestMultipleChannels(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 4)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

ps.Subscribe(ctx, "ch-a")
ps.Subscribe(ctx, "ch-b")
time.Sleep(50 * time.Millisecond)

ps.Publish(ctx, "ch-a", []byte("alpha"))
ps.Publish(ctx, "ch-b", []byte("beta"))

waitFor(t, 2*time.Second, func() bool { return rec.Len() >= 2 })

msgs := rec.Messages()
channels := map[string]string{}
for _, m := range msgs {
channels[m.ChannelID] = m.Payload
}
if channels["ch-a"] != "alpha" {
t.Errorf("ch-a payload = %q, want %q", channels["ch-a"], "alpha")
}
if channels["ch-b"] != "beta" {
t.Errorf("ch-b payload = %q, want %q", channels["ch-b"], "beta")
}

snap := ps.MetricSnapshot()
if snap.ActiveSubscriptions != 2 {
t.Errorf("ActiveSubscriptions = %d, want 2", snap.ActiveSubscriptions)
}
}

func TestPublishTyping(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

// Subscribe to the typing topic.
// The subscriber uses "ch:" prefix, but typing uses "typing:" prefix.
// To receive typing, we'd subscribe to a "typing:xxx" topic.
// For this test, directly publish + verify the metric increments.
err := ps.PublishTyping(ctx, "channel-1", []byte(`{"user_id":"u1"}`))
if err != nil {
t.Fatal(err)
}

snap := ps.MetricSnapshot()
if snap.MsgsPublished != 1 {
t.Errorf("MsgsPublished = %d, want 1", snap.MsgsPublished)
}
}

func TestPublishPresence(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

err := ps.PublishPresence(ctx, "guild-1", []byte(`{"user_id":"u1","status":"online"}`))
if err != nil {
t.Fatal(err)
}

snap := ps.MetricSnapshot()
if snap.MsgsPublished != 1 {
t.Errorf("MsgsPublished = %d, want 1", snap.MsgsPublished)
}
}

func TestStopDrainsWorkers(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 4)

ctx, cancel := context.WithCancel(context.Background())
ps.Start(ctx)

ps.Subscribe(ctx, "drain-ch")
time.Sleep(50 * time.Millisecond)

// Publish a batch of messages.
for i := 0; i < 10; i++ {
ps.Publish(ctx, "drain-ch", []byte("drain-msg"))
}

// Give time for messages to be received from Redis.
time.Sleep(200 * time.Millisecond)

// Stop should drain remaining messages in workerChan.
cancel()
if err := ps.Stop(); err != nil {
t.Fatal(err)
}

// After stop all received messages should have been fanned out.
snap := ps.MetricSnapshot()
if snap.MsgsFannedOut < snap.MsgsReceived {
t.Errorf("MsgsFannedOut (%d) < MsgsReceived (%d) — drain incomplete",
snap.MsgsFannedOut, snap.MsgsReceived)
}
}

func TestConcurrentSubscribeUnsubscribe(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 4)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

// Hammer subscribe/unsubscribe from multiple goroutines.
var wg sync.WaitGroup
for i := 0; i < 20; i++ {
wg.Add(1)
go func(i int) {
defer wg.Done()
ch := "concurrent-ch"
ps.Subscribe(ctx, ch)
time.Sleep(5 * time.Millisecond)
ps.Unsubscribe(ch)
}(i)
}
wg.Wait()

// Should not panic or deadlock.  Final state: 0 subscriptions.
snap := ps.MetricSnapshot()
if snap.ActiveSubscriptions < 0 {
t.Errorf("ActiveSubscriptions negative: %d", snap.ActiveSubscriptions)
}
}

func TestMetricSnapshot(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

// Initial state.
snap := ps.MetricSnapshot()
if snap.MsgsPublished != 0 || snap.MsgsReceived != 0 || snap.MsgsDropped != 0 {
t.Errorf("metrics not zero at start: %+v", snap)
}
if snap.WorkerQueueCap != pubsub.DefaultWorkerChanSize {
t.Errorf("WorkerQueueCap = %d, want %d", snap.WorkerQueueCap, pubsub.DefaultWorkerChanSize)
}
}

func TestEventBusInterface(t *testing.T) {
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

// Verify RedisPubSub satisfies EventBus at runtime.
var bus pubsub.EventBus = ps
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
if err := bus.Start(ctx); err != nil {
t.Fatal(err)
}
if err := bus.Subscribe(ctx, "iface-ch"); err != nil {
t.Fatal(err)
}
if err := bus.Publish(ctx, "iface-ch", []byte("iface-msg")); err != nil {
t.Fatal(err)
}
if err := bus.Unsubscribe("iface-ch"); err != nil {
t.Fatal(err)
}
if err := bus.Stop(); err != nil {
t.Fatal(err)
}
}

func TestWorkerBackpressure(t *testing.T) {
// Use a tiny worker chan to force drops.
rdb, _, _ := setup(t)
log := zap.NewNop()

var delivered atomic.Int64
slowFanout := func(channelID string, message []byte, excludeClientID string) {
// Simulate slow processing.
time.Sleep(50 * time.Millisecond)
delivered.Add(1)
}

// 1 worker, chan size 2 → easy to overflow.
ps := pubsub.NewRedisPubSub(rdb, slowFanout, 1, log)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

ps.Subscribe(ctx, "pressure-ch")
time.Sleep(50 * time.Millisecond)

// Blast many messages quickly.
for i := 0; i < 50; i++ {
ps.Publish(ctx, "pressure-ch", []byte("flood"))
}

// Wait for processing.
time.Sleep(3 * time.Second)

snap := ps.MetricSnapshot()
total := snap.MsgsFannedOut + snap.MsgsDropped
if total < snap.MsgsReceived {
t.Errorf("fanned+dropped (%d) < received (%d)", total, snap.MsgsReceived)
}
t.Logf("received=%d fanned=%d dropped=%d",
snap.MsgsReceived, snap.MsgsFannedOut, snap.MsgsDropped)
}

func TestExtractID(t *testing.T) {
// This is tested indirectly through dispatch, but verify the
// prefix stripping through the full flow.
rdb, _, rec := setup(t)
ps := newPS(t, rdb, rec, 2)

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
ps.Start(ctx)
defer ps.Stop()

ps.Subscribe(ctx, "strip-test")
time.Sleep(50 * time.Millisecond)

ps.Publish(ctx, "strip-test", []byte("stripped"))
waitFor(t, 2*time.Second, func() bool { return rec.Len() >= 1 })

msgs := rec.Messages()
if msgs[0].ChannelID != "strip-test" {
t.Errorf("channelID = %q, want %q (prefix should be stripped)", msgs[0].ChannelID, "strip-test")
}
}
