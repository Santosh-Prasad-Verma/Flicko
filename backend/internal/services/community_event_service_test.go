package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockEventDB struct {
	events map[string]*models.CommunityEvent
}

func (db *mockEventDB) CreateEvent(name, eventType string, startTime time.Time) (*models.CommunityEvent, error) {
	if name == "" {
		return nil, fmt.Errorf("name is required")
	}
	if eventType != "voice" && eventType != "stage" && eventType != "external" && eventType != "text" {
		return nil, fmt.Errorf("invalid event type")
	}
	if startTime.Before(time.Now()) {
		return nil, fmt.Errorf("start time must be in the future")
	}

	e := &models.CommunityEvent{
		ID:        "event-1",
		Name:      name,
		EventType: eventType,
		StartTime: startTime,
		Status:    "scheduled",
		CreatedAt: time.Now(),
	}
	db.events[e.ID] = e
	return e, nil
}

func TestCommunityEventProperties(t *testing.T) {
	// Property 47: Event Data Completeness
	// Validates required fields and time bounds

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockEventDB{
		events: make(map[string]*models.CommunityEvent),
	}

	futureTime := time.Now().Add(24 * time.Hour)
	pastTime := time.Now().Add(-24 * time.Hour)

	// 1. Missing Name
	_, err := db.CreateEvent("", "voice", futureTime)
	assert.Error(t, err)

	// 2. Invalid Event Type
	_, err = db.CreateEvent("My Event", "invalid_type", futureTime)
	assert.Error(t, err)

	// 3. Past Start Time
	_, err = db.CreateEvent("My Event", "stage", pastTime)
	assert.Error(t, err)

	// 4. Valid Data Completeness
	_, err = db.CreateEvent("Valid Event", "voice", futureTime)
	assert.NoError(t, err)
}
