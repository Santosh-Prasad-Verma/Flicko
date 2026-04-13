package services_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestServerService_CreateServer(t *testing.T) {
	mc := &mockCache{store: make(map[string]string)}
	svc := services.NewServerService(nil, mc)

	ctx := context.Background()

	// Invalid Name length
	_, err := svc.CreateServer(ctx, "owner-id", "a", "desc", "url")
	assert.Error(t, err)

	// Valid length
	server, err := svc.CreateServer(ctx, "owner-id", "Valid Server Name", "desc", "url")
	assert.NoError(t, err)
	assert.Equal(t, "Valid Server Name", server.Name)
	assert.Equal(t, "owner-id", server.OwnerID)
}

func TestServerService_JoinServer(t *testing.T) {
	svc := services.NewServerService(nil, nil)
	ctx := context.Background()

	member, err := svc.JoinServer(ctx, "user-id", "valid-code")
	assert.NoError(t, err)
	assert.Equal(t, "user-id", member.UserID)

	_, err = svc.JoinServer(ctx, "user-id", "")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid invite code")
}
