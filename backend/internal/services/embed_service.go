package services

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/net/html"
	"golang.org/x/time/rate"
)

type Embed struct {
	ID          string `json:"id" db:"id"`
	MessageID   string `json:"message_id" db:"message_id"`
	Type        string `json:"type" db:"type"`
	Title       string `json:"title" db:"title"`
	Description string `json:"description" db:"description"`
	URL         string `json:"url" db:"url"`
	ImageURL    string `json:"image_url" db:"image_url"`
	VideoURL    string `json:"video_url" db:"video_url"`
	Color       *int   `json:"color" db:"color"`
}

type EmbedService interface {
	ProcessMessageForEmbeds(ctx context.Context, messageID string, content string) ([]*Embed, error)
}

type embedService struct {
	db          *pgxpool.Pool
	redis       cache.CacheLayer
	httpClient  *http.Client
	urlRegex    *regexp.Regexp
	rateLimiter *rate.Limiter
}

func NewEmbedService(db *pgxpool.Pool, redis cache.CacheLayer) EmbedService {
	// regex to find URLs http or https
	urlRegex := regexp.MustCompile(`https?://[^\s]+`)

	return &embedService{
		db:    db,
		redis: redis,
		httpClient: &http.Client{
			Timeout: 5 * time.Second, // 5 second timeout rule
		},
		urlRegex:    urlRegex,
		rateLimiter: rate.NewLimiter(10, 10), // max 10 requests per second
	}
}

func (s *embedService) ProcessMessageForEmbeds(ctx context.Context, messageID string, content string) ([]*Embed, error) {
	urls := s.urlRegex.FindAllString(content, 5) // process up to 5 URLs
	if len(urls) == 0 {
		return nil, nil // No URLs found
	}

	var embeds []*Embed

	for _, u := range urls {
		embed, err := s.fetchAndCacheEmbed(ctx, u)
		if err != nil {
			log.Printf("[Embed] Failed to fetch embed for %s: %v", u, err)
			continue
		}
		if embed != nil {
			embed.MessageID = messageID
			embed.ID = uuid.New().String()

			// Insert embed record
			// We assume the caller handles the transaction or we insert immediately.
			// Implementing 3.5: "Insert embed record with type, title..."

			query := `
				INSERT INTO public.embeds (id, message_id, type, title, description, url, image_url, video_url)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			`
			_, err := s.db.Exec(ctx, query, embed.ID, embed.MessageID, embed.Type, embed.Title, embed.Description, embed.URL, embed.ImageURL, embed.VideoURL)
			if err != nil {
				log.Printf("[Embed] Failed to persist embed to DB: %v", err)
				continue
			}
			embeds = append(embeds, embed)
		}
	}

	return embeds, nil
}

func (s *embedService) fetchAndCacheEmbed(ctx context.Context, u string) (*Embed, error) {
	cacheKey := fmt.Sprintf("embed:%s", u)

	// 1. Check Redis Cache
	var cached Embed
	err := s.redis.GetJSON(ctx, cacheKey, &cached)
	if err == nil && cached.URL != "" {
		return &cached, nil
	}

	// Wait on rate limiter
	if err := s.rateLimiter.Wait(ctx); err != nil {
		return nil, err
	}

	// 2. Fetch URL
	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	// pretend to be a standard browser to avoid generic 403s
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; FlickBot/1.0)")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("non-200 status code: %d", resp.StatusCode)
	}

	// 3. Parse limited HTML length (don't read huge files)
	limitedReader := io.LimitReader(resp.Body, 1024*1024) // 1MB max

	embed := s.parseHTMLForMetaTags(limitedReader, u)
	if embed == nil {
		return nil, nil // No useful info
	}

	// 4. Cache for 24 hours
	_ = s.redis.SetJSON(ctx, cacheKey, embed, 24*time.Hour)

	return embed, nil
}

func (s *embedService) parseHTMLForMetaTags(r io.Reader, sourceURL string) *Embed {
	embed := &Embed{
		URL:  sourceURL,
		Type: "link",
	}

	tokenizer := html.NewTokenizer(r)
	var titleFound bool

	for {
		tt := tokenizer.Next()
		if tt == html.ErrorToken {
			break
		}

		if tt == html.StartTagToken || tt == html.SelfClosingTagToken {
			token := tokenizer.Token()

			if token.Data == "title" && !titleFound {
				tt = tokenizer.Next()
				if tt == html.TextToken {
					if embed.Title == "" { // Fallback if no og:title
						embed.Title = strings.TrimSpace(tokenizer.Token().Data)
						titleFound = true
					}
				}
				continue
			}

			if token.Data == "meta" {
				var prop, name, content string
				for _, attr := range token.Attr {
					if attr.Key == "property" {
						prop = attr.Val
					} else if attr.Key == "name" {
						name = attr.Val
					} else if attr.Key == "content" {
						content = attr.Val
					}
				}

				key := prop
				if key == "" {
					key = name
				}

				switch key {
				case "og:title", "twitter:title":
					embed.Title = content
					titleFound = true
				case "og:description", "twitter:description", "description":
					if embed.Description == "" { // Prevent overwrite if og exists
						embed.Description = content
					}
				case "og:image", "twitter:image":
					if embed.ImageURL == "" {
						embed.ImageURL = content
					}
				case "og:video":
					if embed.VideoURL == "" {
						embed.VideoURL = content
						embed.Type = "video"
					}
				}
			}
		}
	}

	if embed.Title == "" && embed.Description == "" && embed.ImageURL == "" {
		return nil // Not enough info to make an embed
	}

	return embed
}
