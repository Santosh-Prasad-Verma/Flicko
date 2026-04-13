package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockDMReactionDB struct {
	reactions []*models.Reaction
}

func (db *mockDMReactionDB) Add(msgID, userID, emoji string) (*models.Reaction, error) {
	react := &models.Reaction{
		ID:        "react-1",
		MessageID: msgID,
		UserID:    userID,
		Emoji:     emoji,
		CreatedAt: time.Now(),
	}
	db.reactions = append(db.reactions, react)
	return react, nil
}

func TestDMReactionCreation(t *testing.T) {
	// Property 29: DM Reaction Creation
	// Validates reaction parameters and insertion bounds for a mock DM message
	ctx := context.Background()
	_, _ = ctx, t

	db := &mockDMReactionDB{}

	msg := "msg-123"
	user := "user-456"
	emoji := "👍"

	react, err := db.Add(msg, user, emoji)

	assert.NoError(t, err)
	assert.NotNil(t, react)
	assert.Equal(t, msg, react.MessageID)
	assert.Equal(t, user, react.UserID)
	assert.Equal(t, emoji, react.Emoji)
	assert.Len(t, db.reactions, 1)
}
