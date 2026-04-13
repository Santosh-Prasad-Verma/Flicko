package abuse

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

func testRedis(t *testing.T) (*miniredis.Miniredis, redis.Cmdable) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { _ = rdb.Close() })
	return mr, rdb
}

func lowThresholds() Thresholds {
	return Thresholds{
		DupeMaxCount:    3,
		DupeWindow:      10 * time.Second,
		FreqMaxCount:    5,
		FreqWindow:      10 * time.Second,
		CrossChanMax:    3,
		CrossChanWindow: 30 * time.Second,
		MassDMMax:       3,
		MassDMWindow:    30 * time.Second,
		LinkMax:         2,
		LinkWindow:      60 * time.Second,
	}
}

func check(d *Detector, userID, channelID, content string) CheckResult {
	return d.Check(context.Background(), CheckInput{
		UserID:    userID,
		ChannelID: channelID,
		Content:   content,
	})
}

func checkDM(d *Detector, userID, recipientID, content string) CheckResult {
	return d.Check(context.Background(), CheckInput{
		UserID:      userID,
		ChannelID:   "dm-channel",
		Content:     content,
		IsDM:        true,
		RecipientID: recipientID,
	})
}

// ─────────────────────────────────────────────────────────────────────────────
// hashContent tests
// ─────────────────────────────────────────────────────────────────────────────

func TestHashContent_NormalisesWhitespace(t *testing.T) {
	h1 := hashContent("hello  world")
	h2 := hashContent("hello world")
	h3 := hashContent("HELLO   WORLD")
	if h1 != h2 || h2 != h3 {
		t.Fatalf("expected identical hashes: %s, %s, %s", h1, h2, h3)
	}
}

func TestHashContent_DifferentContent(t *testing.T) {
	h1 := hashContent("hello")
	h2 := hashContent("world")
	if h1 == h2 {
		t.Fatal("expected different hashes for different content")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// containsLinks tests
// ─────────────────────────────────────────────────────────────────────────────

func TestContainsLinks(t *testing.T) {
	tests := []struct {
		content string
		want    bool
	}{
		{"no links here", false},
		{"check https://example.com", true},
		{"join http://example.org/path", true},
		{"discord.gg/invite123", true},
		{"discordapp.com/invite/abc", true},
		{"discord.com/invite/abc", true},
		{"t.me/groupname", true},
		{"telegram.me/groupname", true},
		{"plain text without urls", false},
	}
	for _, tt := range tests {
		if got := containsLinks(tt.content); got != tt.want {
			t.Errorf("containsLinks(%q) = %v, want %v", tt.content, got, tt.want)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Duplicate message spam
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_DuplicateSpam_UnderThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	// 2 identical messages — under threshold of 3.
	r1 := check(d, "user1", "ch1", "hello world")
	r2 := check(d, "user1", "ch1", "hello world")
	if r1.Flagged || r2.Flagged {
		t.Fatal("should not flag under threshold")
	}
}

func TestDetector_DuplicateSpam_AtThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	// Send 3 identical messages (threshold = 3).
	_ = check(d, "user1", "ch1", "spam spam")
	_ = check(d, "user1", "ch1", "spam spam")
	r3 := check(d, "user1", "ch1", "spam spam")

	if !r3.Flagged {
		t.Fatal("expected duplicate spam to be flagged")
	}
	if r3.Reason != ReasonDuplicateSpam {
		t.Fatalf("expected reason %s, got %s", ReasonDuplicateSpam, r3.Reason)
	}
	if r3.Action != ActionShadowMute {
		t.Fatalf("expected shadow mute action, got %s", r3.Action)
	}
}

func TestDetector_DuplicateSpam_DifferentContent_NotFlagged(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "message one")
	_ = check(d, "user1", "ch1", "message two")
	r3 := check(d, "user1", "ch1", "message three")

	if r3.Flagged {
		t.Fatal("different content should not trigger duplicate detection")
	}
}

func TestDetector_DuplicateSpam_DifferentUsers_NotFlagged(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "same text")
	_ = check(d, "user2", "ch1", "same text")
	r3 := check(d, "user3", "ch1", "same text")

	if r3.Flagged {
		t.Fatal("different users sending same content should not flag")
	}
}

func TestDetector_DuplicateSpam_ExpiresAfterWindow(t *testing.T) {
	mr, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "repeat")
	_ = check(d, "user1", "ch1", "repeat")

	// Fast-forward past the 10s window.
	mr.FastForward(11 * time.Second)

	r3 := check(d, "user1", "ch1", "repeat")
	if r3.Flagged {
		t.Fatal("counter should have expired, should not flag")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — High-frequency flooding
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_HighFrequency_UnderThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	for i := 0; i < 4; i++ {
		r := check(d, "user1", "ch1", fmt.Sprintf("msg %d", i))
		if r.Flagged {
			t.Fatalf("should not flag at count %d (threshold 5)", i+1)
		}
	}
}

func TestDetector_HighFrequency_AtThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	var last CheckResult
	for i := 0; i < 5; i++ {
		last = check(d, "user1", "ch1", fmt.Sprintf("unique msg %d", i))
	}

	if !last.Flagged {
		t.Fatal("expected high frequency to be flagged at threshold")
	}
	if last.Reason != ReasonHighFrequency {
		t.Fatalf("expected reason %s, got %s", ReasonHighFrequency, last.Reason)
	}
	if last.Action != ActionMute {
		t.Fatalf("expected mute action, got %s", last.Action)
	}
}

func TestDetector_HighFrequency_ExpiresAfterWindow(t *testing.T) {
	mr, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	for i := 0; i < 4; i++ {
		_ = check(d, "user1", "ch1", fmt.Sprintf("msg %d", i))
	}

	// Fast-forward past window.
	mr.FastForward(11 * time.Second)

	r := check(d, "user1", "ch1", "one more")
	if r.Flagged {
		t.Fatal("counter should have expired, should not flag")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Cross-channel spam
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_CrossChannel_UnderThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "hi")
	r := check(d, "user1", "ch2", "hi")

	if r.Flagged {
		t.Fatal("2 channels should not flag (threshold 3)")
	}
}

func TestDetector_CrossChannel_AtThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "spam")
	_ = check(d, "user1", "ch2", "spam")
	r := check(d, "user1", "ch3", "spam")

	if !r.Flagged {
		t.Fatal("expected cross-channel spam to be flagged")
	}
	if r.Reason != ReasonCrossChannel {
		t.Fatalf("expected reason %s, got %s", ReasonCrossChannel, r.Reason)
	}
}

func TestDetector_CrossChannel_SameChannel_NotFlagged(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	// All messages in the same channel — SADD is idempotent.
	for i := 0; i < 5; i++ {
		r := check(d, "user1", "ch1", fmt.Sprintf("msg %d", i))
		if r.Reason == ReasonCrossChannel {
			t.Fatalf("same channel should not trigger cross-channel, iter %d", i)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Mass DM
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_MassDM_UnderThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = checkDM(d, "user1", "recipient1", "hi")
	r := checkDM(d, "user1", "recipient2", "hi")

	if r.Flagged {
		t.Fatal("2 DM recipients should not flag (threshold 3)")
	}
}

func TestDetector_MassDM_AtThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = checkDM(d, "user1", "r1", "hi")
	_ = checkDM(d, "user1", "r2", "hi")
	r := checkDM(d, "user1", "r3", "hi again")

	if !r.Flagged {
		t.Fatal("expected mass DM to be flagged")
	}
	if r.Reason != ReasonMassDM {
		t.Fatalf("expected reason %s, got %s", ReasonMassDM, r.Reason)
	}
	if r.Action != ActionShadowMute {
		t.Fatalf("expected shadow mute, got %s", r.Action)
	}
}

func TestDetector_MassDM_NonDM_NeverFlags(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	// Non-DM messages (IsDM=false) should never trigger mass DM.
	for i := 0; i < 10; i++ {
		r := check(d, "user1", fmt.Sprintf("ch%d", i), "hi")
		if r.Reason == ReasonMassDM {
			t.Fatal("non-DM should not trigger mass DM detection")
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Invite/link spam
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_LinkSpam_UnderThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "check https://example.com")
	r := check(d, "user1", "ch1", "also https://foo.bar")

	if r.Reason == ReasonInviteLinkSpam {
		t.Fatal("2 links should not flag (threshold > 2)")
	}
}

func TestDetector_LinkSpam_AtThreshold(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	for i := 0; i < 3; i++ {
		r := check(d, "user1", "ch1", fmt.Sprintf("link https://example%d.com", i))
		if i < 2 && r.Reason == ReasonInviteLinkSpam {
			t.Fatalf("should not flag at count %d", i+1)
		}
		if i == 2 {
			if !r.Flagged {
				t.Fatal("expected link spam to be flagged")
			}
			if r.Reason != ReasonInviteLinkSpam {
				t.Fatalf("expected reason %s, got %s", ReasonInviteLinkSpam, r.Reason)
			}
		}
	}
}

func TestDetector_LinkSpam_NoLinks_NotCounted(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	// Many messages without links — link counter should stay at 0.
	for i := 0; i < 10; i++ {
		r := check(d, "user1", "ch1", "plain text message")
		if r.Reason == ReasonInviteLinkSpam {
			t.Fatal("messages without links should not trigger link spam")
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Priority ordering
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_HighFrequencyTakesPriorityOverDuplicate(t *testing.T) {
	_, rdb := testRedis(t)
	th := lowThresholds()
	// Make both trigger at count 3.
	th.FreqMaxCount = 3
	th.DupeMaxCount = 3
	d := NewDetector(rdb, th, zap.NewNop())

	// Send 3 identical messages — both duplicate AND frequency should fire.
	_ = check(d, "user1", "ch1", "same")
	_ = check(d, "user1", "ch1", "same")
	r := check(d, "user1", "ch1", "same")

	if !r.Flagged {
		t.Fatal("expected flagged")
	}
	// High-frequency is evaluated first (higher severity).
	if r.Reason != ReasonHighFrequency {
		t.Fatalf("expected high frequency to take priority, got %s", r.Reason)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Redis failure graceful degradation
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_RedisDown_ReturnsNotFlagged(t *testing.T) {
	mr, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	mr.Close()

	r := check(d, "user1", "ch1", "hello")
	if r.Flagged {
		t.Fatal("Redis failure should not flag messages")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Content normalisation
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_DuplicateSpam_IgnoresWhitespaceDifferences(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	_ = check(d, "user1", "ch1", "hello  world")
	_ = check(d, "user1", "ch1", "Hello World")
	r := check(d, "user1", "ch1", "HELLO   WORLD")

	if !r.Flagged {
		t.Fatal("whitespace-normalised duplicates should be detected")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Discord-style invite links
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_LinkSpam_DiscordInvites(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	invites := []string{
		"join discord.gg/abc123",
		"click discordapp.com/invite/xyz",
		"also discord.com/invite/test",
	}

	var last CheckResult
	for _, msg := range invites {
		last = check(d, "user1", "ch1", msg)
	}

	if !last.Flagged || last.Reason != ReasonInviteLinkSpam {
		t.Fatalf("discord invite links should trigger link spam, got flagged=%v reason=%s",
			last.Flagged, last.Reason)
	}
}

func TestDetector_LinkSpam_TelegramLinks(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	msgs := []string{
		"join t.me/group1",
		"also telegram.me/group2",
		"and t.me/group3",
	}

	var last CheckResult
	for _, msg := range msgs {
		last = check(d, "user1", "ch1", msg)
	}

	if !last.Flagged || last.Reason != ReasonInviteLinkSpam {
		t.Fatalf("telegram links should trigger link spam, got flagged=%v reason=%s",
			last.Flagged, last.Reason)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector — Large-scale simulation
// ─────────────────────────────────────────────────────────────────────────────

func TestDetector_MixedTraffic_NoFalsePositives(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, DefaultThresholds(), zap.NewNop())

	// 30 unique messages in the same channel — should be fine.
	for i := 0; i < 30; i++ {
		r := check(d, "user1", "ch1", fmt.Sprintf("unique message %d", i))
		if r.Flagged {
			t.Fatalf("false positive at iteration %d: reason=%s", i, r.Reason)
		}
	}
}

func TestDetector_LongContent_HashesCorrectly(t *testing.T) {
	_, rdb := testRedis(t)
	d := NewDetector(rdb, lowThresholds(), zap.NewNop())

	longMsg := strings.Repeat("A", 2000)

	_ = check(d, "user1", "ch1", longMsg)
	_ = check(d, "user1", "ch1", longMsg)
	r := check(d, "user1", "ch1", longMsg)

	if !r.Flagged {
		t.Fatal("long duplicate messages should still be detected")
	}
}
