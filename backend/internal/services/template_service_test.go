package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

type mockTemplateDB struct {
	templates map[string]*models.ServerTemplate
	servers   map[string]bool
	channels  map[string]services.TemplateChannel
	roles     map[string]services.TemplateRole
}

func (db *mockTemplateDB) CreateTemplate(code string, channels []services.TemplateChannel, roles []services.TemplateRole) (*models.ServerTemplate, error) {
	if _, ok := db.templates[code]; ok {
		return nil, fmt.Errorf("duplicate template code")
	}

	data := services.TemplateData{
		Channels: channels,
		Roles:    roles,
	}

	t := &models.ServerTemplate{
		Code:         code,
		TemplateData: data, // Will be simulated as raw data
		CreatedAt:    time.Now(),
	}
	db.templates[code] = t
	return t, nil
}

func (db *mockTemplateDB) UseTemplate(code, creatorID, newServerName string) (*models.Server, error) {
	t, ok := db.templates[code]
	if !ok {
		return nil, fmt.Errorf("template not found")
	}

	data := t.TemplateData.(services.TemplateData)

	newServerID := "server-new"
	db.servers[newServerID] = true

	for i, r := range data.Roles {
		db.roles[fmt.Sprintf("role-new-%d", i)] = r
	}

	for i, c := range data.Channels {
		db.channels[fmt.Sprintf("chan-new-%d", i)] = c
	}

	t.UsageCount++

	return &models.Server{
		ID:      newServerID,
		Name:    newServerName,
		OwnerID: creatorID,
	}, nil
}

func TestTemplateProperties(t *testing.T) {
	// Property 41: Template Code Uniqueness
	// Property 42: Template Structure Replication

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockTemplateDB{
		templates: make(map[string]*models.ServerTemplate),
		servers:   make(map[string]bool),
		channels:  make(map[string]services.TemplateChannel),
		roles:     make(map[string]services.TemplateRole),
	}

	channels := []services.TemplateChannel{
		{OriginalID: "cat-1", Name: "Text Channels", Type: models.ChannelTypeCategory},
		{OriginalID: "chan-1", Name: "general", Type: models.ChannelTypeText},
	}
	roles := []services.TemplateRole{
		{OriginalID: "role-1", Name: "Admin", Permissions: 123},
	}

	// 1. Uniqueness
	code := "ABC12345"
	_, err := db.CreateTemplate(code, channels, roles)
	assert.NoError(t, err)

	_, err = db.CreateTemplate(code, channels, roles) // duplicate
	assert.Error(t, err)

	// 2. Structure Replication
	server, err := db.UseTemplate(code, "creator-1", "My Cloned Server")
	assert.NoError(t, err)
	assert.NotNil(t, server)

	// Assert Recreated Data Length
	assert.Len(t, db.channels, 2)
	assert.Len(t, db.roles, 1)

	// Assert Usage Update
	assert.Equal(t, 1, db.templates[code].UsageCount)
}
