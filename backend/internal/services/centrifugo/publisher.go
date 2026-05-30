// Package centrifugo provides a thin HTTP wrapper over the Centrifugo
// server-side API. We use it to publish authoritative game events from the
// Go backend to the Centrifugo channels that mobile clients subscribe to.
//
// We intentionally avoid pulling in github.com/centrifugal/gocent — the
// publish API is a single POST and we don't need any of the client features
// (history, presence, surveys) right now.
package centrifugo

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.uber.org/zap"
)

// Publisher publishes JSON payloads to Centrifugo channels.
type Publisher interface {
	Publish(ctx context.Context, channel string, data any) error
}

// HTTPPublisher posts to <api_url> with the configured api key. When [apiURL]
// is empty (i.e. Centrifugo not configured locally) Publish is a logged
// no-op so the rest of the backend works in dev/CI without Centrifugo.
type HTTPPublisher struct {
	apiURL string
	apiKey string
	client *http.Client
	logger *zap.Logger
}

func NewHTTPPublisher(apiURL, apiKey string, logger *zap.Logger) *HTTPPublisher {
	return &HTTPPublisher{
		apiURL: apiURL,
		apiKey: apiKey,
		client: &http.Client{Timeout: 3 * time.Second},
		logger: logger,
	}
}

type publishCmd struct {
	Method string         `json:"method"`
	Params publishParams  `json:"params"`
}

type publishParams struct {
	Channel string          `json:"channel"`
	Data    json.RawMessage `json:"data"`
}

type apiResponse struct {
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func (p *HTTPPublisher) Publish(ctx context.Context, channel string, data any) error {
	if p == nil || p.apiURL == "" {
		// No-op when not configured. Useful in dev/tests.
		return nil
	}

	raw, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshal publish payload: %w", err)
	}

	body, err := json.Marshal(publishCmd{
		Method: "publish",
		Params: publishParams{Channel: channel, Data: raw},
	})
	if err != nil {
		return fmt.Errorf("marshal publish cmd: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.apiURL,
		bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if p.apiKey != "" {
		req.Header.Set("X-API-Key", p.apiKey)
	}

	resp, err := p.client.Do(req)
	if err != nil {
		// Best-effort: never fail the game action because broadcast failed.
		if p.logger != nil {
			p.logger.Warn("centrifugo publish HTTP failed",
				zap.String("channel", channel), zap.Error(err))
		}
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		if p.logger != nil {
			p.logger.Warn("centrifugo publish non-2xx",
				zap.String("channel", channel), zap.Int("status", resp.StatusCode))
		}
		return nil
	}

	var apiResp apiResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err == nil && apiResp.Error != nil {
		if p.logger != nil {
			p.logger.Warn("centrifugo publish API error",
				zap.String("channel", channel),
				zap.Int("code", apiResp.Error.Code),
				zap.String("msg", apiResp.Error.Message))
		}
	}
	return nil
}

// NopPublisher discards all publishes. Use in tests.
type NopPublisher struct{}

func (NopPublisher) Publish(context.Context, string, any) error { return nil }
