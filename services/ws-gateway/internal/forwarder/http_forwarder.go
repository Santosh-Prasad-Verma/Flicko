// Package forwarder implements the conn.MessageForwarder interface by
// forwarding WS message creates to the msg-service REST API. This
// ensures messages are persisted to PostgreSQL before Pub/Sub publish.
package forwarder

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"go.uber.org/zap"
)

// createMessageRequest matches the msg-service handler's expected body.
type createMessageRequest struct {
	Content string `json:"content"`
	Nonce   string `json:"nonce,omitempty"`
}

// createMessageResponse is the subset of msg-service response we need.
type createMessageResponse struct {
	ID string `json:"id"`
}

// HTTPForwarder sends message create requests to the msg-service REST API.
// Thread-safe: uses a shared http.Client with connection pooling.
type HTTPForwarder struct {
	baseURL      string
	httpClient   *http.Client
	jwtToken     string // Internal service-to-service JWT (optional)
	gatewayToken string // Shared secret for X-Gateway-Token (defense-in-depth)
	log          *zap.Logger
}

// NewHTTPForwarder creates an HTTPForwarder.
//
//   - baseURL:  msg-service URL, e.g. "http://msg-service:8081"
//   - jwtToken: optional service-to-service auth token
//   - gatewayToken: shared secret for X-Gateway-Token header (defense-in-depth)
func NewHTTPForwarder(baseURL string, jwtToken string, gatewayToken string, log *zap.Logger) *HTTPForwarder {
	return &HTTPForwarder{
		baseURL:    baseURL,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        50,
				MaxIdleConnsPerHost: 50,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		jwtToken:     jwtToken,
		gatewayToken: gatewayToken,
		log:          log.Named("forwarder"),
	}
}

// ForwardMessage sends a message create request to the msg-service.
// Returns the created message ID or an error.
//
// Retries up to 3 times with exponential backoff on transient HTTP errors
// (5xx, network errors). 4xx errors are never retried.
func (f *HTTPForwarder) ForwardMessage(ctx context.Context, channelID, authorID, content, nonce string) (string, error) {
	body := createMessageRequest{
		Content: content,
		Nonce:   nonce,
	}

	data, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("forwarder: marshal: %w", err)
	}

	url := fmt.Sprintf("%s/v1/channels/%s/messages", f.baseURL, channelID)

	const maxRetries = 3
	var lastErr error

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			backoff := time.Duration(1<<uint(attempt-1)) * 100 * time.Millisecond
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(backoff):
			}
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
		if err != nil {
			return "", fmt.Errorf("forwarder: new request: %w", err)
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Flicko-User-ID", authorID)
		req.Header.Set("X-Flicko-Internal", "true")

		// Defense-in-depth: shared secret for msg-service to verify the request
		// originated from a trusted internal service.
		if f.gatewayToken != "" {
			req.Header.Set("X-Gateway-Token", f.gatewayToken)
		}

		if f.jwtToken != "" {
			req.Header.Set("Authorization", "Bearer "+f.jwtToken)
		}

		resp, err := f.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("forwarder: http do: %w", err)
			if attempt < maxRetries {
				f.log.Warn("forwarder retry on network error",
					zap.Int("attempt", attempt+1),
					zap.Error(err),
				)
				continue
			}
			return "", lastErr
		}

		if resp.StatusCode >= 500 && attempt < maxRetries {
			resp.Body.Close()
			f.log.Warn("forwarder retry on 5xx",
				zap.Int("status", resp.StatusCode),
				zap.Int("attempt", attempt+1),
			)
			continue
		}

		if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
			respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
			resp.Body.Close()
			f.log.Error("msg-service returned error",
				zap.Int("status", resp.StatusCode),
				zap.String("body", string(respBody)),
				zap.String("channel_id", channelID),
			)
			return "", fmt.Errorf("forwarder: msg-service returned %d", resp.StatusCode)
		}

		var result createMessageResponse
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			return "", fmt.Errorf("forwarder: decode response: %w", err)
		}
		resp.Body.Close()

		f.log.Debug("message forwarded",
			zap.String("channel_id", channelID),
			zap.String("message_id", result.ID),
			zap.Int("attempts", attempt+1),
		)
		return result.ID, nil
	}

	return "", fmt.Errorf("forwarder: all retries exhausted: %w", lastErr)
}
