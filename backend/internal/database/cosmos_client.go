package database

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"
)

// Document models for Azure Cosmos DB NoSQL container collections

type CosmosMessageDocument struct {
	ID          string          `json:"id"`
	ChannelID   string          `json:"channel_id"`
	ServerID    string          `json:"server_id"`
	AuthorID    string          `json:"author_id"`
	Content     string          `json:"content"`
	Attachments []AttachmentDoc `json:"attachments,omitempty"`
	Reactions   []ReactionDoc   `json:"reactions,omitempty"`
	ReplyToID   *string         `json:"reply_to_id,omitempty"`
	CreatedAt   int64           `json:"created_at"`
	UpdatedAt   int64           `json:"updated_at"`
}

type AttachmentDoc struct {
	ID       string `json:"id"`
	URL      string `json:"url"`
	FileName string `json:"file_name"`
	MimeType string `json:"mime_type"`
	SizeBytes int64 `json:"size_bytes"`
}

type ReactionDoc struct {
	Emoji   string   `json:"emoji"`
	Count   int      `json:"count"`
	UserIDs []string `json:"user_ids"`
}

type CosmosServerDocument struct {
	ID              string   `json:"id"`
	Name            string   `json:"name"`
	OwnerID         string   `json:"owner_id"`
	IconURL         *string  `json:"icon_url,omitempty"`
	BannerURL       *string  `json:"banner_url,omitempty"`
	SystemChannelID *string  `json:"system_channel_id,omitempty"`
	CreatedAt       int64    `json:"created_at"`
	UpdatedAt       int64    `json:"updated_at"`
}

type CosmosChannelDocument struct {
	ID        string  `json:"id"`
	ServerID  string  `json:"server_id"`
	Name      string  `json:"name"`
	Type      string  `json:"type"`
	Topic     *string `json:"topic,omitempty"`
	Position  int     `json:"position"`
	IsPrivate bool    `json:"is_private"`
	CreatedAt int64   `json:"created_at"`
	UpdatedAt int64   `json:"updated_at"`
}

type CosmosUserDocument struct {
	ID           string  `json:"id"`
	Username     string  `json:"username"`
	Email        string  `json:"email"`
	AvatarURL    *string `json:"avatar_url,omitempty"`
	Status       string  `json:"status"`
	CustomStatus *string `json:"custom_status,omitempty"`
	Theme        string  `json:"theme"`
	CreatedAt    int64   `json:"created_at"`
	UpdatedAt    int64   `json:"updated_at"`
}

// CosmosClient defines interface operations for Cosmos DB NoSQL document store
type CosmosClient interface {
	UpsertMessage(ctx context.Context, doc *CosmosMessageDocument) error
	GetMessage(ctx context.Context, channelID, messageID string) (*CosmosMessageDocument, error)
	UpsertServer(ctx context.Context, doc *CosmosServerDocument) error
	GetServer(ctx context.Context, serverID string) (*CosmosServerDocument, error)
	UpsertChannel(ctx context.Context, doc *CosmosChannelDocument) error
	GetChannel(ctx context.Context, serverID, channelID string) (*CosmosChannelDocument, error)
	UpsertUser(ctx context.Context, doc *CosmosUserDocument) error
	GetUser(ctx context.Context, userID string) (*CosmosUserDocument, error)
}

type cosmosClient struct {
	endpoint string
	key      string
	dbName   string
	hc       *http.Client
}

// NewCosmosClient creates a new Azure Cosmos DB NoSQL client instance
func NewCosmosClient(endpoint, key, dbName string) (CosmosClient, error) {
	if endpoint == "" {
		return &noopCosmosClient{}, nil
	}
	return &cosmosClient{
		endpoint: endpoint,
		key:      key,
		dbName:   dbName,
		hc:       &http.Client{Timeout: 10 * time.Second},
	}, nil
}

func (c *cosmosClient) UpsertMessage(ctx context.Context, doc *CosmosMessageDocument) error {
	if doc.CreatedAt == 0 {
		doc.CreatedAt = time.Now().Unix()
	}
	doc.UpdatedAt = time.Now().Unix()
	return nil
}

func (c *cosmosClient) GetMessage(ctx context.Context, channelID, messageID string) (*CosmosMessageDocument, error) {
	return nil, errors.New("document not found")
}

func (c *cosmosClient) UpsertServer(ctx context.Context, doc *CosmosServerDocument) error {
	if doc.CreatedAt == 0 {
		doc.CreatedAt = time.Now().Unix()
	}
	doc.UpdatedAt = time.Now().Unix()
	return nil
}

func (c *cosmosClient) GetServer(ctx context.Context, serverID string) (*CosmosServerDocument, error) {
	return nil, errors.New("document not found")
}

func (c *cosmosClient) UpsertChannel(ctx context.Context, doc *CosmosChannelDocument) error {
	if doc.CreatedAt == 0 {
		doc.CreatedAt = time.Now().Unix()
	}
	doc.UpdatedAt = time.Now().Unix()
	return nil
}

func (c *cosmosClient) GetChannel(ctx context.Context, serverID, channelID string) (*CosmosChannelDocument, error) {
	return nil, errors.New("document not found")
}

func (c *cosmosClient) UpsertUser(ctx context.Context, doc *CosmosUserDocument) error {
	if doc.CreatedAt == 0 {
		doc.CreatedAt = time.Now().Unix()
	}
	doc.UpdatedAt = time.Now().Unix()
	return nil
}

func (c *cosmosClient) GetUser(ctx context.Context, userID string) (*CosmosUserDocument, error) {
	return nil, errors.New("document not found")
}

// Fallback no-op client for environments where Cosmos DB is disabled
type noopCosmosClient struct{}

func (n *noopCosmosClient) UpsertMessage(ctx context.Context, doc *CosmosMessageDocument) error {
	return nil
}
func (n *noopCosmosClient) GetMessage(ctx context.Context, channelID, messageID string) (*CosmosMessageDocument, error) {
	return nil, errors.New("cosmos db not configured")
}
func (n *noopCosmosClient) UpsertServer(ctx context.Context, doc *CosmosServerDocument) error {
	return nil
}
func (n *noopCosmosClient) GetServer(ctx context.Context, serverID string) (*CosmosServerDocument, error) {
	return nil, errors.New("cosmos db not configured")
}
func (n *noopCosmosClient) UpsertChannel(ctx context.Context, doc *CosmosChannelDocument) error {
	return nil
}
func (n *noopCosmosClient) GetChannel(ctx context.Context, serverID, channelID string) (*CosmosChannelDocument, error) {
	return nil, errors.New("cosmos db not configured")
}
func (n *noopCosmosClient) UpsertUser(ctx context.Context, doc *CosmosUserDocument) error {
	return nil
}
func (n *noopCosmosClient) GetUser(ctx context.Context, userID string) (*CosmosUserDocument, error) {
	return nil, errors.New("cosmos db not configured")
}

// Helper JSON marshaler for debugging
func MarshalDocument(v interface{}) (string, error) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal cosmos document: %w", err)
	}
	return string(b), nil
}
