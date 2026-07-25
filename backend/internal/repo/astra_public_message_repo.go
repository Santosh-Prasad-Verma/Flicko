package repo

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type AstraPublicMessageRepo interface {
	InsertPublicMessage(ctx context.Context, msg *models.AstraPublicMessage) error
	GetChannelMessages(ctx context.Context, channelID string, limit int) ([]*models.AstraPublicMessage, error)
	SearchPublicMessagesVector(ctx context.Context, vector []float32, limit int) ([]*models.AstraPublicMessage, error)
	DeletePublicMessage(ctx context.Context, messageID string) error
}

type astraPublicMessageRepo struct {
	client     database.AstraClient
	collection string
}

func NewAstraPublicMessageRepo(client database.AstraClient) AstraPublicMessageRepo {
	return &astraPublicMessageRepo{
		client:     client,
		collection: "public_messages",
	}
}

func (r *astraPublicMessageRepo) InsertPublicMessage(ctx context.Context, msg *models.AstraPublicMessage) error {
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now().UTC()
	}
	if msg.UpdatedAt.IsZero() {
		msg.UpdatedAt = time.Now().UTC()
	}

	doc := map[string]any{
		"channel_id":    msg.ChannelID,
		"author_id":     msg.AuthorID,
		"author_name":   msg.AuthorName,
		"author_avatar": msg.AuthorAvatar,
		"content":       msg.Content,
		"created_at":    msg.CreatedAt.Format(time.RFC3339),
		"updated_at":    msg.UpdatedAt.Format(time.RFC3339),
	}

	if len(msg.Vector) > 0 {
		doc["$vector"] = msg.Vector
	}

	if msg.ID != "" {
		doc["_id"] = msg.ID
	}

	err := r.client.InsertOne(ctx, r.collection, doc)
	if err != nil {
		return fmt.Errorf("astra public message insert error: %w", err)
	}

	return nil
}

func (r *astraPublicMessageRepo) GetChannelMessages(ctx context.Context, channelID string, limit int) ([]*models.AstraPublicMessage, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	filter := map[string]any{
		"channel_id": channelID,
	}

	opts := &database.FindOptions{
		Limit: limit,
		Sort: map[string]any{
			"created_at": -1,
		},
	}

	docs, err := r.client.Find(ctx, r.collection, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("astra fetch channel messages error: %w", err)
	}

	return parseAstraPublicMessages(docs)
}

func (r *astraPublicMessageRepo) SearchPublicMessagesVector(ctx context.Context, vector []float32, limit int) ([]*models.AstraPublicMessage, error) {
	if limit <= 0 {
		limit = 10
	}

	docs, err := r.client.VectorSearch(ctx, r.collection, vector, limit, nil)
	if err != nil {
		return nil, fmt.Errorf("astra vector search messages error: %w", err)
	}

	return parseAstraPublicMessages(docs)
}

func (r *astraPublicMessageRepo) DeletePublicMessage(ctx context.Context, messageID string) error {
	filter := map[string]any{
		"_id": messageID,
	}

	err := r.client.DeleteOne(ctx, r.collection, filter)
	if err != nil {
		return fmt.Errorf("astra delete public message error: %w", err)
	}

	return nil
}

func parseAstraPublicMessages(docs []map[string]any) ([]*models.AstraPublicMessage, error) {
	messages := make([]*models.AstraPublicMessage, 0, len(docs))
	for _, docMap := range docs {
		msg := &models.AstraPublicMessage{}
		if id, ok := docMap["_id"].(string); ok {
			msg.ID = id
		}
		if channelID, ok := docMap["channel_id"].(string); ok {
			msg.ChannelID = channelID
		}
		if authorID, ok := docMap["author_id"].(string); ok {
			msg.AuthorID = authorID
		}
		if authorName, ok := docMap["author_name"].(string); ok {
			msg.AuthorName = authorName
		}
		if authorAvatar, ok := docMap["author_avatar"].(string); ok {
			msg.AuthorAvatar = authorAvatar
		}
		if content, ok := docMap["content"].(string); ok {
			msg.Content = content
		}
		if createdAtStr, ok := docMap["created_at"].(string); ok {
			if t, err := time.Parse(time.RFC3339, createdAtStr); err == nil {
				msg.CreatedAt = t
			}
		}

		messages = append(messages, msg)
	}

	return messages, nil
}
