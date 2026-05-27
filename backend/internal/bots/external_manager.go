package bots

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
)

// ExternalBotManager handles external bot registration and management
type ExternalBotManager struct {
	ctx      BotContext
	delivery *WebhookDelivery
	logger   *zap.Logger
}

// BotRegistration represents a new bot registration request
type BotRegistration struct {
	Name              string   `json:"name"`
	Description       string   `json:"description"`
	DeveloperID       string   `json:"developer_id"`
	AvatarURL         string   `json:"avatar_url,omitempty"`
	WebhookURL        string   `json:"webhook_url"`
	Permissions       int64    `json:"permissions"`
	Categories        []string `json:"categories"`
	Tags              []string `json:"tags"`
	WebsiteURL        string   `json:"website_url,omitempty"`
	PrivacyPolicyURL  string   `json:"privacy_policy_url,omitempty"`
	TermsOfServiceURL string   `json:"terms_of_service_url,omitempty"`
}

// BotInstallation represents a bot installation on a server
type BotInstallation struct {
	BotID       string                 `json:"bot_id"`
	ServerID    string                 `json:"server_id"`
	InstalledBy string                 `json:"installed_by"`
	Permissions int64                  `json:"permissions"`
	Config      map[string]interface{} `json:"config"`
}

// NewExternalBotManager creates a new external bot manager
func NewExternalBotManager(ctx BotContext) *ExternalBotManager {
	return &ExternalBotManager{
		ctx:      ctx,
		delivery: NewWebhookDelivery(ctx),
		logger:   ctx.Logger,
	}
}

// RegisterBot registers a new external bot
func (m *ExternalBotManager) RegisterBot(ctx context.Context, reg BotRegistration) (string, string, error) {
	// Generate webhook secret
	webhookSecret, err := generateSecret(32)
	if err != nil {
		return "", "", fmt.Errorf("generate webhook secret: %w", err)
	}

	query := `
		INSERT INTO external_bots (
			name, description, developer_id, avatar_url, webhook_url,
			webhook_secret, permissions, categories, tags, website_url,
			privacy_policy_url, terms_of_service_url, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'pending')
		RETURNING id
	`

	var botID string
	err = m.ctx.DB.QueryRow(ctx, query,
		reg.Name, reg.Description, reg.DeveloperID, reg.AvatarURL, reg.WebhookURL,
		webhookSecret, reg.Permissions, reg.Categories, reg.Tags, reg.WebsiteURL,
		reg.PrivacyPolicyURL, reg.TermsOfServiceURL,
	).Scan(&botID)

	if err != nil {
		return "", "", fmt.Errorf("insert bot: %w", err)
	}

	m.logger.Info("bot registered",
		zap.String("bot_id", botID),
		zap.String("name", reg.Name),
		zap.String("developer", reg.DeveloperID),
	)

	return botID, webhookSecret, nil
}

// InstallBot installs a bot on a server
func (m *ExternalBotManager) InstallBot(ctx context.Context, install BotInstallation) error {
	// Verify bot is approved
	var status string
	err := m.ctx.DB.QueryRow(ctx,
		`SELECT status FROM external_bots WHERE id = $1`,
		install.BotID,
	).Scan(&status)

	if err != nil {
		return fmt.Errorf("query bot status: %w", err)
	}

	if status != "approved" {
		return fmt.Errorf("bot not approved: status=%s", status)
	}

	// Insert installation
	query := `
		INSERT INTO bot_installations (
			bot_id, server_id, installed_by, permissions, config
		) VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (bot_id, server_id) DO UPDATE
		SET enabled = true, updated_at = now()
	`

	_, err = m.ctx.DB.Exec(ctx, query,
		install.BotID, install.ServerID, install.InstalledBy,
		install.Permissions, install.Config,
	)

	if err != nil {
		return fmt.Errorf("insert installation: %w", err)
	}

	// HIGH-19: invalidate the per-(event,server) cache so the new install
	// receives events immediately.
	m.delivery.InvalidateSubscriptionCache()

	m.logger.Info("bot installed",
		zap.String("bot_id", install.BotID),
		zap.String("server_id", install.ServerID),
	)

	return nil
}

// UninstallBot removes a bot from a server
func (m *ExternalBotManager) UninstallBot(ctx context.Context, botID, serverID string) error {
	query := `DELETE FROM bot_installations WHERE bot_id = $1 AND server_id = $2`
	_, err := m.ctx.DB.Exec(ctx, query, botID, serverID)
	if err != nil {
		return fmt.Errorf("delete installation: %w", err)
	}

	m.delivery.InvalidateSubscriptionCache()

	m.logger.Info("bot uninstalled",
		zap.String("bot_id", botID),
		zap.String("server_id", serverID),
	)

	return nil
}

// SubscribeToEvents subscribes a bot to specific event types
func (m *ExternalBotManager) SubscribeToEvents(ctx context.Context, botID string, eventTypes []string) error {
	for _, eventType := range eventTypes {
		query := `
			INSERT INTO bot_event_subscriptions (bot_id, event_type)
			VALUES ($1, $2)
			ON CONFLICT (bot_id, event_type) DO UPDATE SET enabled = true
		`
		_, err := m.ctx.DB.Exec(ctx, query, botID, eventType)
		if err != nil {
			return fmt.Errorf("subscribe to %s: %w", eventType, err)
		}
	}

	m.delivery.InvalidateSubscriptionCache()

	m.logger.Info("bot subscribed to events",
		zap.String("bot_id", botID),
		zap.Strings("events", eventTypes),
	)

	return nil
}

// GenerateAPIKey generates a new API key for a bot
func (m *ExternalBotManager) GenerateAPIKey(ctx context.Context, botID, name string, scopes []string, expiresAt *time.Time) (string, error) {
	// Generate random API key
	apiKey, err := generateSecret(32)
	if err != nil {
		return "", fmt.Errorf("generate api key: %w", err)
	}

	// Hash the key for storage
	keyHash, err := bcrypt.GenerateFromPassword([]byte(apiKey), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("hash api key: %w", err)
	}

	// Store with prefix for identification
	prefix := apiKey[:8]
	fullKey := fmt.Sprintf("flicko_bot_%s", apiKey)

	query := `
		INSERT INTO bot_api_keys (bot_id, key_hash, key_prefix, name, scopes, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`

	var keyID string
	err = m.ctx.DB.QueryRow(ctx, query, botID, string(keyHash), prefix, name, scopes, expiresAt).Scan(&keyID)
	if err != nil {
		return "", fmt.Errorf("insert api key: %w", err)
	}

	m.logger.Info("api key generated",
		zap.String("bot_id", botID),
		zap.String("key_id", keyID),
		zap.String("name", name),
	)

	return fullKey, nil
}

// ValidateAPIKey validates an API key and returns the bot ID
func (m *ExternalBotManager) ValidateAPIKey(ctx context.Context, apiKey string) (string, error) {
	// Extract prefix
	if len(apiKey) < 18 || apiKey[:10] != "flicko_bot" {
		return "", fmt.Errorf("invalid api key format")
	}

	actualKey := apiKey[11:] // Remove "flicko_bot_" prefix
	prefix := actualKey[:8]

	// Query keys with matching prefix
	query := `
		SELECT bak.bot_id, bak.key_hash
		FROM bot_api_keys bak
		JOIN external_bots eb ON eb.id = bak.bot_id
		WHERE bak.key_prefix = $1
		  AND bak.revoked = false
		  AND (bak.expires_at IS NULL OR bak.expires_at > now())
		  AND eb.status = 'approved'
	`

	rows, err := m.ctx.DB.Query(ctx, query, prefix)
	if err != nil {
		return "", fmt.Errorf("query api keys: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var botID, keyHash string
		if err := rows.Scan(&botID, &keyHash); err != nil {
			continue
		}

		// Verify hash
		if err := bcrypt.CompareHashAndPassword([]byte(keyHash), []byte(actualKey)); err == nil {
			// Update last used timestamp
			go m.updateKeyLastUsed(context.Background(), botID, prefix)
			return botID, nil
		}
	}

	return "", fmt.Errorf("invalid api key")
}

// updateKeyLastUsed updates the last_used_at timestamp for an API key
func (m *ExternalBotManager) updateKeyLastUsed(ctx context.Context, botID, prefix string) {
	query := `UPDATE bot_api_keys SET last_used_at = now() WHERE bot_id = $1 AND key_prefix = $2`
	_, err := m.ctx.DB.Exec(ctx, query, botID, prefix)
	if err != nil {
		m.logger.Error("update key last used", zap.Error(err))
	}
}

// RegisterEventHandler registers the webhook delivery handler with the event bus
func (m *ExternalBotManager) RegisterEventHandler() {
	// Subscribe to all event types that external bots can receive.
	// HIGH-7 fix: use a unique name per event type to avoid collisions
	// when EventBus.Subscribe deduplicates by (eventType, name).
	eventTypes := []events.EventType{
		events.MessageCreate, events.MessageUpdate, events.MessageDelete,
		events.MemberJoin, events.MemberLeave, events.MemberBan, events.MemberUnban,
		events.ReactionAdd, events.ReactionRemove,
		events.ChannelCreate, events.ChannelUpdate, events.ChannelDelete,
		events.RoleCreate, events.RoleUpdate, events.RoleDelete,
		events.VoiceJoin, events.VoiceLeave,
	}

	for _, eventType := range eventTypes {
		et := eventType // capture for closure
		m.ctx.EventBus.Subscribe(et, "external-bot-webhook:"+string(et), func(evt events.Event) error {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			return m.delivery.DeliverEvent(ctx, evt)
		})
	}

	m.logger.Info("external bot webhook handler registered")
}

// generateSecret generates a cryptographically secure random secret
func generateSecret(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}
