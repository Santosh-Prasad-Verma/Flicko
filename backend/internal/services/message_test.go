package services_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestMessageService_CreateMessage(t *testing.T) {
	mc := &mockCache{store: make(map[string]string)}
	svc := services.NewMessageService(nil, mc)
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
	msg, err := svc.CreateMessage(ctx, "chn", "author", "Hello World!")
	assert.NoError(t, err)
	assert.Equal(t, "Hello World!", msg.Content)
}

func TestMessageService_SearchValidation(t *testing.T) {
	mc := &mockCache{store: make(map[string]string)}
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
