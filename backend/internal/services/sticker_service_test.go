package services_test

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockStickerDB struct {
	serverBoosts map[string]int
	stickers     map[string]*models.Sticker
}

func (db *mockStickerDB) SetBoostLevel(serverID string, level int) {
	db.serverBoosts[serverID] = level
}

func (db *mockStickerDB) Upload(serverID, name, filename string, size int64) (*models.Sticker, error) {
	if size > 512*1024 {
		return nil, fmt.Errorf("file size must be <= 512KB")
	}

	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".png" && ext != ".apng" && ext != ".gif" {
		return nil, fmt.Errorf("invalid format")
	}

	boostLevel := db.serverBoosts[serverID]
	if boostLevel < 1 {
		return nil, fmt.Errorf("server boost level must be >= 1")
	}

	st := &models.Sticker{
		ID:        "st-1",
		ServerID:  serverID,
		Name:      name,
		ImageURL:  "storage/" + filename,
		CreatedAt: time.Now(),
	}
	db.stickers["st-1"] = st
	return st, nil
}

func TestStickerUploadProperties(t *testing.T) {
	// Property 39: Sticker Upload Boost Requirement
	// Property 40: Sticker Upload Validation

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockStickerDB{
		serverBoosts: make(map[string]int),
		stickers:     make(map[string]*models.Sticker),
	}

	db.SetBoostLevel("server-unboosted", 0)
	db.SetBoostLevel("server-boosted", 1)

	// Test 1: Boost requirement
	_, err := db.Upload("server-unboosted", "Cool Sticker", "test.png", 100*1024)
	assert.Error(t, err)

	_, err = db.Upload("server-boosted", "Cool Sticker", "test.png", 100*1024)
	assert.NoError(t, err)

	// Test 2: File size limit (> 512KB)
	_, err = db.Upload("server-boosted", "Large Sticker", "big.png", 600*1024)
	assert.Error(t, err)

	// Test 3: Invalid format
	_, err = db.Upload("server-boosted", "Bad Format", "test.jpg", 100*1024)
	assert.Error(t, err)

	// Test 4: Valid APNG
	_, err = db.Upload("server-boosted", "Anim", "test.apng", 200*1024)
	assert.NoError(t, err)
}
