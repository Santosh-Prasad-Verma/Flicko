package redis_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	flickoredis "github.com/flicko-org/flicko/services/shared/redis"
)

// ---------- helpers ----------

// setup starts a miniredis server and returns a go-redis client + cleanup func.
func setup(t *testing.T) (*goredis.Client, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })
	return rdb, mr
}

func noopLogger() *zap.Logger { return zap.NewNop() }

// ============================================================
//  client.go tests
// ============================================================

func TestHealthCheck(t *testing.T) {
	rdb, _ := setup(t)
	ctx := context.Background()

	if err := flickoredis.HealthCheck(ctx, rdb); err != nil {
		t.Fatalf("HealthCheck() error = %v", err)
	}
}

func TestHealthCheckDown(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	mr.Close() // shut it down
	ctx := context.Background()

	if err := flickoredis.HealthCheck(ctx, rdb); err == nil {
		t.Fatal("HealthCheck() expected error when server is down")
	}
}

// ============================================================
//  ratelimit.go tests
// ============================================================

func TestRateLimiterAllow(t *testing.T) {
	rdb, _ := setup(t)
	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	// Allow 3 requests in 10s window.
	for i := 0; i < 3; i++ {
		ok, err := rl.Allow(ctx, "test:user1", 3, 10*time.Second)
		if err != nil {
			t.Fatalf("Allow() error = %v", err)
		}
		if !ok {
			t.Fatalf("Allow() request %d should be allowed", i+1)
		}
	}

	// 4th should be denied.
	ok, err := rl.Allow(ctx, "test:user1", 3, 10*time.Second)
	if err != nil {
		t.Fatalf("Allow() error = %v", err)
	}
	if ok {
		t.Fatal("Allow() 4th request should be denied")
	}
}

func TestRateLimiterDifferentKeys(t *testing.T) {
	rdb, _ := setup(t)
	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	// Exhaust user1.
	for i := 0; i < 2; i++ {
		rl.Allow(ctx, "test:user1", 2, 10*time.Second)
	}

	// user2 should still be allowed.
	ok, err := rl.Allow(ctx, "test:user2", 2, 10*time.Second)
	if err != nil {
		t.Fatalf("Allow() error = %v", err)
	}
	if !ok {
		t.Fatal("Allow() user2 should be allowed (different key)")
	}
}

func TestRateLimiterWindowExpiry(t *testing.T) {
	rdb, mr := setup(t)
	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	// Fill the limiter.
	for i := 0; i < 2; i++ {
		rl.Allow(ctx, "test:exp", 2, 1*time.Second)
	}

	// Fast-forward time in miniredis.
	mr.FastForward(2 * time.Second)

	// Should be allowed again after window expires.
	ok, err := rl.Allow(ctx, "test:exp", 2, 1*time.Second)
	if err != nil {
		t.Fatalf("Allow() error = %v", err)
	}
	if !ok {
		t.Fatal("Allow() should be allowed after window expires")
	}
}

func TestRateLimiterReset(t *testing.T) {
	rdb, _ := setup(t)
	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	for i := 0; i < 3; i++ {
		rl.Allow(ctx, "test:reset", 3, 10*time.Second)
	}

	if err := rl.Reset(ctx, "test:reset"); err != nil {
		t.Fatalf("Reset() error = %v", err)
	}

	ok, err := rl.Allow(ctx, "test:reset", 3, 10*time.Second)
	if err != nil {
		t.Fatalf("Allow() error = %v", err)
	}
	if !ok {
		t.Fatal("Allow() should be allowed after Reset()")
	}
}

func TestRateLimiterLocalFallback(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	mr.Close() // Kill Redis.

	// Should fallback to local limiter without error.
	ok, err := rl.Allow(ctx, "test:fallback", 2, 10*time.Second)
	if err != nil {
		t.Fatalf("Allow() should not error on fallback, got %v", err)
	}
	if !ok {
		t.Fatal("Allow() first request on local fallback should be allowed")
	}

	// Exhaust local limiter.
	rl.Allow(ctx, "test:fallback", 2, 10*time.Second)
	ok, _ = rl.Allow(ctx, "test:fallback", 2, 10*time.Second)
	if ok {
		t.Fatal("Allow() local fallback should enforce limit")
	}
}

func TestRateLimiterCleanupLocal(t *testing.T) {
	rdb, mr := setup(t)
	mr.Close()

	rl := flickoredis.NewSlidingWindowRateLimiter(rdb, noopLogger())
	ctx := context.Background()

	rl.Allow(ctx, "test:cleanup", 10, 1*time.Second)
	rl.CleanupLocal() // should not panic, should prune
}

// ============================================================
//  presence.go tests
// ============================================================

func TestSetAndGetPresence(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	err := pm.SetPresence(ctx, "user1", "online", "gw-01")
	if err != nil {
		t.Fatalf("SetPresence() error = %v", err)
	}

	p, err := pm.GetPresence(ctx, "user1")
	if err != nil {
		t.Fatalf("GetPresence() error = %v", err)
	}
	if p == nil {
		t.Fatal("GetPresence() returned nil")
	}
	if p.Status != "online" {
		t.Errorf("Status = %q, want online", p.Status)
	}
	if p.GatewayID != "gw-01" {
		t.Errorf("GatewayID = %q, want gw-01", p.GatewayID)
	}
	if p.LastSeen == 0 {
		t.Error("LastSeen should not be zero")
	}
}

func TestGetPresenceNotFound(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	p, err := pm.GetPresence(ctx, "nonexistent")
	if err != nil {
		t.Fatalf("GetPresence() error = %v", err)
	}
	if p != nil {
		t.Fatal("GetPresence() should return nil for missing user")
	}
}

func TestRemovePresence(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.SetPresence(ctx, "user2", "idle", "gw-02")
	pm.RemovePresence(ctx, "user2")

	p, _ := pm.GetPresence(ctx, "user2")
	if p != nil {
		t.Fatal("GetPresence() should return nil after removal")
	}
}

func TestPresenceTTL(t *testing.T) {
	rdb, mr := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.SetPresence(ctx, "user-ttl", "online", "gw-01")

	mr.FastForward(flickoredis.PresenceTTL + time.Second)

	p, _ := pm.GetPresence(ctx, "user-ttl")
	if p != nil {
		t.Fatal("Presence should expire after PresenceTTL")
	}
}

func TestSetAndGetTyping(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.SetTyping(ctx, "ch1", "userA")
	pm.SetTyping(ctx, "ch1", "userB")
	pm.SetTyping(ctx, "ch2", "userC") // different channel

	users, err := pm.GetTyping(ctx, "ch1")
	if err != nil {
		t.Fatalf("GetTyping() error = %v", err)
	}
	if len(users) != 2 {
		t.Fatalf("GetTyping() len = %d, want 2", len(users))
	}

	// Verify both IDs are present (order not guaranteed by SCAN).
	found := map[string]bool{}
	for _, u := range users {
		found[u] = true
	}
	if !found["userA"] || !found["userB"] {
		t.Errorf("GetTyping() = %v, want userA + userB", users)
	}
}

func TestTypingTTL(t *testing.T) {
	rdb, mr := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.SetTyping(ctx, "ch1", "userX")
	mr.FastForward(flickoredis.TypingTTL + time.Second)

	users, _ := pm.GetTyping(ctx, "ch1")
	if len(users) != 0 {
		t.Fatal("Typing indicator should expire after TypingTTL")
	}
}

func TestClearTyping(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.SetTyping(ctx, "ch1", "userA")
	pm.ClearTyping(ctx, "ch1", "userA")

	users, _ := pm.GetTyping(ctx, "ch1")
	if len(users) != 0 {
		t.Fatal("Typing indicator should be cleared")
	}
}

func TestGuildOnline(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.UpdateGuildOnline(ctx, "guild1", "user1")
	pm.UpdateGuildOnline(ctx, "guild1", "user2")
	pm.UpdateGuildOnline(ctx, "guild1", "user3")

	online, err := pm.GetGuildOnline(ctx, "guild1", 10)
	if err != nil {
		t.Fatalf("GetGuildOnline() error = %v", err)
	}
	if len(online) != 3 {
		t.Fatalf("GetGuildOnline() len = %d, want 3", len(online))
	}
}

func TestGuildOnlineLimit(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		pm.UpdateGuildOnline(ctx, "guild2", "user"+string(rune('A'+i)))
	}

	online, _ := pm.GetGuildOnline(ctx, "guild2", 5)
	if len(online) != 5 {
		t.Fatalf("GetGuildOnline() len = %d, want 5 (limit)", len(online))
	}
}

func TestRemoveGuildOnline(t *testing.T) {
	rdb, _ := setup(t)
	pm := flickoredis.NewPresenceManager(rdb, noopLogger())
	ctx := context.Background()

	pm.UpdateGuildOnline(ctx, "guild3", "user1")
	pm.UpdateGuildOnline(ctx, "guild3", "user2")
	pm.RemoveGuildOnline(ctx, "guild3", "user1")

	online, _ := pm.GetGuildOnline(ctx, "guild3", 10)
	if len(online) != 1 {
		t.Fatalf("GetGuildOnline() after remove: len = %d, want 1", len(online))
	}
	if online[0] != "user2" {
		t.Errorf("remaining member = %q, want user2", online[0])
	}
}

// ============================================================
//  idempotency.go tests
// ============================================================

func TestIdempotencyStoreAndGet(t *testing.T) {
	rdb, _ := setup(t)
	store := flickoredis.NewIdempotencyStore(rdb)
	ctx := context.Background()

	payload := []byte(`{"id":"msg123","content":"hello"}`)

	err := store.Store(ctx, "nonce-abc", payload, 0)
	if err != nil {
		t.Fatalf("Store() error = %v", err)
	}

	got, found, err := store.Get(ctx, "nonce-abc")
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if !found {
		t.Fatal("Get() should find the stored nonce")
	}
	if string(got) != string(payload) {
		t.Errorf("Get() = %s, want %s", got, payload)
	}
}

func TestIdempotencyGetMiss(t *testing.T) {
	rdb, _ := setup(t)
	store := flickoredis.NewIdempotencyStore(rdb)
	ctx := context.Background()

	_, found, err := store.Get(ctx, "nonexistent-nonce")
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if found {
		t.Fatal("Get() should return false for missing nonce")
	}
}

func TestIdempotencyTTL(t *testing.T) {
	rdb, mr := setup(t)
	store := flickoredis.NewIdempotencyStore(rdb)
	ctx := context.Background()

	store.Store(ctx, "nonce-ttl", []byte("data"), 5*time.Second)
	mr.FastForward(6 * time.Second)

	_, found, _ := store.Get(ctx, "nonce-ttl")
	if found {
		t.Fatal("nonce should have expired")
	}
}

func TestIdempotencyDelete(t *testing.T) {
	rdb, _ := setup(t)
	store := flickoredis.NewIdempotencyStore(rdb)
	ctx := context.Background()

	store.Store(ctx, "nonce-del", []byte("data"), 0)
	store.Delete(ctx, "nonce-del")

	_, found, _ := store.Get(ctx, "nonce-del")
	if found {
		t.Fatal("nonce should be deleted")
	}
}

func TestIdempotencyDefaultTTL(t *testing.T) {
	rdb, mr := setup(t)
	store := flickoredis.NewIdempotencyStore(rdb)
	ctx := context.Background()

	store.Store(ctx, "nonce-default", []byte("data"), 0) // 0 → 300s default

	// Still present after 200s.
	mr.FastForward(200 * time.Second)
	_, found, _ := store.Get(ctx, "nonce-default")
	if !found {
		t.Fatal("should still exist before 300s")
	}

	// Gone after 300s.
	mr.FastForward(150 * time.Second)
	_, found, _ = store.Get(ctx, "nonce-default")
	if found {
		t.Fatal("should have expired after 300s")
	}
}

// ============================================================
//  cache.go tests
// ============================================================

type testUser struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

func TestCacheSetAndGet(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	user := testUser{ID: "u1", Username: "alice"}

	err := flickoredis.Set(ctx, c, flickoredis.UserKey("u1"), user, 0)
	if err != nil {
		t.Fatalf("Set() error = %v", err)
	}

	var got testUser
	found, err := flickoredis.Get(ctx, c, flickoredis.UserKey("u1"), &got)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if !found {
		t.Fatal("Get() should find cached user")
	}
	if got.Username != "alice" {
		t.Errorf("Username = %q, want alice", got.Username)
	}
}

func TestCacheGetMiss(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	var got testUser
	found, err := flickoredis.Get(ctx, c, flickoredis.UserKey("missing"), &got)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if found {
		t.Fatal("Get() should return false for miss")
	}
}

func TestCacheDelete(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	flickoredis.Set(ctx, c, flickoredis.UserKey("del"), testUser{ID: "del"}, 0)
	c.Delete(ctx, flickoredis.UserKey("del"))

	var got testUser
	found, _ := flickoredis.Get(ctx, c, flickoredis.UserKey("del"), &got)
	if found {
		t.Fatal("Get() should miss after Delete()")
	}
}

func TestCacheTTL(t *testing.T) {
	rdb, mr := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	flickoredis.Set(ctx, c, "test:ttl", "data", 5*time.Second)
	mr.FastForward(6 * time.Second)

	var got string
	found, _ := flickoredis.Get(ctx, c, "test:ttl", &got)
	if found {
		t.Fatal("cache entry should have expired")
	}
}

func TestCacheChannelMembers(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	err := c.SetChannelMembers(ctx, "ch1", []string{"u1", "u2", "u3"}, 0)
	if err != nil {
		t.Fatalf("SetChannelMembers() error = %v", err)
	}

	members, err := c.GetChannelMembers(ctx, "ch1")
	if err != nil {
		t.Fatalf("GetChannelMembers() error = %v", err)
	}
	if len(members) != 3 {
		t.Fatalf("len = %d, want 3", len(members))
	}

	// IsMember check.
	ok, err := c.IsChannelMember(ctx, "ch1", "u2")
	if err != nil {
		t.Fatalf("IsChannelMember() error = %v", err)
	}
	if !ok {
		t.Fatal("u2 should be a member")
	}

	ok, _ = c.IsChannelMember(ctx, "ch1", "u99")
	if ok {
		t.Fatal("u99 should not be a member")
	}
}

func TestCacheAddRemoveChannelMember(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	c.SetChannelMembers(ctx, "ch2", []string{"u1"}, 0)
	c.AddChannelMember(ctx, "ch2", "u2")

	members, _ := c.GetChannelMembers(ctx, "ch2")
	if len(members) != 2 {
		t.Fatalf("After add: len = %d, want 2", len(members))
	}

	c.RemoveChannelMember(ctx, "ch2", "u1")
	members, _ = c.GetChannelMembers(ctx, "ch2")
	if len(members) != 1 {
		t.Fatalf("After remove: len = %d, want 1", len(members))
	}
}

func TestCacheGetChannelMembersMiss(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	members, err := c.GetChannelMembers(ctx, "nonexistent")
	if err != nil {
		t.Fatalf("GetChannelMembers() error = %v", err)
	}
	if members != nil {
		t.Fatal("GetChannelMembers() should return nil for missing key")
	}
}

// ---------- Key format tests ----------

func TestKeyFormats(t *testing.T) {
	tests := []struct {
		fn   func(string) string
		arg  string
		want string
	}{
		{flickoredis.UserKey, "abc", "flicko:cache:user:abc"},
		{flickoredis.ChannelKey, "xyz", "flicko:cache:channel:xyz"},
		{flickoredis.ChannelMembersKey, "ch1", "flicko:channel:members:ch1"},
	}
	for _, tt := range tests {
		got := tt.fn(tt.arg)
		if got != tt.want {
			t.Errorf("%s(%q) = %q, want %q", "KeyFunc", tt.arg, got, tt.want)
		}
	}
}

// ---------- JSON round-trip test ----------

func TestCacheJSONRoundTrip(t *testing.T) {
	rdb, _ := setup(t)
	c := flickoredis.NewCache(rdb)
	ctx := context.Background()

	type complex struct {
		Items []string       `json:"items"`
		Meta  map[string]int `json:"meta"`
	}

	orig := complex{
		Items: []string{"a", "b", "c"},
		Meta:  map[string]int{"x": 1, "y": 2},
	}

	flickoredis.Set(ctx, c, "test:complex", orig, 0)

	var got complex
	found, err := flickoredis.Get(ctx, c, "test:complex", &got)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if !found {
		t.Fatal("should be found")
	}

	origJSON, _ := json.Marshal(orig)
	gotJSON, _ := json.Marshal(got)
	if string(origJSON) != string(gotJSON) {
		t.Errorf("round-trip mismatch:\n  orig: %s\n  got:  %s", origJSON, gotJSON)
	}
}

// ---------- TTL constants test ----------

func TestTTLConstants(t *testing.T) {
	if flickoredis.PresenceTTL != 120*time.Second {
		t.Errorf("PresenceTTL = %v, want 120s", flickoredis.PresenceTTL)
	}
	if flickoredis.TypingTTL != 8*time.Second {
		t.Errorf("TypingTTL = %v, want 8s", flickoredis.TypingTTL)
	}
	if flickoredis.IdempotencyTTL != 300*time.Second {
		t.Errorf("IdempotencyTTL = %v, want 300s", flickoredis.IdempotencyTTL)
	}
	if flickoredis.CacheTTL != 300*time.Second {
		t.Errorf("CacheTTL = %v, want 300s", flickoredis.CacheTTL)
	}
}
