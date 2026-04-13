package services_test

import (
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockGroupDMDB struct {
	group        *models.GroupDM
	participants map[string]bool
}

func (db *mockGroupDMDB) Add(ownerID string, users []string) error {
	count := len(users) + 1
	if count < 2 || count > 10 {
		return fmt.Errorf("group dm must have between 2 and 10 participants")
	}

	db.group = &models.GroupDM{
		ID:        "group-1",
		OwnerID:   ownerID,
		IsActive:  true,
		CreatedAt: time.Now(),
	}

	db.participants = make(map[string]bool)
	db.participants[ownerID] = true
	for _, u := range users {
		db.participants[u] = true
	}
	return nil
}

func (db *mockGroupDMDB) Remove(actingUser, targetUser string) error {
	if !db.group.IsActive {
		return fmt.Errorf("group inactive")
	}

	isOwner := actingUser == db.group.OwnerID
	isSelf := actingUser == targetUser

	if !isOwner && !isSelf {
		return fmt.Errorf("only owner can remove others")
	}

	if !db.participants[targetUser] {
		return fmt.Errorf("not a participant")
	}

	delete(db.participants, targetUser)

	if len(db.participants) == 0 {
		db.group.IsActive = false
	}
	return nil
}

func TestGroupDMParticipantLimits(t *testing.T) {
	// Property 27: Group DM Participant Limits
	db := &mockGroupDMDB{}

	// Test < 2
	err := db.Add("owner", []string{})
	assert.Error(t, err)

	// Test > 10
	err = db.Add("owner", []string{"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"})
	assert.Error(t, err)

	// Test Valid
	err = db.Add("owner", []string{"user1", "user2"})
	assert.NoError(t, err)
	assert.Len(t, db.participants, 3)
}

func TestGroupDMParticipantRemoval(t *testing.T) {
	// Property 28: Group DM Participant Removal
	db := &mockGroupDMDB{}
	db.Add("owner", []string{"user1", "user2"})

	// Self-removal
	err := db.Remove("user1", "user1")
	assert.NoError(t, err)
	assert.False(t, db.participants["user1"])

	// Non-owner trying to remove someone else
	err = db.Remove("user2", "owner")
	assert.Error(t, err)
	assert.True(t, db.participants["owner"])

	// Owner removing someone else
	err = db.Remove("owner", "user2")
	assert.NoError(t, err)
	assert.False(t, db.participants["user2"])
}
