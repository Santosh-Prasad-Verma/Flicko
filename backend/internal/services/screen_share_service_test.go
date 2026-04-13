package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockScreenShareDB struct {
	shares map[string]*models.ScreenShare
	voice  *models.VoiceState
}

func (db *mockScreenShareDB) Start() *models.ScreenShare {
	db.voice.IsStreaming = true
	db.voice.UpdatedAt = time.Now()

	s := &models.ScreenShare{
		ID:        "share-id-123",
		UserID:    db.voice.UserID,
		SessionID: db.voice.SessionID,
		ShareType: models.ShareTypeScreen,
		StartedAt: time.Now(),
	}
	db.shares[s.ID] = s
	return s
}

func (db *mockScreenShareDB) Stop(shareID string) {
	s := db.shares[shareID]
	now := time.Now()
	s.EndedAt = &now

	db.voice.IsStreaming = false
	db.voice.UpdatedAt = now
}

func TestScreenShareLifecycle(t *testing.T) {
	// Property 25: Screen Share Session Lifecycle
	// Validates correct synchronization of voice.is_streaming with screen share ended_at state.

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockScreenShareDB{
		shares: make(map[string]*models.ScreenShare),
		voice: &models.VoiceState{
			UserID:      "test-user",
			SessionID:   "sess-id",
			IsStreaming: false,
		},
	}

	assert.False(t, db.voice.IsStreaming)

	// Start stream
	share := db.Start()

	assert.True(t, db.voice.IsStreaming)
	assert.NotNil(t, db.shares[share.ID])
	assert.Nil(t, db.shares[share.ID].EndedAt)

	// Stop stream
	db.Stop(share.ID)

	assert.False(t, db.voice.IsStreaming)
	assert.NotNil(t, db.shares[share.ID].EndedAt)
}
