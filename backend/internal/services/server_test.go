package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestServerService_CreateServer(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	mp := new(MockPermissionService)
	ma := new(MockAuditLogService)
	
	svc := services.NewServerService(db, mc, mp, ma)
	ctx := context.Background()
	ownerID := uuid.New().String()

	// Invalid Name length
	_, err := svc.CreateServer(ctx, ownerID, "a", "desc", "url")
	assert.Error(t, err)

	// Valid length - Mock DB
	tx := new(MockTx)
	db.On("Begin", ctx).Return(tx, nil).Once()
	tx.On("Rollback", ctx).Return(nil).Maybe()

	ownerUUID, _ := uuid.Parse(ownerID)
	row := NewMockRow(uuid.New().String(), "Server Name", "desc", ownerID)
	tx.On("QueryRow", ctx, mock.Anything, "Server Name", "desc", ownerUUID, "url").Return(row).Once()
	
	// Member insert (matches two args in Exec: server.ID, ownerUUID)
	tx.On("Exec", ctx, mock.Anything, mock.Anything, ownerUUID).Return(pgconn.NewCommandTag("INSERT 1"), nil).Once()
	
	// Welcome settings insert (matches one arg in Exec: server.ID)
	tx.On("Exec", ctx, mock.Anything, mock.Anything).Return(pgconn.NewCommandTag("INSERT 1"), nil).Once()
	
	tx.On("Commit", ctx).Return(nil).Once()
	mc.On("SetJSON", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()
	ma.On("CreateLog", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	server, err := svc.CreateServer(ctx, ownerID, "Server Name", "desc", "url")
	assert.NoError(t, err)
	assert.NotNil(t, server)

	db.AssertExpectations(t)
	tx.AssertExpectations(t)
}

func TestServerService_JoinServer(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	mp := new(MockPermissionService)
	ma := new(MockAuditLogService)
	
	svc := services.NewServerService(db, mc, mp, ma)
	ctx := context.Background()
	userID := uuid.New().String()
	userUUID, _ := uuid.Parse(userID)
	
	// Invalid ID
	_, err := svc.JoinServer(ctx, "invalid-uuid", "code")
	assert.Error(t, err)

	db.On("QueryRow", ctx, mock.Anything, "code", userUUID).Return(NewMockRow(false)).Once() // exists check
	db.On("QueryRow", ctx, mock.Anything, "code", userUUID).Return(NewMockRow(false)).Once() // isBanned check
	
	tx := new(MockTx)
	db.On("Begin", ctx).Return(tx, nil).Once()
	tx.On("Rollback", ctx).Return(nil).Maybe()
	
	// Lookup invite
	inviteServerID := uuid.New()
	tx.On("QueryRow", ctx, mock.Anything, "code").Return(NewMockRow(inviteServerID, 0, 10, nil)).Once()
	// Update invite
	tx.On("Exec", ctx, mock.Anything, "code").Return(pgconn.NewCommandTag("UPDATE 1"), nil).Once()
	// Add member
	tx.On("QueryRow", ctx, mock.Anything, inviteServerID, userUUID).Return(NewMockRow(uuid.New().String(), inviteServerID.String(), userID, "", []string{}, time.Now(), nil, nil)).Once()
	tx.On("Commit", ctx).Return(nil).Once()
	ma.On("CreateLog", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	_, err = svc.JoinServer(ctx, userID, "code")
	assert.NoError(t, err)
}

func TestServerService_KickMember(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	mp := new(MockPermissionService)
	ma := new(MockAuditLogService)

	svc := services.NewServerService(db, mc, mp, ma)
	ctx := context.Background()

	serverID := uuid.New()
	adminID := uuid.New()
	targetID := uuid.New()

	// Case 1: No Permission
	mp.On("HasServerPermission", ctx, adminID, serverID, "KICK_MEMBERS").Return(false, nil).Once()
	err := svc.KickMember(ctx, serverID.String(), targetID.String(), adminID.String(), "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unauthorized: missing KICK_MEMBERS permission")

	// Set up cache expectations for subsequent cases
	mc.On("GetJSON", mock.Anything, mock.Anything, mock.Anything).Return(fmt.Errorf("cache miss")).Maybe()
	mc.On("SetJSON", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	// Case 2: Kick Owner (Forbidden)
	mp.On("HasServerPermission", ctx, adminID, serverID, "KICK_MEMBERS").Return(true, nil).Once()
	row := NewMockRow(serverID.String(), "Test Server", "Desc", targetID.String())
	db.On("QueryRow", ctx, mock.Anything, serverID.String()).Return(row).Once()

	err = svc.KickMember(ctx, serverID.String(), targetID.String(), adminID.String(), "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot kick the server owner")

	// Case 3: Success
	mp.On("HasServerPermission", ctx, adminID, serverID, "KICK_MEMBERS").Return(true, nil).Once()
	
	// Mock owner check (target is NOT owner)
	row2 := NewMockRow(serverID.String(), "Test Server", "Desc", uuid.New().String())
	db.On("QueryRow", ctx, mock.Anything, serverID.String()).Return(row2).Once()

	// Mock DELETE
	db.On("Exec", ctx, mock.Anything, serverID, targetID).Return(pgconn.NewCommandTag("DELETE 1"), nil).Once()
	
	// Mock Audit Log
	ma.On("CreateLog", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	err = svc.KickMember(ctx, serverID.String(), targetID.String(), adminID.String(), "")
	assert.NoError(t, err)
	
	db.AssertExpectations(t)
	mp.AssertExpectations(t)
	ma.AssertExpectations(t)
}

func TestServerService_BanMember(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	mp := new(MockPermissionService)
	ma := new(MockAuditLogService)

	svc := services.NewServerService(db, mc, mp, ma)
	ctx := context.Background()

	serverID := uuid.New()
	adminID := uuid.New()
	targetID := uuid.New()

	// Success case
	mp.On("HasServerPermission", ctx, adminID, serverID, "BAN_MEMBERS").Return(true, nil).Once()

	// Set up cache expectations for GetServer
	mc.On("GetJSON", mock.Anything, mock.Anything, mock.Anything).Return(fmt.Errorf("cache miss")).Maybe()
	mc.On("SetJSON", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	// Mock owner check (target is NOT owner)
	row := NewMockRow(serverID.String(), "Test Server", "Desc", uuid.New().String())
	db.On("QueryRow", ctx, mock.Anything, serverID.String()).Return(row).Once()

	// Mock Transaction
	tx := new(MockTx)
	db.On("Begin", ctx).Return(tx, nil).Once()
	
	// Ban insert
	tx.On("Exec", ctx, mock.Anything, serverID, targetID, adminID, "").Return(pgconn.NewCommandTag("INSERT 1"), nil).Once()
	// Member delete
	tx.On("Exec", ctx, mock.Anything, serverID, targetID).Return(pgconn.NewCommandTag("DELETE 1"), nil).Once()
	// Commit
	tx.On("Commit", ctx).Return(nil).Once()
	// Rollback defer (called if commit fails or before) - in our success case, commit is called.
	tx.On("Rollback", ctx).Return(nil).Maybe()

	// Mock Audit Log
	ma.On("CreateLog", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	err := svc.BanMember(ctx, serverID.String(), targetID.String(), adminID.String(), "")
	assert.NoError(t, err)

	db.AssertExpectations(t)
	mp.AssertExpectations(t)
	ma.AssertExpectations(t)
	tx.AssertExpectations(t)
}

func TestServerService_UnbanMember(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	mp := new(MockPermissionService)
	ma := new(MockAuditLogService)

	svc := services.NewServerService(db, mc, mp, ma)
	ctx := context.Background()

	serverID := uuid.New()
	adminID := uuid.New()
	targetID := uuid.New()

	// Success case
	mp.On("HasServerPermission", ctx, adminID, serverID, "BAN_MEMBERS").Return(true, nil).Once()

	// Mock DELETE from bans
	db.On("Exec", ctx, mock.Anything, serverID, targetID).Return(pgconn.NewCommandTag("DELETE 1"), nil).Once()

	// Mock Audit Log
	ma.On("CreateLog", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil).Maybe()

	err := svc.UnbanMember(ctx, serverID.String(), targetID.String(), adminID.String())
	assert.NoError(t, err)

	db.AssertExpectations(t)
	mp.AssertExpectations(t)
	ma.AssertExpectations(t)
}
