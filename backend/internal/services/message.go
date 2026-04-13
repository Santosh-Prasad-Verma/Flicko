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

type MessageService interface {
	CreateMessage(ctx context.Context, channelID, authorID, content string) (*models.Message, error)
	GetMessages(ctx context.Context, channelID string, cursor string, limit int) ([]*models.Message, error)
	UpdateMessage(ctx context.Context, messageID, authorID, newContent string) (*models.Message, error)
	DeleteMessage(ctx context.Context, messageID, authorID string) error

	AddReaction(ctx context.Context, messageID, userID, emoji string) error
	RemoveReaction(ctx context.Context, messageID, userID, emoji string) error

	SearchMessages(ctx context.Context, query string, filters map[string]interface{}) ([]*models.Message, error)
}

type messageService struct {
	db    database.DatabaseClient
	cache cache.CacheLayer
}

func NewMessageService(db database.DatabaseClient, cache cache.CacheLayer) MessageService {
	return &messageService{
		db:    db,
		cache: cache,
	}
}

func (s *messageService) CreateMessage(ctx context.Context, channelID, authorID, content string) (*models.Message, error) {
	if len(content) == 0 || len(content) > 4000 {
		return nil, errors.New("message content must be between 1 and 4000 characters")
	}

	msg := &models.Message{
		ID:        "generate-msg-uuid",
		ChannelID: channelID,
		AuthorID:  authorID,
		Content:   content,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Cache last 50 messages logic would use Redis Lists (LPUSH + LTRIM)
	// For MVP interface matching standard set:
	cacheKey := fmt.Sprintf("message:%s", msg.ID)
	s.cache.SetJSON(ctx, cacheKey, msg, 5*time.Minute)

	// In real use, PubSub broadcast is triggered here
	s.cache.Publish(ctx, fmt.Sprintf("channel:%s:messages", channelID), msg)

	return msg, nil
}

func (s *messageService) GetMessages(ctx context.Context, channelID string, cursor string, limit int) ([]*models.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	// Attempt to pull from Redis cache list here
	return []*models.Message{}, nil
}

func (s *messageService) UpdateMessage(ctx context.Context, messageID, authorID, newContent string) (*models.Message, error) {
	return &models.Message{ID: messageID, Content: newContent}, nil
}

func (s *messageService) DeleteMessage(ctx context.Context, messageID, authorID string) error {
	s.cache.Delete(ctx, fmt.Sprintf("message:%s", messageID))
	return nil
}

func (s *messageService) AddReaction(ctx context.Context, messageID, userID, emoji string) error {
	// Persist to DB -> broadcast event
	return nil
}

func (s *messageService) RemoveReaction(ctx context.Context, messageID, userID, emoji string) error {
	return nil
}

func (s *messageService) SearchMessages(ctx context.Context, query string, filters map[string]interface{}) ([]*models.Message, error) {
	if len(query) > 100 {
		return nil, errors.New("search query too long")
	}
	return []*models.Message{}, nil
}
