package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Webhook Service Interface ──────────────────────────────────────────────

type WebhookService interface {
	CreateWebhook(ctx context.Context, channelID, creatorID, name string, avatar *string) (*models.Webhook, error)
	PostMessage(ctx context.Context, webhookID, secret, content string, username, avatarURL *string) error
	GetWebhooks(ctx context.Context, channelID string) ([]*models.Webhook, error)
	DeleteWebhook(ctx context.Context, webhookID, executorID string) error
}

// ─── Rate Limiter ───────────────────────────────────────────────────────────

type webhookRateLimiter struct {
	mu       sync.Mutex
	counters map[string]*rateBucket
}

type rateBucket struct {
	count    int
	windowAt time.Time
}

func newWebhookRateLimiter() *webhookRateLimiter {
	return &webhookRateLimiter{counters: make(map[string]*rateBucket)}
}

func (rl *webhookRateLimiter) Allow(webhookID string, maxPerMinute int) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	bucket, exists := rl.counters[webhookID]
	if !exists || now.Sub(bucket.windowAt) > time.Minute {
		rl.counters[webhookID] = &rateBucket{count: 1, windowAt: now}
		return true
	}

	if bucket.count >= maxPerMinute {
		return false
	}

	bucket.count++
	return true
}

// ─── Implementation ─────────────────────────────────────────────────────────

type webhookService struct {
	db          *pgxpool.Pool
	permService PermissionService
	rateLimiter *webhookRateLimiter
	baseURL     string
}

func NewWebhookService(db *pgxpool.Pool, permService PermissionService, baseURL string) WebhookService {
	return &webhookService{
		db:          db,
		permService: permService,
		rateLimiter: newWebhookRateLimiter(),
		baseURL:     baseURL,
	}
}

func generateSecret() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func (s *webhookService) CreateWebhook(ctx context.Context, channelID, creatorID, name string, avatar *string) (*models.Webhook, error) {
	chanUUID, err1 := uuid.Parse(channelID)
	creatorUUID, err2 := uuid.Parse(creatorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, creatorUUID, chanUUID, "MANAGE_WEBHOOKS")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_WEBHOOKS permission")
	}

	// Get server_id from channel
	var serverID uuid.UUID
	err = s.db.QueryRow(ctx, "SELECT server_id FROM public.channels WHERE id = $1", chanUUID).Scan(&serverID)
	if err != nil {
		return nil, fmt.Errorf("channel not found: %w", err)
	}

	webhookID := uuid.New()
	secret := generateSecret()
	url := fmt.Sprintf("%s/webhooks/%s/%s", s.baseURL, webhookID.String(), secret)

	query := `
		INSERT INTO public.webhooks (id, server_id, channel_id, creator_id, name, avatar, webhook_type, url, secret, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, 'incoming', $7, $8, true)
		RETURNING id, server_id, channel_id, creator_id, name, avatar, webhook_type, url, secret, is_active, usage_count, created_at, updated_at
	`

	var wh models.Webhook
	err = s.db.QueryRow(ctx, query, webhookID, serverID, chanUUID, creatorUUID, name, avatar, url, secret).
		Scan(&wh.ID, &wh.ServerID, &wh.ChannelID, &wh.CreatorID, &wh.Name, &wh.Avatar, &wh.WebhookType, &wh.URL, &wh.Secret, &wh.IsActive, &wh.UsageCount, &wh.CreatedAt, &wh.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create webhook: %w", err)
	}

	return &wh, nil
}

func (s *webhookService) PostMessage(ctx context.Context, webhookID, secret, content string, username, avatarURL *string) error {
	whUUID, err := uuid.Parse(webhookID)
	if err != nil {
		return fmt.Errorf("invalid webhook id")
	}

	// Validate webhook exists and secret matches
	var storedSecret string
	var channelID uuid.UUID
	var isActive bool
	err = s.db.QueryRow(ctx,
		"SELECT secret, channel_id, is_active FROM public.webhooks WHERE id = $1",
		whUUID,
	).Scan(&storedSecret, &channelID, &isActive)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("webhook not found")
		}
		return err
	}

	if !isActive {
		return fmt.Errorf("webhook is inactive")
	}
	if storedSecret != secret {
		return fmt.Errorf("invalid webhook secret")
	}

	// Rate Limiting: 30 requests/minute
	if !s.rateLimiter.Allow(webhookID, 30) {
		fmt.Printf("warning: webhook rate limit exceeded for %s\n", webhookID)
		return fmt.Errorf("rate limit exceeded: max 30 requests per minute")
	}

	// Insert message into channel
	_, err = s.db.Exec(ctx,
		`INSERT INTO public.messages (channel_id, author_id, content) VALUES ($1, NULL, $2)`,
		channelID, content,
	)
	if err != nil {
		return fmt.Errorf("failed to post webhook message: %w", err)
	}

	// Increment usage count
	_, err = s.db.Exec(ctx, "UPDATE public.webhooks SET usage_count = usage_count + 1 WHERE id = $1", whUUID)
	return err
}

func (s *webhookService) GetWebhooks(ctx context.Context, channelID string) ([]*models.Webhook, error) {
	chanUUID, err := uuid.Parse(channelID)
	if err != nil {
		return nil, fmt.Errorf("invalid channel uuid")
	}

	rows, err := s.db.Query(ctx,
		"SELECT id, server_id, channel_id, creator_id, name, avatar, webhook_type, url, secret, is_active, usage_count, created_at, updated_at FROM public.webhooks WHERE channel_id = $1 ORDER BY created_at DESC",
		chanUUID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var webhooks []*models.Webhook
	for rows.Next() {
		wh := &models.Webhook{}
		if err := rows.Scan(&wh.ID, &wh.ServerID, &wh.ChannelID, &wh.CreatorID, &wh.Name, &wh.Avatar, &wh.WebhookType, &wh.URL, &wh.Secret, &wh.IsActive, &wh.UsageCount, &wh.CreatedAt, &wh.UpdatedAt); err != nil {
			return nil, err
		}
		webhooks = append(webhooks, wh)
	}
	return webhooks, nil
}

func (s *webhookService) DeleteWebhook(ctx context.Context, webhookID, executorID string) error {
	whUUID, err1 := uuid.Parse(webhookID)
	executorUUID, err2 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	// Get webhook's channel to check permissions
	var chanID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT channel_id FROM public.webhooks WHERE id = $1", whUUID).Scan(&chanID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("webhook not found")
		}
		return err
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, chanID, "MANAGE_WEBHOOKS")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_WEBHOOKS permission")
	}

	_, err = s.db.Exec(ctx, "DELETE FROM public.webhooks WHERE id = $1", whUUID)
	return err
}
