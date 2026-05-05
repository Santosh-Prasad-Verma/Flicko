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
		return nil, fmt.Errorf("message content must be between 1 and 4000 characters")
	}

	query := `
		INSERT INTO public.messages (channel_id, author_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, channel_id, author_id, content, type, flags, pinned, 
				  mention_everyone, tts, nonce, webhook_id, application_id, 
				  created_at, updated_at, deleted_at
	`

	var msg models.Message
	row := s.db.QueryRow(ctx, query, channelID, authorID, content)
	err := row.Scan(
		&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content, &msg.Type, &msg.Flags,
		&msg.Pinned, &msg.MentionEveryone, &msg.TTS, &msg.Nonce, &msg.WebhookID,
		&msg.ApplicationID, &msg.CreatedAt, &msg.UpdatedAt, &msg.DeletedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating message: %w", err)
	}

	// Cache and Publish
	cacheKey := fmt.Sprintf("message:%s", msg.ID)
	s.cache.SetJSON(ctx, cacheKey, &msg, 1*time.Hour)
	s.cache.Publish(ctx, fmt.Sprintf("channel:%s:messages", channelID), &msg)

	return &msg, nil
}

func (s *messageService) GetMessages(ctx context.Context, channelID string, cursor string, limit int) ([]*models.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	sqlQuery := `
		SELECT id, channel_id, author_id, content, type, flags, pinned, 
			   mention_everyone, tts, nonce, webhook_id, application_id, 
			   created_at, updated_at, deleted_at
		FROM public.messages
		WHERE channel_id = $1 AND deleted_at IS NULL
	`
	args := []interface{}{channelID, limit}

	if cursor != "" {
		sqlQuery += " AND created_at < (SELECT created_at FROM public.messages WHERE id = $3)"
		args = append(args, cursor)
	}

	sqlQuery += " ORDER BY created_at DESC LIMIT $2"

	rows, err := s.db.Query(ctx, sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("error fetching messages: %w", err)
	}
	defer rows.Close()

	messages := []*models.Message{}
	for rows.Next() {
		var msg models.Message
		err := rows.Scan(
			&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content, &msg.Type, &msg.Flags,
			&msg.Pinned, &msg.MentionEveryone, &msg.TTS, &msg.Nonce, &msg.WebhookID,
			&msg.ApplicationID, &msg.CreatedAt, &msg.UpdatedAt, &msg.DeletedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning message: %w", err)
		}
		messages = append(messages, &msg)
	}

	return messages, nil
}

func (s *messageService) UpdateMessage(ctx context.Context, messageID, authorID, newContent string) (*models.Message, error) {
	query := `
		UPDATE public.messages
		SET content = $1, updated_at = NOW()
		WHERE id = $2 AND author_id = $3
		RETURNING id, channel_id, author_id, content, type, flags, pinned, 
				  mention_everyone, tts, nonce, webhook_id, application_id, 
				  created_at, updated_at, deleted_at
	`

	var msg models.Message
	row := s.db.QueryRow(ctx, query, newContent, messageID, authorID)
	err := row.Scan(
		&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content, &msg.Type, &msg.Flags,
		&msg.Pinned, &msg.MentionEveryone, &msg.TTS, &msg.Nonce, &msg.WebhookID,
		&msg.ApplicationID, &msg.CreatedAt, &msg.UpdatedAt, &msg.DeletedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error updating message: %w", err)
	}

	s.cache.Delete(ctx, fmt.Sprintf("message:%s", messageID))
	s.cache.Publish(ctx, fmt.Sprintf("channel:%s:messages", msg.ChannelID), &msg)

	return &msg, nil
}

func (s *messageService) DeleteMessage(ctx context.Context, messageID, authorID string) error {
	query := `UPDATE public.messages SET deleted_at = NOW() WHERE id = $1 AND author_id = $2`
	_, err := s.db.Exec(ctx, query, messageID, authorID)
	if err != nil {
		return fmt.Errorf("error deleting message: %w", err)
	}

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
