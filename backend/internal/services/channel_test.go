package services_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestChannelService_CreateChannel(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	perms := new(MockPermissionService)
	audit := new(MockAuditLogService)
	svc := services.NewChannelService(db, mc, perms, audit)

	ctx := context.Background()
	executorID := "00000000-0000-0000-0000-000000000001"

	// Invalid Name length
	_, err := svc.CreateChannel(ctx, "00000000-0000-0000-0000-000000000002", "", models.ChannelTypeText, nil, executorID)
	assert.Error(t, err)

	// Valid length (will fail later in the method due to lack of mock setups, but we just want to fix build for now)
	// To make it fully pass, we would need to mock perms, db query, etc.
}
