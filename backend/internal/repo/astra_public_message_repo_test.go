package repo_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
)

func TestAstraPublicMessageRepo(t *testing.T) {
	endpoint := os.Getenv("ASTRA_DB_API_ENDPOINT")
	if endpoint == "" {
		endpoint = os.Getenv("ASTRA_DB_ENDPOINT")
	}
	token := os.Getenv("ASTRA_DB_APPLICATION_TOKEN")

	if endpoint == "" || token == "" {
		t.Skip("Skipping Astra DB integration test: ASTRA_DB_API_ENDPOINT or ASTRA_DB_APPLICATION_TOKEN not set")
	}

	logger, _ := zap.NewDevelopment()
	client := database.NewAstraClient(endpoint, token, logger)
	defer client.Close()

	publicMsgRepo := repo.NewAstraPublicMessageRepo(client)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	channelID := "test_channel_public_123"
	testMsg := &models.AstraPublicMessage{
		ID:           "test_msg_001",
		ChannelID:    channelID,
		AuthorID:     "user_456",
		AuthorName:   "Tarun Verma",
		AuthorAvatar: "https://avatar.url/tarun.png",
		Content:      "Hello Flicko Astra DB Public Chat!",
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}

	// 1. Insert
	err := publicMsgRepo.InsertPublicMessage(ctx, testMsg)
	require.NoError(t, err)

	// 2. Fetch
	messages, err := publicMsgRepo.GetChannelMessages(ctx, channelID, 10)
	require.NoError(t, err)
	assert.NotEmpty(t, messages)

	found := false
	for _, m := range messages {
		if m.Content == testMsg.Content {
			found = true
			assert.Equal(t, testMsg.AuthorName, m.AuthorName)
			break
		}
	}
	assert.True(t, found, "Inserted public message should be retrieved")

	// 3. Delete
	err = publicMsgRepo.DeletePublicMessage(ctx, testMsg.ID)
	assert.NoError(t, err)
}
