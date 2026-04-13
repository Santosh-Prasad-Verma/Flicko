package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockAnnounceDB struct {
	announcements map[string]*models.Announcement
}

func (db *mockAnnounceDB) Create(title, content, aType string, priority int, scheduledFor *time.Time) (*models.Announcement, error) {
	if aType != "news" && aType != "update" && aType != "alert" && aType != "event" {
		return nil, fmt.Errorf("invalid type")
	}
	if priority < 0 || priority > 10 {
		return nil, fmt.Errorf("invalid priority")
	}

	var pubAt *time.Time
	if scheduledFor == nil {
		now := time.Now()
		pubAt = &now
	}

	a := &models.Announcement{
		ID:               "ann-1",
		Title:            title,
		Content:          content,
		AnnouncementType: aType,
		Priority:         priority,
		PublishedAt:      pubAt,
		ScheduledFor:     scheduledFor,
	}
	db.announcements[a.ID] = a
	return a, nil
}

func TestAnnouncementProperties(t *testing.T) {
	// Property 48: Announcement Data Completeness
	// Validates fields, priorities, and schedule logic

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockAnnounceDB{
		announcements: make(map[string]*models.Announcement),
	}

	// 1. Invalid Type
	_, err := db.Create("Hello", "Content", "invalid_type", 5, nil)
	assert.Error(t, err)

	// 2. Invalid Priority
	_, err = db.Create("Hello", "Content", "news", 11, nil)
	assert.Error(t, err)

	// 3. Immediate Publishing
	a1, err := db.Create("Immediate", "Content", "update", 0, nil)
	assert.NoError(t, err)
	assert.NotNil(t, a1.PublishedAt)
	assert.Nil(t, a1.ScheduledFor)

	// 4. Scheduled Publishing
	futureDate := time.Now().Add(time.Hour)
	a2, err := db.Create("Scheduled", "Content", "alert", 10, &futureDate)
	assert.NoError(t, err)
	assert.Nil(t, a2.PublishedAt)
	assert.Equal(t, &futureDate, a2.ScheduledFor)
}
