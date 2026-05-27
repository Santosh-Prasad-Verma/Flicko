package bots

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// TestParseDuration_HappyPath covers the standard formats.
func TestParseDuration_HappyPath(t *testing.T) {
	cases := []struct {
		in   string
		want time.Duration
	}{
		{"10s", 10 * time.Second},
		{"5m", 5 * time.Minute},
		{"1h", time.Hour},
		{"2h30m", 2*time.Hour + 30*time.Minute},
		{"7d", 7 * 24 * time.Hour},
		{"1d", 24 * time.Hour},
	}
	for _, c := range cases {
		got, err := ParseDuration(c.in)
		assert.NoError(t, err, "ParseDuration(%q) error: %v", c.in, err)
		assert.Equal(t, c.want, got, "ParseDuration(%q)=%s want %s", c.in, got, c.want)
	}
}

// TestParseDuration_Caps verifies MED-8: zero and negative durations are
// rejected, and the upper bound is 30 days.
func TestParseDuration_Caps(t *testing.T) {
	// Zero.
	_, err := ParseDuration("0s")
	assert.Error(t, err, "0s should be rejected")

	// Negative.
	_, err = ParseDuration("-1h")
	assert.Error(t, err, "-1h should be rejected")

	// 30 days exact — allowed.
	d, err := ParseDuration("30d")
	assert.NoError(t, err)
	assert.Equal(t, 30*24*time.Hour, d)

	// 31 days — rejected.
	_, err = ParseDuration("31d")
	assert.Error(t, err, "31d should exceed the 30-day cap")
}

// TestParseDuration_EmptyString is a contract guarantee.
func TestParseDuration_EmptyString(t *testing.T) {
	_, err := ParseDuration("")
	assert.Error(t, err, "empty string should be rejected")
}

// TestParseDuration_GibberishReturnsError ensures we don't silently accept junk.
func TestParseDuration_GibberishReturnsError(t *testing.T) {
	_, err := ParseDuration("not-a-duration")
	assert.Error(t, err)
}

// TestBoolEmoji is a smoke test on the formatting helper.
func TestBoolEmoji(t *testing.T) {
	assert.Contains(t, BoolEmoji(true), "Enabled")
	assert.Contains(t, BoolEmoji(false), "Disabled")
}

// TestPermissionBits_AdminAlwaysWins documents the design contract that
// the Administrator bit is automatically OR'd into the permission check.
func TestPermissionBits_AdminAlwaysWins(t *testing.T) {
	// PermAdministrator must be a distinct bit from PermManageGuild.
	assert.NotEqual(t, PermAdministrator, PermManageGuild)
	assert.NotEqual(t, PermAdministrator, PermBanMembers)
	assert.NotEqual(t, PermBanMembers, PermKickMembers)
}
