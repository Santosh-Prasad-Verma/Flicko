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
	"sync"
	"time"

	"github.com/flicko-org/flicko-backend/internal/bots/delivery"
	"github.com/flicko-org/flicko-backend/internal/events"
	"go.uber.org/zap"
)

type webhookLogJob struct {
	botID        string
	evt          events.Event
	statusCode   int
	responseTime int
	success      bool
	errMsg       string
	retryCount   int
}

// WebhookDelivery handles delivery of events to external bot webhooks
type WebhookDelivery struct {
	ctx    BotContext
	client *http.Client
	logger *zap.Logger

	// HIGH-19: in-memory cache of subscribed bots per (event_type, server_id)
	// to avoid querying Postgres on every event publish.
	subMu    sync.RWMutex
	subCache map[string]subCacheEntry

	// CRIT-10: per-bot circuit breakers from the bots/delivery package.
	// A bot whose webhook URL has been failing repeatedly is taken out of
	// rotation for a cooldown window so it can't drag down delivery latency
	// for healthy bots.
	cbMu       sync.RWMutex
	breakers   map[string]*delivery.CircuitBreaker
	logQueue   chan *webhookLogJob
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
	wd := &WebhookDelivery{
		ctx: ctx,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger:   ctx.Logger,
		subCache: make(map[string]subCacheEntry),
		breakers: make(map[string]*delivery.CircuitBreaker),
		logQueue: make(chan *webhookLogJob, 10000),
	}

	// Start background log workers
	for i := 0; i < 5; i++ {
		go wd.logWorker()
	}

	return wd
}

// DeliverEvent delivers an event to all subscribed external bots.
// HIGH-9 fix: uses a bounded semaphore instead of unbounded goroutines.
// HIGH-19: bot list per (event_type, server_id) is cached for 60s in-memory
// to avoid hammering Postgres on every bus publish.
func (wd *WebhookDelivery) DeliverEvent(ctx context.Context, evt events.Event) error {
	bots, err := wd.lookupSubscribedBots(ctx, string(evt.Type), evt.ServerID)
	if err != nil {
		return err
	}

	// Deliver to each bot with bounded concurrency (HIGH-9).
	// Max 32 concurrent webhook deliveries to prevent connection exhaustion.
	sem := make(chan struct{}, 32)
	for _, bot := range bots {
		sem <- struct{}{}
		go func(b ExternalBot) {
			defer func() { <-sem }()
			wd.deliverToBot(ctx, b, evt)
		}(bot)
	}

	return nil
}

type subCacheEntry struct {
	bots      []ExternalBot
	expiresAt time.Time
}

// lookupSubscribedBots returns the cached bot list for (eventType, serverID),
// refreshing from Postgres at most once per 60 seconds.
func (wd *WebhookDelivery) lookupSubscribedBots(ctx context.Context, eventType, serverID string) ([]ExternalBot, error) {
	cacheKey := eventType + ":" + serverID

	wd.subMu.RLock()
	if entry, ok := wd.subCache[cacheKey]; ok && time.Now().Before(entry.expiresAt) {
		bots := entry.bots
		wd.subMu.RUnlock()
		return bots, nil
	}
	wd.subMu.RUnlock()

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

	rows, err := wd.ctx.DB.Query(ctx, query, eventType, serverID)
	if err != nil {
		return nil, fmt.Errorf("query subscribed bots: %w", err)
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

	wd.subMu.Lock()
	if wd.subCache == nil {
		wd.subCache = make(map[string]subCacheEntry)
	}
	wd.subCache[cacheKey] = subCacheEntry{
		bots:      bots,
		expiresAt: time.Now().Add(60 * time.Second),
	}
	wd.subMu.Unlock()

	return bots, nil
}

// InvalidateSubscriptionCache clears the subscription cache. Call when bot
// installs/uninstalls or subscriptions change so updates take effect promptly.
func (wd *WebhookDelivery) InvalidateSubscriptionCache() {
	wd.subMu.Lock()
	wd.subCache = nil
	wd.subMu.Unlock()
}

// deliverToBot delivers an event to a single bot with retry logic and a
// per-bot circuit breaker (CRIT-10). A bot that's been failing repeatedly
// short-circuits without making outbound HTTP calls until cooldown elapses.
func (wd *WebhookDelivery) deliverToBot(ctx context.Context, bot ExternalBot, evt events.Event) {
	cb := wd.getBreaker(bot.ID)
	if err := cb.Allow(); err != nil {
		wd.logger.Debug("webhook circuit open, skipping",
			zap.String("bot", bot.Name),
			zap.Error(err),
		)
		return
	}

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
			cb.RecordSuccess()
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

	cb.RecordFailure()
	wd.logger.Error("webhook delivery failed after retries",
		zap.String("bot", bot.Name),
		zap.String("event", string(evt.Type)),
	)
}

// getBreaker returns the per-bot circuit breaker, creating one on first use.
// Settings: 5 failures → open; require 2 successes during half-open to fully
// close; 30s base open duration; 10s probe window.
func (wd *WebhookDelivery) getBreaker(botID string) *delivery.CircuitBreaker {
	wd.cbMu.RLock()
	if cb, ok := wd.breakers[botID]; ok {
		wd.cbMu.RUnlock()
		return cb
	}
	wd.cbMu.RUnlock()

	wd.cbMu.Lock()
	defer wd.cbMu.Unlock()
	if cb, ok := wd.breakers[botID]; ok {
		return cb
	}
	if wd.breakers == nil {
		wd.breakers = make(map[string]*delivery.CircuitBreaker)
	}
	cb := delivery.NewCircuitBreaker(5, 2, 30*time.Second, 10*time.Second)
	wd.breakers[botID] = cb
	return cb
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

func (wd *WebhookDelivery) logWorker() {
	for job := range wd.logQueue {
		logCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		query := `
			INSERT INTO bot_webhook_deliveries (
				bot_id, event_type, event_id, server_id, status_code,
				response_time_ms, success, error_message, retry_count
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		`
		if _, dbErr := wd.ctx.DB.Exec(logCtx, query,
			job.botID, job.evt.Type, job.evt.ID, job.evt.ServerID, job.statusCode,
			job.responseTime, job.success, job.errMsg, job.retryCount,
		); dbErr != nil {
			wd.logger.Debug("log webhook delivery failed", zap.Error(dbErr))
		}
		cancel()
	}
}

// logDelivery records webhook delivery attempt in database (async queue).
func (wd *WebhookDelivery) logDelivery(ctx context.Context, botID string, evt events.Event, statusCode, responseTime int, success bool, err error, retryCount int) {
	var errMsg string
	if err != nil {
		errMsg = err.Error()
	}

	job := &webhookLogJob{
		botID:        botID,
		evt:          evt,
		statusCode:   statusCode,
		responseTime: responseTime,
		success:      success,
		errMsg:       errMsg,
		retryCount:   retryCount,
	}

	select {
	case wd.logQueue <- job:
	default:
		wd.logger.Warn("webhook log queue full, discarding delivery log")
	}
}

// VerifyWebhookSignature verifies incoming webhook signature from external bot
func VerifyWebhookSignature(body []byte, signature, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}
