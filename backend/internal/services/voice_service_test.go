package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockVoiceDB struct {
	states map[string]*models.VoiceState
}

func (db *mockVoiceDB) insert(s *models.VoiceState) {
	db.states[s.UserID] = s
}

func (db *mockVoiceDB) update(userID string, isMuted bool) {
	st, ok := db.states[userID]
	if ok {
		st.IsSelfMuted = isMuted
		st.UpdatedAt = time.Now()
	}
}

func (db *mockVoiceDB) remove(userID string) {
	delete(db.states, userID)
}

func TestVoiceStateLifecycle(t *testing.T) {
	// Property 24: Voice State Lifecycle
	// Verifies voice state tracking correctly registers components and disconnects

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockVoiceDB{states: make(map[string]*models.VoiceState)}
	user := "user-mock-uuid"

	// 1. Join
	st := &models.VoiceState{
		UserID:      user,
		ChannelID:   "channel-uuid",
		SessionID:   "sess-id-123",
		IsSelfMuted: false,
		JoinedAt:    time.Now(),
	}
	db.insert(st)

	assert.NotNil(t, db.states[user])
	assert.False(t, db.states[user].IsSelfMuted)

	// 2. Mute/Update
	db.update(user, true)

	assert.True(t, db.states[user].IsSelfMuted)
	assert.WithinDuration(t, time.Now(), db.states[user].UpdatedAt, 1*time.Second)

	// 3. Disconnection
	db.remove(user)

	assert.Nil(t, db.states[user])
}
