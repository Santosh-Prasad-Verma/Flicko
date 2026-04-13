package services_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockPermissionService for Crosspost testing
type MockPermissionService struct {
	mock.Mock
}

func (m *MockPermissionService) HasPermission(ctx context.Context, userID, channelID uuid.UUID, permission string) (bool, error) {
	args := m.Called(ctx, userID, channelID, permission)
	return args.Bool(0), args.Error(1)
}
func (m *MockPermissionService) InvalidatePermissionCache(ctx context.Context, userID, channelID uuid.UUID) error {
	return nil
}

// MockAuditLogService for testing
type MockAuditLogService struct {
	mock.Mock
}

func (m *MockAuditLogService) CreateLog(ctx context.Context, serverID string, actorID *string, actionType models.AuditLogAction, targetType string, targetID, reason *string, changes map[string]interface{}) error {
	return nil
}

func (m *MockAuditLogService) GetLogs(ctx context.Context, serverID, executorID string, actionType, actorID, targetType *string, limit, offset int) ([]*models.AuditLog, error) {
	return nil, nil
}

func TestCrosspostService_Validation(t *testing.T) {
	// Property 18: Crossposting Validation
	// Tests that users without SEND_MESSAGES are rejected from crossposting.

	ctx := context.Background()

	mockPerms := new(MockPermissionService)
	// Setup a rejection scenario
	mockPerms.On("HasPermission", mock.Anything, mock.Anything, mock.Anything, "SEND_MESSAGES").Return(false, nil)

	mockAudit := new(MockAuditLogService)

	// We pass nil for DB since it should fail before hitting the DB
	svc := services.NewCrosspostService(nil, mockPerms, mockAudit)

	userUUID := "123e4567-e89b-12d3-a456-426614174000"
	targetChanUUID := "123e4567-e89b-12d3-a456-426614174001"
	origMsgUUID := "123e4567-e89b-12d3-a456-426614174002"

	msg, err := svc.CrosspostMessage(ctx, userUUID, origMsgUUID, targetChanUUID)

	assert.Error(t, err)
	assert.Nil(t, msg)
	assert.Contains(t, err.Error(), "does not have SEND_MESSAGES permission")
	mockPerms.AssertExpectations(t)
}
