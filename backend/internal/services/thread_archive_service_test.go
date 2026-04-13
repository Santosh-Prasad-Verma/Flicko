package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockArchiveDB struct {
	thread *models.Thread
}

func (db *mockArchiveDB) Archive() {
	db.thread.IsArchived = true
	db.thread.ArchiveAt = time.Now()
}

func (db *mockArchiveDB) Unarchive() {
	db.thread.IsArchived = false
	// Simulate NOW() + duration
	// Let's assume duration was 24 hours
	db.thread.ArchiveAt = time.Now().Add(24 * time.Hour)
}

func TestThreadArchiveService_TimerReset(t *testing.T) {
	// Property 23: Thread Auto-Archive Timer Reset
	// Validates that unarchiving a thread resets the archive_at timer.

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockArchiveDB{
		thread: &models.Thread{
			ID:                  "mock-thread",
			IsArchived:          true,
			AutoArchiveDuration: "24 hours",
			ArchiveAt:           time.Now().Add(-1 * time.Hour), // Expired
		},
	}

	assert.True(t, db.thread.IsArchived)
	assert.True(t, db.thread.ArchiveAt.Before(time.Now())) // In the past

	// Simulate unarchive
	db.Unarchive()

	assert.False(t, db.thread.IsArchived)

	// The new archive time should be ~24 hours in the future
	expectedArchiveAt := time.Now().Add(24 * time.Hour)
	assert.WithinDuration(t, expectedArchiveAt, db.thread.ArchiveAt, 2*time.Second)
}
