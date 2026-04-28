package bots

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

// WebhookDelivery handles delivery of events to external bot webhooks
type WebhookDelivery struct {
	ctx    BotContext
	client *http.Client
	logger *zap.Logger
}

// ExternalBot represents a registered external bot
type ExternalBot struct {
	ID            string
	Name          string
	WebhookURL    string
	WebhookSecret string
	Permissions   int64
}

// WebhookPayload is the structure sent to external bot webhooks
type WebhookPayload struct {
	EventID   string                 `json:"event_id"`
	EventType string                 `json:"event_type"`
	Timestamp time.Time              `json:"timestamp"`
	ServerID  string                 `json:"server_id,omitempty"`
	ChannelID string                 `json:"channel_id,omitempty"`
	UserID    string                 `json:"user_id,omitempty"`
	Data      map[string]interface{} `json:"data"`
}

// NewWebhookDelivery creates a new webhook delivery service
func NewWebhookDelivery(ctx BotContext) *WebhookDelivery {
	return &WebhookDelivery{
		ctx: ctx,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger: ctx.Logger,
	}
}

// DeliverEvent delivers an event to all subscribed external bots
func (wd *WebhookDelivery) DeliverEvent(ctx context.Context, evt events.Event) error {
	// Query all bots subscribed to this event type
	query := `
		SELECT eb.id, eb.name, eb.webhook_url, eb.webhook_secret, eb.permissions
		FROM external_bots eb
		JOIN bot_event_subscriptions bes ON bes.bot_id = eb.id
		JOIN bot_installations bi ON bi.bot_id = eb.id
		WHERE bes.event_type = $1
		  AND bes.enabled = true
		  AND eb.status = 'approved'
		  AND bi.server_id = $2
		  AND bi.enabled = true
	`

	rows, err := wd.ctx.DB.Query(ctx, query, evt.Type, evt.ServerID)
	if err != nil {
		return fmt.Errorf("query subscribed bots: %w", err)
	}
	defer rows.Close()

	var bots []ExternalBot
	for rows.Next() {
		var bot ExternalBot
		if err := rows.Scan(&bot.ID, &bot.Name, &bot.WebhookURL, &bot.WebhookSecret, &bot.Permissions); err != nil {
			wd.logger.Error("scan bot row", zap.Error(err))
			continue
		}
		bots = append(bots, bot)
	}

	// Deliver to each bot asynchronously
	for _, bot := range bots {
		go wd.deliverToBot(ctx, bot, evt)
	}

	return nil
}

// deliverToBot delivers an event to a single bot with retry logic
func (wd *WebhookDelivery) deliverToBot(ctx context.Context, bot ExternalBot, evt events.Event) {
	payload := WebhookPayload{
		EventID:   evt.ID,
		EventType: string(evt.Type),
		Timestamp: evt.Timestamp,
		ServerID:  evt.ServerID,
		ChannelID: evt.ChannelID,
		UserID:    evt.UserID,
		Data:      evt.Data,
	}

	maxRetries := 3
	for attempt := 0; attempt <= maxRetries; attempt++ {
		startTime := time.Now()
		statusCode, err := wd.sendWebhook(ctx, bot, payload)
		responseTime := time.Since(startTime).Milliseconds()

		success := err == nil && statusCode >= 200 && statusCode < 300

		// Log delivery
		wd.logDelivery(ctx, bot.ID, evt, statusCode, int(responseTime), success, err, attempt)

		if success {
			wd.logger.Debug("webhook delivered",
				zap.String("bot", bot.Name),
				zap.String("event", string(evt.Type)),
				zap.Int("status", statusCode),
				zap.Int64("ms", responseTime),
			)
			return
		}

		if attempt < maxRetries {
			backoff := time.Duration(1<<uint(attempt)) * time.Second
			time.Sleep(backoff)
		}
	}

	wd.logger.Error("webhook delivery failed after retries",
		zap.String("bot", bot.Name),
		zap.String("event", string(evt.Type)),
	)
}

// sendWebhook sends the webhook HTTP request with HMAC signature
func (wd *WebhookDelivery) sendWebhook(ctx context.Context, bot ExternalBot, payload WebhookPayload) (int, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return 0, fmt.Errorf("marshal payload: %w", err)
	}

	// Generate HMAC signature
	signature := wd.generateSignature(body, bot.WebhookSecret)

	req, err := http.NewRequestWithContext(ctx, "POST", bot.WebhookURL, bytes.NewReader(body))
	if err != nil {
		return 0, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Flicko-Signature", signature)
	req.Header.Set("X-Flicko-Event", payload.EventType)
	req.Header.Set("X-Flicko-Event-ID", payload.EventID)
	req.Header.Set("User-Agent", "Flicko-Webhook/1.0")

	resp, err := wd.client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("send request: %w", err)
	}
	defer resp.Body.Close()

	return resp.StatusCode, nil
}

// generateSignature creates HMAC-SHA256 signature for webhook verification
func (wd *WebhookDelivery) generateSignature(body []byte, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

// logDelivery records webhook delivery attempt in database
func (wd *WebhookDelivery) logDelivery(ctx context.Context, botID string, evt events.Event, statusCode, responseTime int, success bool, err error, retryCount int) {
	var errMsg string
	if err != nil {
		errMsg = err.Error()
	}

	query := `
		INSERT INTO bot_webhook_deliveries (
			bot_id, event_type, event_id, server_id, status_code,
			response_time_ms, success, error_message, retry_count
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	_, dbErr := wd.ctx.DB.Exec(ctx, query,
		botID, evt.Type, evt.ID, evt.ServerID, statusCode,
		responseTime, success, errMsg, retryCount,
	)

	if dbErr != nil {
		wd.logger.Error("log webhook delivery", zap.Error(dbErr))
	}
}

// VerifyWebhookSignature verifies incoming webhook signature from external bot
func VerifyWebhookSignature(body []byte, signature, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}
