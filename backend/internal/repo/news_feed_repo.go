package repo

import (
	"context"
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
		docs = append(docs, feedItemToMap(item))
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

func feedItemToMap(item *FeedItem) map[string]any {
	doc := map[string]any{
		"_id":        item.ID,
		"server_id":  item.ServerID,
		"title":      item.Title,
		"content":    item.Content,
		"source_url": item.SourceURL,
		"created_at": item.CreatedAt,
	}
	if item.ImageURL != "" {
		doc["image_url"] = item.ImageURL
	}
	if item.Category != "" {
		doc["category"] = item.Category
	}
	return doc
}

func fromMapFeedItem(m map[string]any) (*FeedItem, error) {
	if m == nil {
		return nil, fmt.Errorf("nil feed item map")
	}
	item := &FeedItem{}
	if id, ok := m["_id"].(string); ok {
		item.ID = id
	} else if id, ok := m["id"].(string); ok {
		item.ID = id
	}
	if serverID, ok := m["server_id"].(string); ok {
		item.ServerID = serverID
	}
	if title, ok := m["title"].(string); ok {
		item.Title = title
	}
	if content, ok := m["content"].(string); ok {
		item.Content = content
	}
	if sourceURL, ok := m["source_url"].(string); ok {
		item.SourceURL = sourceURL
	}
	if imageURL, ok := m["image_url"].(string); ok {
		item.ImageURL = imageURL
	}
	if category, ok := m["category"].(string); ok {
		item.Category = category
	}
	if rawCreatedAt, ok := m["created_at"]; ok {
		switch t := rawCreatedAt.(type) {
		case time.Time:
			item.CreatedAt = t
		case string:
			if parsed, err := time.Parse(time.RFC3339, t); err == nil {
				item.CreatedAt = parsed
			}
		}
	}
	return item, nil
}
