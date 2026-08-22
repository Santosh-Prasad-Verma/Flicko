// Package llm provides a thin streaming chat-completion client used by all
// AI features in Flicko (catch-me-up summary, server insights, moderation, etc).
//
// Powered by Google Gemini (e.g. gemini-2.5-flash / gemini-2.0-flash).
//
// Streaming format is OpenAI-compatible Server-Sent Events:
//
//	data: {"choices":[{"delta":{"content":"hello"}}]}
//	data: [DONE]
package llm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go.uber.org/zap"
)

// Role for a chat message.
type Role string

const (
	RoleSystem    Role = "system"
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
)

// Message is one entry in the chat history sent to the model.
type Message struct {
	Role    Role   `json:"role"`
	Content string `json:"content"`
}

// Request describes a single streaming completion call.
type Request struct {
	Messages    []Message
	Temperature float32
	MaxTokens   int
	// StopSequences halts generation when any is encountered.
	StopSequences []string
}

// Token is one streamed delta from the model.
type Token struct {
	Content string
	// Done is true on the final emit and carries usage stats.
	Done   bool
	Usage  Usage
	Model  string
	Reason string // finish reason: stop, length, content_filter, error
}

// Usage records token accounting from the provider.
type Usage struct {
	PromptTokens     int
	CompletionTokens int
	TotalTokens      int
}

// Client is the public interface used by callers.
type Client interface {
	// Stream runs a chat completion. Tokens flow on the returned channel and
	// the channel is closed when the stream ends. The last token has Done=true.
	// On error, an error token (Done=true, Reason="error") is emitted and the
	// channel is closed.
	Stream(ctx context.Context, req Request) (<-chan Token, error)
	// ProviderName identifies which backend handled the call after Stream returns.
	ProviderName() string
}

// Config controls the Gemini backend settings.
type Config struct {
	GeminiAPIKey  string
	GeminiBaseURL string // default https://generativelanguage.googleapis.com/v1beta/openai
	GeminiModel   string // default gemini-2.5-flash

	HTTPTimeout time.Duration
}

// New returns a Gemini LLM client.
func New(cfg Config, logger *zap.Logger) Client {
	if logger == nil {
		logger = zap.NewNop()
	}
	if cfg.HTTPTimeout == 0 {
		cfg.HTTPTimeout = 30 * time.Second
	}
	baseURL := cfg.GeminiBaseURL
	if baseURL == "" {
		baseURL = "https://generativelanguage.googleapis.com/v1beta/openai"
	}
	model := cfg.GeminiModel
	if model == "" {
		model = "gemini-2.5-flash"
	}

	httpClient := &http.Client{Timeout: cfg.HTTPTimeout}

	return &geminiClient{
		name:    "gemini",
		baseURL: strings.TrimRight(baseURL, "/"),
		apiKey:  cfg.GeminiAPIKey,
		model:   model,
		http:    httpClient,
		logger:  logger.Named("ai.llm.gemini"),
	}
}

type geminiClient struct {
	name    string
	baseURL string
	apiKey  string
	model   string
	http    *http.Client
	logger  *zap.Logger
}

func (p *geminiClient) ProviderName() string { return p.name }

type oaiChatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Stream      bool      `json:"stream"`
	Temperature float32   `json:"temperature,omitempty"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
	Stop        []string  `json:"stop,omitempty"`
}

type oaiStreamChunk struct {
	Choices []struct {
		Delta struct {
			Content string `json:"content"`
		} `json:"delta"`
		FinishReason string `json:"finish_reason"`
	} `json:"choices"`
	Usage *struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage,omitempty"`
}

func (p *geminiClient) Stream(ctx context.Context, req Request) (<-chan Token, error) {
	if p.apiKey == "" {
		out := make(chan Token, 1)
		out <- Token{Done: true, Reason: "error", Content: "Gemini API key is not configured", Model: p.model}
		close(out)
		return out, nil
	}

	body, err := json.Marshal(oaiChatRequest{
		Model:       p.model,
		Messages:    req.Messages,
		Stream:      true,
		Temperature: req.Temperature,
		MaxTokens:   req.MaxTokens,
		Stop:        req.StopSequences,
	})
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+p.apiKey)
	httpReq.Header.Set("Accept", "text/event-stream")

	resp, err := p.http.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("transport error: %w", err)
	}
	if resp.StatusCode >= 400 {
		buf, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		_ = resp.Body.Close()
		return nil, fmt.Errorf("provider %s status %d: %s", p.name, resp.StatusCode, string(buf))
	}

	out := make(chan Token, 16)
	go func() {
		defer close(out)
		defer resp.Body.Close()

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

		var usage Usage
		var finishReason string

		for scanner.Scan() {
			line := scanner.Text()
			if !strings.HasPrefix(line, "data: ") {
				continue
			}
			payload := strings.TrimPrefix(line, "data: ")
			if payload == "[DONE]" {
				break
			}
			var chunk oaiStreamChunk
			if err := json.Unmarshal([]byte(payload), &chunk); err != nil {
				p.logger.Debug("dropping malformed sse line", zap.String("line", payload))
				continue
			}
			if chunk.Usage != nil {
				usage.PromptTokens = chunk.Usage.PromptTokens
				usage.CompletionTokens = chunk.Usage.CompletionTokens
				usage.TotalTokens = chunk.Usage.TotalTokens
			}
			for _, choice := range chunk.Choices {
				if choice.Delta.Content != "" {
					select {
					case out <- Token{Content: choice.Delta.Content, Model: p.model}:
					case <-ctx.Done():
						return
					}
				}
				if choice.FinishReason != "" {
					finishReason = choice.FinishReason
				}
			}
		}
		if err := scanner.Err(); err != nil {
			out <- Token{Done: true, Reason: "error", Content: err.Error(), Model: p.model}
			return
		}
		out <- Token{Done: true, Reason: nonEmpty(finishReason, "stop"), Model: p.model, Usage: usage}
	}()

	return out, nil
}

func nonEmpty(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

