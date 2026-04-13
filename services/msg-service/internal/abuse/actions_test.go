package abuse

import (
	"context"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Mock AbuseLogger
// ─────────────────────────────────────────────────────────────────────────────

type mockAbuseLogger struct {
	entries []LogEntry
}

func (m *mockAbuseLogger) LogAbuse(_ context.Context, entry LogEntry) error {
	m.entries = append(m.entries, entry)
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

func newTestEnforcer(t *testing.T) (*miniredis.Miniredis, *Enforcer, *mockAbuseLogger) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = rdb.Close() })
	logger := &mockAbuseLogger{}
	e := NewEnforcer(rdb, logger, zap.NewNop())
	return mr, e, logger
}

// ─────────────────────────────────────────────────────────────────────────────
// AutoMute tests
// ─────────────────────────────────────────────────────────────────────────────

func TestEnforcer_AutoMute_SetsKey(t *testing.T) {
	mr, e, _ := newTestEnforcer(t)

	err := e.AutoMute(context.Background(), "user1", 5*time.Minute, ReasonDuplicateSpam, "test")
	if err != nil {
		t.Fatalf("AutoMute error: %v", err)
	}

	// Key should exist in Redis.
	if !mr.Exists(mutedKeyPrefix + "user1") {
		t.Fatal("muted key should exist")
	}

	// TTL should be approximately 5 minutes.
	ttl := mr.TTL(mutedKeyPrefix + "user1")
	if ttl < 4*time.Minute || ttl > 6*time.Minute {
		t.Fatalf("unexpected TTL: %v", ttl)
	}
}

func TestEnforcer_AutoMute_LogsEntry(t *testing.T) {
	_, e, logger := newTestEnforcer(t)

	_ = e.AutoMute(context.Background(), "user1", 5*time.Minute, ReasonDuplicateSpam, "spammy")

	if len(logger.entries) != 1 {
		t.Fatalf("expected 1 log entry, got %d", len(logger.entries))
	}
	entry := logger.entries[0]
	if entry.UserID != "user1" {
		t.Fatalf("expected user1, got %s", entry.UserID)
	}
	if entry.Reason != ReasonDuplicateSpam {
		t.Fatalf("expected reason %s, got %s", ReasonDuplicateSpam, entry.Reason)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// IsUserMuted tests
// ─────────────────────────────────────────────────────────────────────────────

func TestEnforcer_IsUserMuted_True(t *testing.T) {
	_, e, _ := newTestEnforcer(t)

	_ = e.AutoMute(context.Background(), "user1", 5*time.Minute, ReasonHighFrequency, "flood")

	muted, err := e.IsUserMuted(context.Background(), "user1")
	if err != nil {
		t.Fatalf("IsUserMuted error: %v", err)
	}
	if !muted {
		t.Fatal("expected user to be muted")
	}
}

func TestEnforcer_IsUserMuted_False(t *testing.T) {
	_, e, _ := newTestEnforcer(t)

	muted, err := e.IsUserMuted(context.Background(), "user1")
	if err != nil {
		t.Fatalf("IsUserMuted error: %v", err)
	}
	if muted {
		t.Fatal("expected user to NOT be muted")
	}
}

func TestEnforcer_IsUserMuted_ExpiresAfterTTL(t *testing.T) {
	mr, e, _ := newTestEnforcer(t)

	_ = e.AutoMute(context.Background(), "user1", 2*time.Second, ReasonDuplicateSpam, "test")

	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if !muted {
		t.Fatal("should be muted immediately after AutoMute")
	}

	mr.FastForward(3 * time.Second)

	muted, _ = e.IsUserMuted(context.Background(), "user1")
	if muted {
		t.Fatal("mute should have expired")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// UnmuteUser tests
// ─────────────────────────────────────────────────────────────────────────────

func TestEnforcer_UnmuteUser(t *testing.T) {
	_, e, _ := newTestEnforcer(t)

	_ = e.AutoMute(context.Background(), "user1", 10*time.Minute, ReasonHighFrequency, "flood")

	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if !muted {
		t.Fatal("should be muted")
	}

	err := e.UnmuteUser(context.Background(), "user1")
	if err != nil {
		t.Fatalf("UnmuteUser error: %v", err)
	}

	muted, _ = e.IsUserMuted(context.Background(), "user1")
	if muted {
		t.Fatal("should be unmuted after UnmuteUser")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Execute tests
// ─────────────────────────────────────────────────────────────────────────────

func TestEnforcer_Execute_ActionNone(t *testing.T) {
	_, e, logger := newTestEnforcer(t)

	err := e.Execute(context.Background(), CheckResult{Action: ActionNone}, "user1")
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}
	if len(logger.entries) != 0 {
		t.Fatal("ActionNone should not log")
	}
}

func TestEnforcer_Execute_ActionWarn(t *testing.T) {
	_, e, logger := newTestEnforcer(t)

	err := e.Execute(context.Background(), CheckResult{
		Flagged: true,
		Action:  ActionWarn,
		Reason:  ReasonDuplicateSpam,
		Details: "test warning",
	}, "user1")
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}

	// Should log but NOT mute.
	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if muted {
		t.Fatal("warn should not mute")
	}
	if len(logger.entries) != 1 {
		t.Fatalf("expected 1 log entry, got %d", len(logger.entries))
	}
}

func TestEnforcer_Execute_ActionMute(t *testing.T) {
	_, e, logger := newTestEnforcer(t)

	err := e.Execute(context.Background(), CheckResult{
		Flagged:      true,
		Action:       ActionMute,
		Reason:       ReasonHighFrequency,
		Details:      "flood",
		MuteDuration: 5 * time.Minute,
	}, "user1")
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}

	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if !muted {
		t.Fatal("mute action should mute the user")
	}
	if len(logger.entries) != 1 {
		t.Fatalf("expected 1 log entry, got %d", len(logger.entries))
	}
}

func TestEnforcer_Execute_ActionShadowMute(t *testing.T) {
	_, e, _ := newTestEnforcer(t)

	err := e.Execute(context.Background(), CheckResult{
		Flagged:      true,
		Action:       ActionShadowMute,
		Reason:       ReasonMassDM,
		Details:      "mass DM",
		MuteDuration: 30 * time.Minute,
	}, "user1")
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}

	// Shadow mute sets the same Redis key.
	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if !muted {
		t.Fatal("shadow mute should set the muted key")
	}
}

func TestEnforcer_Execute_ActionKick_FallsBackToMute(t *testing.T) {
	_, e, _ := newTestEnforcer(t)

	err := e.Execute(context.Background(), CheckResult{
		Flagged:      true,
		Action:       ActionKick,
		Reason:       ReasonCrossChannel,
		Details:      "cross-channel spam",
		MuteDuration: 10 * time.Minute,
	}, "user1")
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}

	// Kick is not yet implemented — falls back to mute.
	muted, _ := e.IsUserMuted(context.Background(), "user1")
	if !muted {
		t.Fatal("kick fallback should mute the user")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Redis failure
// ─────────────────────────────────────────────────────────────────────────────

func TestEnforcer_IsUserMuted_RedisDown_ReturnsFalse(t *testing.T) {
	mr, e, _ := newTestEnforcer(t)
	mr.Close()

	muted, err := e.IsUserMuted(context.Background(), "user1")
	if err == nil {
		t.Fatal("expected error when Redis is down")
	}
	if muted {
		t.Fatal("should return false when Redis fails")
	}
}

func TestEnforcer_AutoMute_RedisDown_ReturnsError(t *testing.T) {
	mr, e, _ := newTestEnforcer(t)
	mr.Close()

	err := e.AutoMute(context.Background(), "user1", 5*time.Minute, ReasonHighFrequency, "test")
	if err == nil {
		t.Fatal("expected error when Redis is down")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Action.String()
// ─────────────────────────────────────────────────────────────────────────────

func TestAction_String(t *testing.T) {
	tests := []struct {
		action Action
		want   string
	}{
		{ActionNone, "none"},
		{ActionWarn, "warn"},
		{ActionMute, "mute"},
		{ActionShadowMute, "shadow_mute"},
		{ActionKick, "kick"},
		{ActionBan, "ban"},
		{Action(99), "unknown"},
	}
	for _, tt := range tests {
		if got := tt.action.String(); got != tt.want {
			t.Errorf("Action(%d).String() = %q, want %q", tt.action, got, tt.want)
		}
	}
}
