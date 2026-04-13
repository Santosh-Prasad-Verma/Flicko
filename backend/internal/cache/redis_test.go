package cache_test

import (
	"testing"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/stretchr/testify/assert"
)

type TestStruct struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func TestRedisCache_MissingURL(t *testing.T) {
	_, err := cache.NewRedisCache("invalid-url")
	assert.Error(t, err)
}

// Below tests would require a live Redis connection to fully mock
// In a CI environment we will skip or use mini-redis

func TestJSONHelpers(t *testing.T) {
	// Dummy test to ensure types compile correctly in scope
	var dest TestStruct
	dest.ID = 1
	dest.Name = "Test"

	assert.Equal(t, 1, dest.ID)
	assert.Equal(t, "Test", dest.Name)
}
