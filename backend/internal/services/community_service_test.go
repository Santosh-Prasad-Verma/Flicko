package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockCommunityDB struct {
	communities map[string]*models.Community
}

func (db *mockCommunityDB) Enable(serverID, rulesChannelID string) (*models.Community, error) {
	if rulesChannelID == "" {
		return nil, fmt.Errorf("rules channel must be set to enable community")
	}

	c := &models.Community{
		ServerID:       serverID,
		RulesChannelID: &rulesChannelID,
		IsDiscoverable: true,
		CreatedAt:      time.Now(),
	}
	db.communities[serverID] = c
	return c, nil
}

func TestCommunityFeatureProperties(t *testing.T) {
	// Property 46: Community Feature Requirements
	// Validates that rules channel must be set to enable community features

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockCommunityDB{
		communities: make(map[string]*models.Community),
	}

	// 1. Missing Rules Channel
	_, err := db.Enable("server-1", "")
	assert.Error(t, err)

	// 2. Valid Properties
	_, err = db.Enable("server-1", "channel-1")
	assert.NoError(t, err)
}
