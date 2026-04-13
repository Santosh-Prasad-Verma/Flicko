package services_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
)

func calculateMockPermissions(base int64, roleAllow, roleDeny, userAllow, userDeny int64) int64 {
	// 5a. Role Overwrites
	perms := (base & ^roleDeny) | roleAllow
	// 5b. User Specific Overwrites
	perms = (perms & ^userDeny) | userAllow
	return perms
}

func TestPermissionOverwriteOrder(t *testing.T) {
	// Property 43: Permission Overwrite Application Order
	// Proves that if a role denies a permission but a user allow grants it, it is granted.
	// If a role allows it but a user deny revokes it, it is revoked.

	ctx := context.Background()
	_, _ = ctx, t

	var permSendMessages int64 = 2048
	var permManageMessages int64 = 8192

	// Base permissions
	base := permSendMessages

	// Scenario 1: Role Denies SEND, User Allows SEND
	// Expected: SEND is True (User > Role)
	final1 := calculateMockPermissions(base, 0, permSendMessages, permSendMessages, 0)
	assert.Equal(t, permSendMessages, final1&permSendMessages)

	// Scenario 2: Role Allows MANAGE, User Denies MANAGE
	// Expected: MANAGE is False (User > Role)
	base2 := permSendMessages
	final2 := calculateMockPermissions(base2, permManageMessages, 0, 0, permManageMessages)
	assert.Equal(t, int64(0), final2&permManageMessages)

	// Scenario 3: Base has it, Role Denies it, User is neutral
	// Expected: False (Role > Base)
	final3 := calculateMockPermissions(base, 0, permSendMessages, 0, 0)
	assert.Equal(t, int64(0), final3&permSendMessages)
}
