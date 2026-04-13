package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type ChannelService interface {
	CreateChannel(ctx context.Context, serverID, name string, channelType models.ChannelType, parentID *string) (*models.Channel, error)
	GetChannel(ctx context.Context, channelID string) (*models.Channel, error)
	UpdateChannel(ctx context.Context, channelID string, updates map[string]interface{}) (*models.Channel, error)
	DeleteChannel(ctx context.Context, channelID string) error

	GetServerChannels(ctx context.Context, serverID string) ([]*models.Channel, error)
	CheckAccess(ctx context.Context, userID, channelID string) (bool, error)
}

type channelService struct {
	db    database.DatabaseClient
	cache cache.CacheLayer
}

func NewChannelService(db database.DatabaseClient, cache cache.CacheLayer) ChannelService {
	return &channelService{
		db:    db,
		cache: cache,
	}
}

func (s *channelService) CreateChannel(ctx context.Context, serverID, name string, channelType models.ChannelType, parentID *string) (*models.Channel, error) {
	if len(name) < 1 || len(name) > 100 {
		return nil, errors.New("channel name must be between 1 and 100 characters")
	}

	// Example enforcing max channels limit (500)
	// count, err := s.db.Query(...)
	// if count >= 500 { return error }

	channel := &models.Channel{
		ID:        "generate-uuid",
		ServerID:  serverID,
		Type:      channelType,
		Name:      name,
		ParentID:  parentID,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	cacheKey := fmt.Sprintf("channel:%s", channel.ID)
	s.cache.SetJSON(ctx, cacheKey, channel, 10*time.Minute)

	return channel, nil
}

func (s *channelService) GetChannel(ctx context.Context, channelID string) (*models.Channel, error) {
	cacheKey := fmt.Sprintf("channel:%s", channelID)
	var channel models.Channel
	err := s.cache.GetJSON(ctx, cacheKey, &channel)
	if err == nil {
		return &channel, nil
	}

	if s.db == nil {
		return &models.Channel{ID: channelID, Name: "mock-channel"}, nil
	}

	return nil, errors.New("channel not found")
}

func (s *channelService) UpdateChannel(ctx context.Context, channelID string, updates map[string]interface{}) (*models.Channel, error) {
	cacheKey := fmt.Sprintf("channel:%s", channelID)
	s.cache.Delete(ctx, cacheKey)

	return &models.Channel{ID: channelID, Name: "updated-mock-channel"}, nil
}

func (s *channelService) DeleteChannel(ctx context.Context, channelID string) error {
	cacheKey := fmt.Sprintf("channel:%s", channelID)
	s.cache.Delete(ctx, cacheKey)
	return nil
}

func (s *channelService) GetServerChannels(ctx context.Context, serverID string) ([]*models.Channel, error) {
	return []*models.Channel{}, nil
}

func (s *channelService) CheckAccess(ctx context.Context, userID, channelID string) (bool, error) {
	// Simple stub allowing access
	return true, nil
}
