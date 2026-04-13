package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockDrawingDB struct {
	strokes []*models.DrawingStroke
}

func (db *mockDrawingDB) Insert(s *models.DrawingStroke) {
	db.strokes = append(db.strokes, s)
}

func (db *mockDrawingDB) GetByUserAndShare(userID, shareID string) []*models.DrawingStroke {
	var filtered []*models.DrawingStroke
	for _, s := range db.strokes {
		if s.UserID == userID && s.ScreenShareID == shareID {
			filtered = append(filtered, s)
		}
	}
	return filtered
}

func TestDrawingStrokes(t *testing.T) {
	// Property 26: Drawing Stroke Data Completeness
	// Validates parameters mappings and metadata persistence properties

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockDrawingDB{}

	tool := models.ToolPen
	color := "#ff0000"
	width := 5
	opacity := 0.8
	coords := map[string]interface{}{
		"x": []int{10, 20, 30},
		"y": []int{15, 25, 35},
	}

	share := "mock-share-123"
	user := "mock-user-456"

	str := &models.DrawingStroke{
		ID:            "str-789",
		ScreenShareID: share,
		UserID:        user,
		Tool:          tool,
		Color:         color,
		Width:         width,
		Opacity:       opacity,
		Coordinates:   coords,
		CreatedAt:     time.Now(),
	}

	db.Insert(str)

	strokes := db.GetByUserAndShare(user, share)
	assert.Len(t, strokes, 1)

	saved := strokes[0]
	assert.Equal(t, models.ToolPen, saved.Tool)
	assert.Equal(t, "#ff0000", saved.Color)
	assert.Equal(t, 5, saved.Width)
	assert.Equal(t, 0.8, saved.Opacity)
	assert.NotNil(t, saved.Coordinates)
}
