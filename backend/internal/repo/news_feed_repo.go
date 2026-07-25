package repo

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/google/uuid"
)

const collNewsFeedCaches = "news_feed_caches"

// FeedItem represents a cached news/game feed entry.
type FeedItem struct {
	ID        string    `json:"_id"`
	ServerID  string    `json:"server_id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	SourceURL string    `json:"source_url"`
	ImageURL  string    `json:"image_url,omitempty"`
	Category  string    `json:"category,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// NewsFeedRepo defines operations for news feed caching in Astra DB.
type NewsFeedRepo interface {
	SaveFeedItems(ctx context.Context, items []*FeedItem) error
	GetFeed(ctx context.Context, serverID string, limit int) ([]*FeedItem, error)
}

type newsFeedRepo struct {
	astra database.AstraClient
}

// NewNewsFeedRepo creates a new Astra-backed NewsFeedRepo.
func NewNewsFeedRepo(astra database.AstraClient) NewsFeedRepo {
	return &newsFeedRepo{astra: astra}
}

func (r *newsFeedRepo) SaveFeedItems(ctx context.Context, items []*FeedItem) error {
	docs := make([]map[string]any, 0, len(items))
	for _, item := range items {
		if item.ID == "" {
			item.ID = uuid.NewString()
		}
		if item.CreatedAt.IsZero() {
			item.CreatedAt = time.Now().UTC()
		}
		doc, err := toMap(item)
		if err != nil {
			return fmt.Errorf("marshal feed item: %w", err)
		}
		docs = append(docs, doc)
	}

	if err := r.astra.InsertMany(ctx, collNewsFeedCaches, docs); err != nil {
		return fmt.Errorf("insert feed items: %w", err)
	}
	return nil
}

func (r *newsFeedRepo) GetFeed(ctx context.Context, serverID string, limit int) ([]*FeedItem, error) {
	filter := map[string]any{"server_id": serverID}
	if limit <= 0 {
		limit = 20
	}

	opts := &database.FindOptions{
		Limit: limit,
		Sort:  map[string]any{"created_at": -1},
	}

	docs, err := r.astra.Find(ctx, collNewsFeedCaches, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("find feed items: %w", err)
	}

	results := make([]*FeedItem, 0, len(docs))
	for _, doc := range docs {
		item, err := fromMapFeedItem(doc)
		if err != nil {
			return nil, fmt.Errorf("decode feed item: %w", err)
		}
		results = append(results, item)
	}
	return results, nil
}

func fromMapFeedItem(m map[string]any) (*FeedItem, error) {
	b, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	var item FeedItem
	if err := json.Unmarshal(b, &item); err != nil {
		return nil, err
	}
	return &item, nil
}
