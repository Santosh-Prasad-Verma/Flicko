package services_test

import (
	"context"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestChannelService_CreateChannel(t *testing.T) {
	mc := &mockCache{store: make(map[string]string)}
	svc := services.NewChannelService(nil, mc)

	ctx := context.Background()

	// Invalid Name length
	_, err := svc.CreateChannel(ctx, "server-id", "", models.ChannelTypeText, nil)
	assert.Error(t, err)

	// Valid length
	channel, err := svc.CreateChannel(ctx, "server-id", "general", models.ChannelTypeText, nil)
	assert.NoError(t, err)
	assert.Equal(t, "general", channel.Name)
}
