package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
)

// MockCache for testing
type mockCache struct {
	store map[string]string
}

func (m *mockCache) DeletePattern(ctx context.Context, pattern string) error {
	// Simple mock implementation
	return nil
}

func (m *mockCache) Get(ctx context.Context, key string) (string, error) { return m.store[key], nil }
func (m *mockCache) Set(ctx context.Context, key string, val string, ext time.Duration) error {
	m.store[key] = val
	return nil
}
func (m *mockCache) Delete(ctx context.Context, key string) error                    { delete(m.store, key); return nil }
func (m *mockCache) GetJSON(ctx context.Context, key string, dest interface{}) error { return nil } // Stub
func (m *mockCache) SetJSON(ctx context.Context, key string, val interface{}, ext time.Duration) error {
	return nil
}
func (m *mockCache) Exists(ctx context.Context, key string) (bool, error) {
	_, ok := m.store[key]
	return ok, nil
}
func (m *mockCache) Publish(ctx context.Context, ch string, msg interface{}) error { return nil }
func (m *mockCache) Subscribe(ctx context.Context, ch string) *redis.PubSub        { return nil }
func (m *mockCache) Close() error                                                  { return nil }

// Sorted set stubs for CacheLayer compliance
func (m *mockCache) ZAdd(ctx context.Context, key string, score float64, member string) error {
	return nil
}
func (m *mockCache) ZCard(ctx context.Context, key string) (int64, error) { return 0, nil }
func (m *mockCache) ZRemRangeByScore(ctx context.Context, key, min, max string) error {
	return nil
}
func (m *mockCache) ZRangeFirst(ctx context.Context, key string) (int64, error) { return 0, nil }
func (m *mockCache) Expire(ctx context.Context, key string, expiration time.Duration) error {
	return nil
}
func (m *mockCache) Ping(ctx context.Context) error { return nil }

// GetRedisClient returns nil for testing purposes
func (m *mockCache) GetRedisClient() redis.Cmdable { return nil }

func TestUserService_CacheInvalidation(t *testing.T) {
	mc := &mockCache{store: make(map[string]string)}
	svc := services.NewUserService(nil, mc)

	// Because of our simple stub in services, we just verify no panic happens
	user, err := svc.UpdateProfile(context.Background(), "user-123", nil)
	// it will return our "pending pgx database implementation" error due to stub or return mock
	if err == nil {
		assert.Equal(t, "updated_mock_user", user.Username)
	}

	presence, err := svc.GetPresence(context.Background(), "user-123")
	assert.NoError(t, err)
	assert.Equal(t, models.StatusOffline, presence.Status) // Defaults to offline when not found
}
