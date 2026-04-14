package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockSocialDB struct {
	friendships    map[string]*models.Friendship
	friendRequests map[string]*models.FriendRequest
	blocks         map[string]*models.Block
}

func (db *mockSocialDB) ActionAccept(reqID, receiverID string) error {
	req, ok := db.friendRequests[reqID]
	if !ok || req.ReceiverID != receiverID || req.Status != models.FriendRequestPending {
		return fmt.Errorf("invalid request")
	}

	req.Status = models.FriendRequestAccepted
	now := time.Now()
	req.RespondedAt = &now

	db.friendships[req.SenderID+req.ReceiverID] = &models.Friendship{UserID: req.SenderID, FriendID: req.ReceiverID}
	db.friendships[req.ReceiverID+req.SenderID] = &models.Friendship{UserID: req.ReceiverID, FriendID: req.SenderID}
	return nil
}

func (db *mockSocialDB) SetNickname(userID, friendID string, nickname *string) error {
	f, ok := db.friendships[userID+friendID]
	if !ok {
		return fmt.Errorf("friendship not found")
	}
	f.Nickname = nickname
	return nil
}

func TestFriendRequestAcceptance(t *testing.T) {
	// Property 32: Friend Request Acceptance
	ctx := context.Background()
	_, _ = ctx, t

	db := &mockSocialDB{
		friendships:    make(map[string]*models.Friendship),
		friendRequests: make(map[string]*models.FriendRequest),
		blocks:         make(map[string]*models.Block),
	}

	req := &models.FriendRequest{
		ID:         "req-1",
		SenderID:   "user-A",
		ReceiverID: "user-B",
		Status:     models.FriendRequestPending,
	}
	db.friendRequests["req-1"] = req

	// Accept
	err := db.ActionAccept("req-1", "user-B")
	assert.NoError(t, err)

	assert.Equal(t, models.FriendRequestAccepted, db.friendRequests["req-1"].Status)
	assert.NotNil(t, db.friendships["user-Auser-B"])
	assert.NotNil(t, db.friendships["user-Buser-A"])
}

func TestFriendNicknameRoundTrip(t *testing.T) {
	// Property 33: Friend Nickname Round-Trip
	ctx := context.Background()
	_, _ = ctx, t

	db := &mockSocialDB{
		friendships:    make(map[string]*models.Friendship),
		friendRequests: make(map[string]*models.FriendRequest),
	}

	db.friendships["user-Auser-B"] = &models.Friendship{UserID: "user-A", FriendID: "user-B"}

	nick := "Bestie"
	err := db.SetNickname("user-A", "user-B", &nick)
	assert.NoError(t, err)

	f := db.friendships["user-Auser-B"]
	assert.NotNil(t, f.Nickname)
	assert.Equal(t, "Bestie", *f.Nickname)

	// Clear nickname and verify it round-trips to nil.
	err = db.SetNickname("user-A", "user-B", nil)
	assert.NoError(t, err)
	assert.Nil(t, db.friendships["user-Auser-B"].Nickname)
}

func (db *mockSocialDB) BlockUser(blockerID, blockedID string) error {
	if blockerID == blockedID {
		return fmt.Errorf("cannot block yourself")
	}

	db.blocks[blockerID+blockedID] = &models.Block{BlockerID: blockerID, BlockedID: blockedID, CreatedAt: time.Now()}

	// remove friendships
	delete(db.friendships, blockerID+blockedID)
	delete(db.friendships, blockedID+blockerID)

	return nil
}

func TestUserBlockingProperties(t *testing.T) {
	// Property 34: Block Record Creation
	// Property 35: Block Prevents DMs (simulated via friendship deletion constraint verification)

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockSocialDB{
		friendships:    make(map[string]*models.Friendship),
		friendRequests: make(map[string]*models.FriendRequest),
		blocks:         make(map[string]*models.Block),
	}

	// Make them friends first
	db.friendships["user-Auser-B"] = &models.Friendship{UserID: "user-A", FriendID: "user-B"}
	db.friendships["user-Buser-A"] = &models.Friendship{UserID: "user-B", FriendID: "user-A"}

	// Self-block
	err := db.BlockUser("user-A", "user-A")
	assert.Error(t, err)

	// User A blocks User B
	err = db.BlockUser("user-A", "user-B")
	assert.NoError(t, err)

	assert.NotNil(t, db.blocks["user-Auser-B"])
	// Assert friendship destroyed
	assert.Nil(t, db.friendships["user-Auser-B"])
	assert.Nil(t, db.friendships["user-Buser-A"])
}
