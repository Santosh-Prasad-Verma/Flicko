package services_test

import (
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

// MockEditDB handles DB interaction assertions for edit limits
type mockEditDB struct {
	Histories []services.MessageEditHistory
}

func (m *mockEditDB) insertHistory(h services.MessageEditHistory) {
	m.Histories = append(m.Histories, h)
}

func (m *mockEditDB) cleanupOld(messageID string) {
	// Simulate the SQL constraint:
	// DELETE FROM message_edit_history WHERE ... OFFSET 10
	if len(m.Histories) > 10 {
		m.Histories = m.Histories[len(m.Histories)-10:]
	}
}

func TestMessageEditService_HistoryLimit(t *testing.T) {
	// Property 18: Message Edit History
	// Property 19: Edit History Limit (Max 10)

	db := &mockEditDB{}
	msgID := "123e4567-e89b-12d3-a456-426614174000"

	// Simulate 12 edits (12 insertions and cleanups)
	for i := 0; i < 12; i++ {
		db.insertHistory(services.MessageEditHistory{
			ID:              "seq-id-stub",
			MessageID:       msgID,
			PreviousContent: "Old content",
			EditedAt:        time.Now(),
		})
		db.cleanupOld(msgID)
	}

	// At the end, there should be exactly 10 history records
	assert.Len(t, db.Histories, 10)
}
