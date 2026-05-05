package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestMessageService_CreateMessage(t *testing.T) {
	db := new(MockDatabaseClient)
	mc := NewMockCache()
	svc := services.NewMessageService(db, mc)
	ctx := context.Background()

	// Empty message
	_, err := svc.CreateMessage(ctx, "chn", "author", "")
	assert.Error(t, err)

	tooLong := make([]byte, 4001)
	for i := range tooLong {
		tooLong[i] = 'a'
	}

	// Too long message
	_, err = svc.CreateMessage(ctx, "chn", "author", string(tooLong))
	assert.Error(t, err)

	// Valid length
	db.On("QueryRow", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(NewMockRow("msg_id", "chn", "author", "Hello World!", time.Now()))
	mc.On("SetJSON", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil)
	mc.On("Publish", mock.Anything, mock.Anything, mock.Anything).Return(nil)
	
	msg, err := svc.CreateMessage(ctx, "chn", "author", "Hello World!")
	assert.NoError(t, err)
	assert.Equal(t, "Hello World!", msg.Content)
}

func TestMessageService_SearchValidation(t *testing.T) {
	mc := NewMockCache()
	svc := services.NewMessageService(nil, mc)
	ctx := context.Background()

	tooLong := make([]byte, 101)
	for i := range tooLong {
		tooLong[i] = 'a'
	}

	_, err := svc.SearchMessages(ctx, string(tooLong), nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "search query too long")
}
