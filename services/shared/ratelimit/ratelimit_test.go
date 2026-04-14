package ratelimit_test

import (
"context"
"sync"
"testing"
"time"

"github.com/alicebob/miniredis/v2"
goredis "github.com/redis/go-redis/v9"
"go.uber.org/zap"

"github.com/flicko-org/flicko/services/shared/ratelimit"
)

// ── helpers ─────────────────────────────────────────────────

func setupRedis(t *testing.T) (*goredis.Client, *miniredis.Miniredis) {
t.Helper()
mr := miniredis.RunT(t)
rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
t.Cleanup(func() { rdb.Close() })
return rdb, mr
}

func newSW(t *testing.T, rdb *goredis.Client) *ratelimit.SlidingWindow {
t.Helper()
sw, err := ratelimit.NewSlidingWindow(context.Background(), rdb, zap.NewNop())
if err != nil {
t.Fatalf("NewSlidingWindow: %v", err)
}
return sw
}

// ── SlidingWindow tests ─────────────────────────────────────

func TestSlidingWindow_UnderLimit(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
ctx := context.Background()

for i := range 5 {
res, err := sw.Allow(ctx, "user:1", 5, time.Second)
if err != nil {
t.Fatal(err)
}
if !res.Allowed {
t.Fatalf("request %d should be allowed", i)
}
if res.Remaining != 5-i-1 {
t.Errorf("remaining: got %d, want %d", res.Remaining, 5-i-1)
}
}
}

func TestSlidingWindow_OverLimit(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
ctx := context.Background()

for range 5 {
sw.Allow(ctx, "user:2", 5, time.Second)
}

res, err := sw.Allow(ctx, "user:2", 5, time.Second)
if err != nil {
t.Fatal(err)
}
if res.Allowed {
t.Fatal("6th request should be denied")
}
if res.Remaining != 0 {
t.Errorf("remaining: got %d, want 0", res.Remaining)
}
}

func TestSlidingWindow_WindowSlides(t *testing.T) {
rdb, mr := setupRedis(t)
sw := newSW(t, rdb)
ctx := context.Background()

// Exhaust the limit.
for range 3 {
sw.Allow(ctx, "user:3", 3, 2*time.Second)
}

res, _ := sw.Allow(ctx, "user:3", 3, 2*time.Second)
if res.Allowed {
t.Fatal("should be denied before window slides")
}

// Fast-forward time in miniredis.
mr.FastForward(3 * time.Second)

res, err := sw.Allow(ctx, "user:3", 3, 2*time.Second)
if err != nil {
t.Fatal(err)
}
if !res.Allowed {
t.Fatal("should be allowed after window slides")
}
}

func TestSlidingWindow_ResetAt(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
ctx := context.Background()

before := time.Now()
res, err := sw.Allow(ctx, "user:4", 10, 5*time.Second)
if err != nil {
t.Fatal(err)
}
// ResetAt should be ~5s in the future.
if res.ResetAt.Before(before) {
t.Errorf("resetAt %v is before request time %v", res.ResetAt, before)
}
if res.ResetAt.After(before.Add(6 * time.Second)) {
t.Errorf("resetAt %v too far in the future", res.ResetAt)
}
}

func TestSlidingWindow_DifferentKeys(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
ctx := context.Background()

// Exhaust limit for key A.
for range 2 {
sw.Allow(ctx, "keyA", 2, time.Second)
}
resA, _ := sw.Allow(ctx, "keyA", 2, time.Second)
if resA.Allowed {
t.Fatal("keyA should be denied")
}

// Key B should still be allowed.
resB, _ := sw.Allow(ctx, "keyB", 2, time.Second)
if !resB.Allowed {
t.Fatal("keyB should be allowed")
}
}

// ── TokenBucket tests ───────────────────────────────────────

func TestBucketStore_UnderLimit(t *testing.T) {
bs := ratelimit.NewBucketStore()
defer bs.Stop()

for range 5 {
if !bs.Allow("user:1", 10, 5) {
t.Fatal("should be allowed within burst")
}
}
}

func TestBucketStore_OverBurst(t *testing.T) {
bs := ratelimit.NewBucketStore()
defer bs.Stop()

// Exhaust burst.
for range 3 {
bs.Allow("user:2", 1, 3)
}
if bs.Allow("user:2", 1, 3) {
t.Fatal("should be denied after burst exhausted")
}
}

func TestBucketStore_LenAndIsolation(t *testing.T) {
bs := ratelimit.NewBucketStore()
defer bs.Stop()

bs.Allow("a", 10, 10)
bs.Allow("b", 10, 10)
bs.Allow("c", 10, 10)

if n := bs.Len(); n != 3 {
t.Errorf("Len() = %d, want 3", n)
}
}

func TestBucketStore_ConcurrentAccess(t *testing.T) {
bs := ratelimit.NewBucketStore()
defer bs.Stop()

var wg sync.WaitGroup
for range 50 {
wg.Add(1)
go func() {
defer wg.Done()
bs.Allow("concurrent-key", 100, 100)
}()
}
wg.Wait()
// No panic = success.
}

// ── Composite tests ─────────────────────────────────────────

func TestComposite_RedisPath(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
bs := ratelimit.NewBucketStore()
defer bs.Stop()
comp := ratelimit.NewComposite(sw, bs, zap.NewNop())

ctx := context.Background()
for range 5 {
ok, err := comp.Allow(ctx, "comp:1", 5, time.Second)
if err != nil {
t.Fatal(err)
}
if !ok {
t.Fatal("should be allowed")
}
}
ok, err := comp.Allow(ctx, "comp:1", 5, time.Second)
if err != nil {
t.Fatal(err)
}
if ok {
t.Fatal("6th request should be denied")
}
}

func TestComposite_FallbackToLocal(t *testing.T) {
rdb, mr := setupRedis(t)
sw := newSW(t, rdb)
bs := ratelimit.NewBucketStore()
defer bs.Stop()
comp := ratelimit.NewComposite(sw, bs, zap.NewNop())
ctx := context.Background()

// Shut down Redis to trigger fallback.
mr.Close()

// Should still work via local bucket.
ok, err := comp.Allow(ctx, "fallback:1", 10, time.Second)
if err != nil {
t.Fatal(err)
}
if !ok {
t.Fatal("should be allowed via local fallback")
}
}

func TestComposite_AllowDetailed_RetryAfter(t *testing.T) {
rdb, _ := setupRedis(t)
sw := newSW(t, rdb)
bs := ratelimit.NewBucketStore()
defer bs.Stop()
comp := ratelimit.NewComposite(sw, bs, zap.NewNop())
ctx := context.Background()

// Exhaust limit.
for range 3 {
comp.AllowDetailed(ctx, "detail:1", 3, 2*time.Second)
}

res, err := comp.AllowDetailed(ctx, "detail:1", 3, 2*time.Second)
if err != nil {
t.Fatal(err)
}
if res.Allowed {
t.Fatal("should be denied")
}
// ResetAt should be in the future.
if res.ResetAt.Before(time.Now()) {
t.Errorf("resetAt %v should be in the future", res.ResetAt)
}
}

// ── Tier tests ──────────────────────────────────────────────

func TestTier_Key(t *testing.T) {
key := ratelimit.TierAPIGeneral.Key("user123")
want := "api_general:user123"
if key != want {
t.Errorf("Key() = %q, want %q", key, want)
}
}

func TestTier_Defaults(t *testing.T) {
if ratelimit.TierAPIGeneral.Limit != 50 {
t.Errorf("APIGeneral limit = %d, want 50", ratelimit.TierAPIGeneral.Limit)
}
	if ratelimit.TierMessageCreate.Limit != 5 {
	t.Errorf("MessageCreate limit = %d, want 5", ratelimit.TierMessageCreate.Limit)
	}
if ratelimit.TierAuth.Window != time.Minute {
t.Errorf("Auth window = %v, want 1m", ratelimit.TierAuth.Window)
}
if ratelimit.TierGuildJoin.Window != time.Hour {
t.Errorf("GuildJoin window = %v, want 1h", ratelimit.TierGuildJoin.Window)
}
}
