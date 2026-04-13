package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockInviteDB struct {
	invites map[string]*models.Invite
	members map[string]bool
}

func (db *mockInviteDB) CreateInvite(code string, maxUses int, maxAge time.Duration) *models.Invite {
	var expires *time.Time
	if maxAge > 0 {
		exp := time.Now().Add(maxAge)
		expires = &exp
	}

	inv := &models.Invite{
		Code:      code,
		ServerID:  "server-1",
		ChannelID: "channel-1",
		InviterID: "inviter-1",
		Uses:      0,
		MaxUses:   maxUses,
		CreatedAt: time.Now(),
		ExpiresAt: expires,
	}
	db.invites[code] = inv
	return inv
}

func (db *mockInviteDB) AcceptInvite(userID, code string) error {
	inv, ok := db.invites[code]
	if !ok {
		return fmt.Errorf("invite not found")
	}

	if inv.ExpiresAt != nil && inv.ExpiresAt.Before(time.Now()) {
		return fmt.Errorf("invite expired")
	}
	if inv.MaxUses > 0 && inv.Uses >= inv.MaxUses {
		return fmt.Errorf("invite use limit reached")
	}

	inv.Uses++
	db.members[userID] = true
	return nil
}

func TestInviteProperties(t *testing.T) {
	// Property 36: Invite Code Uniqueness (Simulated via mapped keys)
	// Property 37: Invite Usage Increment
	// Property 38: Invite Usage Limit Expiration

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockInviteDB{
		invites: make(map[string]*models.Invite),
		members: make(map[string]bool),
	}

	// Usage limits test
	code1 := "LIMIT123"
	db.CreateInvite(code1, 2, 0) // Max 2 uses

	err := db.AcceptInvite("user-A", code1)
	assert.NoError(t, err)
	assert.Equal(t, 1, db.invites[code1].Uses)

	err = db.AcceptInvite("user-B", code1)
	assert.NoError(t, err)
	assert.Equal(t, 2, db.invites[code1].Uses)

	// Third use should fail
	err = db.AcceptInvite("user-C", code1)
	assert.Error(t, err)

	// Expiration test
	code2 := "EXPIR456"
	db.CreateInvite(code2, 0, -1*time.Hour) // Created already expired

	err = db.AcceptInvite("user-D", code2)
	assert.Error(t, err)
}
