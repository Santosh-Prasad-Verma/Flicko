package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestPermissionService_InvalidateServerCache(t *testing.T) {
	mockCache := NewMockCache()
	service := services.NewPermissionService(nil, mockCache)

	serverID := uuid.New()
	versionKey := fmt.Sprintf("perm_version:%s", serverID.String())

	ctx := context.Background()

	// Invalidate Server Cache (bumps version)
	err := service.InvalidateServerCache(ctx, serverID)
	assert.NoError(t, err)

	// Value stored in mockCache for versionKey should now be "1" (or incremented)
	val, err := mockCache.Get(ctx, versionKey)
	assert.NoError(t, err)
	assert.Equal(t, "1", val)
}

func TestPermissionService_CacheKeyFormatting(t *testing.T) {
	mockCache := NewMockCache()

	serverID := uuid.New()
	channelID := uuid.New()
	userID := uuid.New()
	permissionName := "VIEW_CHANNEL"

	ctx := context.Background()
	_ = mockCache.Set(ctx, fmt.Sprintf("chan_srv:%s", channelID.String()), serverID.String(), 24*time.Hour)
	_ = mockCache.Set(ctx, fmt.Sprintf("perm_version:%s", serverID.String()), "5", 24*time.Hour)

	// Expected cache key format: perm:{serverID}:{version}:{userID}:{channelID}:{permissionName}
	expectedCacheKey := fmt.Sprintf("perm:%s:5:%s:%s:VIEW_CHANNEL", serverID.String(), userID.String(), channelID.String())

	// Pre-populate cache with "true"
	_ = mockCache.Set(ctx, expectedCacheKey, "true", 5*time.Minute)

	service := services.NewPermissionService(nil, mockCache)

	// Call HasPermission - should hit the cache using our version-tagged key without DB access!
	hasPerm, err := service.HasPermission(ctx, userID, channelID, permissionName)
	assert.NoError(t, err)
	assert.True(t, hasPerm)
}
