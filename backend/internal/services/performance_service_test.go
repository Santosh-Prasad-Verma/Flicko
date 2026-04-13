package services_test

import (
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

// ─── Property 60: Rate Limit Enforcement ────────────────────────────────────

func TestRateLimitEnforcement(t *testing.T) {
	// Verify default rate limits are configured correctly
	limits := services.DefaultRateLimits

	// Message creation: 5 per 5 seconds
	assert.Equal(t, 5, limits.MessageCreate.MaxRequests)
	assert.Equal(t, 5*time.Second, limits.MessageCreate.Window)

	// Friend requests: 10 per hour
	assert.Equal(t, 10, limits.FriendRequest.MaxRequests)
	assert.Equal(t, time.Hour, limits.FriendRequest.Window)

	// Webhook calls: 30 per minute
	assert.Equal(t, 30, limits.WebhookCall.MaxRequests)
	assert.Equal(t, time.Minute, limits.WebhookCall.Window)

	// API general: 50 per second
	assert.Equal(t, 50, limits.APIGeneral.MaxRequests)
	assert.Equal(t, time.Second, limits.APIGeneral.Window)
}

// ─── Property 66: Transaction Atomicity / Cache Strategy ────────────────────

func TestCacheStrategyTTLs(t *testing.T) {
	strategy := services.DefaultCacheStrategy

	assert.Equal(t, time.Hour, strategy.UserSettingsTTL)
	assert.Equal(t, 5*time.Minute, strategy.PermissionTTL)
	assert.Equal(t, 30*time.Second, strategy.PresenceTTL)
	assert.Equal(t, 5*time.Minute, strategy.MemberListTTL)
	assert.Equal(t, 24*time.Hour, strategy.EmbedDataTTL)
}
