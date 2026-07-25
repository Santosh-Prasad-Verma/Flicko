package repo

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
)

const collLinkPreviews = "link_previews"

// LinkPreview represents cached OpenGraph / meta tag data for a URL.
type LinkPreview struct {
	ID          string    `json:"_id"`
	URL         string    `json:"url"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	ImageURL    string    `json:"image_url,omitempty"`
	SiteName    string    `json:"site_name,omitempty"`
	FaviconURL  string    `json:"favicon_url,omitempty"`
	FetchedAt   time.Time `json:"fetched_at"`
}

// LinkPreviewRepo defines operations for link preview caching in Astra DB.
type LinkPreviewRepo interface {
	GetPreview(ctx context.Context, url string) (*LinkPreview, error)
	SavePreview(ctx context.Context, preview *LinkPreview) error
}

type linkPreviewRepo struct {
	astra database.AstraClient
}

// NewLinkPreviewRepo creates a new Astra-backed LinkPreviewRepo.
func NewLinkPreviewRepo(astra database.AstraClient) LinkPreviewRepo {
	return &linkPreviewRepo{astra: astra}
}

func (r *linkPreviewRepo) GetPreview(ctx context.Context, url string) (*LinkPreview, error) {
	id := hashURL(url)
	filter := map[string]any{"_id": id}

	doc, err := r.astra.FindOne(ctx, collLinkPreviews, filter)
	if err != nil {
		return nil, fmt.Errorf("find link preview: %w", err)
	}
	if doc == nil {
		return nil, ErrNotFound
	}

	preview, err := fromMapLinkPreview(doc)
	if err != nil {
		return nil, fmt.Errorf("decode link preview: %w", err)
	}
	return preview, nil
}

func (r *linkPreviewRepo) SavePreview(ctx context.Context, preview *LinkPreview) error {
	preview.ID = hashURL(preview.URL)
	if preview.FetchedAt.IsZero() {
		preview.FetchedAt = time.Now().UTC()
	}

	doc, err := toMap(preview)
	if err != nil {
		return fmt.Errorf("marshal link preview: %w", err)
	}

	if err := r.astra.InsertOne(ctx, collLinkPreviews, doc); err != nil {
		return fmt.Errorf("insert link preview: %w", err)
	}
	return nil
}

func hashURL(url string) string {
	h := sha256.Sum256([]byte(url))
	return hex.EncodeToString(h[:])
}

func fromMapLinkPreview(m map[string]any) (*LinkPreview, error) {
	b, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	var preview LinkPreview
	if err := json.Unmarshal(b, &preview); err != nil {
		return nil, err
	}
	return &preview, nil
}
