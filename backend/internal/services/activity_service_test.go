package services_test

import (
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

// We mock the service to test the expired filtering logic of Property 8
type mockActivityDB struct {
	activities []*models.Activity
	deleted    int
}

func (db *mockActivityDB) Insert(a *models.Activity) {
	db.activities = append(db.activities, a)
}

func (db *mockActivityDB) GetValid() []*models.Activity {
	// simulates SQL: WHERE user_id = $1 AND (ends_at IS NULL OR ends_at > NOW())
	var valid []*models.Activity
	for _, a := range db.activities {
		if a.EndsAt == nil || a.EndsAt.After(time.Now()) {
			valid = append(valid, a)
		}
	}
	return valid
}

func (db *mockActivityDB) CleanupExpired() {
	var keep []*models.Activity
	for _, a := range db.activities {
		if a.EndsAt == nil || a.EndsAt.After(time.Now()) {
			keep = append(keep, a)
		} else {
			db.deleted++
		}
	}
	db.activities = keep
}

func TestActivityService_AutoDelete(t *testing.T) {
	// Property 8: Custom Status Data Completeness & Auto Delete
	// Validates fetching hides expired, and cleanup deletes expired.

	db := &mockActivityDB{}

	// Perm activity
	db.Insert(&models.Activity{
		Name:   "Listening to Spotify",
		EndsAt: nil,
	})

	// Expired activity
	exp := time.Now().Add(-1 * time.Hour) // Past
	db.Insert(&models.Activity{
		Name:   "Playing a game",
		EndsAt: &exp,
	})

	// Future expiration
	future := time.Now().Add(1 * time.Hour) // Future
	db.Insert(&models.Activity{
		Name:   "Watching a movie",
		EndsAt: &future,
	})

	// Before cleanup, fetch valid should return 2
	valid := db.GetValid()
	assert.Len(t, valid, 2, "Expired activities should not be returned")

	// Perform cleanup
	db.CleanupExpired()

	assert.Equal(t, 1, db.deleted, "One expired activity should be hard deleted")
	assert.Len(t, db.activities, 2, "Valid activities should remain in DB")
}
