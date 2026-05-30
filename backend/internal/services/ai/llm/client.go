// Package llm provides a thin streaming chat-completion client used by all
// AI features in Flicko (catch-me-up summary, server insights, etc).
//
// It wraps two backends behind a single interface:
//
//   - Groq's OpenAI-compatible API (primary, free tier, ~80 t/s)
//   - Ollama running locally (fallback, no quota)
//
// The interface is intentionally minimal: a single Stream() method that
// returns tokens on a channel and a final usage record when done.
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
	"errors"
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

// Config controls which backends are used.
type Config struct {
	GroqAPIKey  string
	GroqBaseURL string // e.g. https://api.groq.com/openai/v1
	GroqModel   string

	OllamaBaseURL string // e.g. http://ollama:11434
	OllamaModel   string

	HTTPTimeout time.Duration
}

// New returns a client that prefers Groq when an API key is configured and
// falls back to Ollama on transport errors / 5xx responses. If no Groq key
// is set, Ollama is the only backend.
func New(cfg Config, logger *zap.Logger) Client {
	if logger == nil {
		logger = zap.NewNop()
	}
	if cfg.HTTPTimeout == 0 {
		cfg.HTTPTimeout = 30 * time.Second
	}

	httpClient := &http.Client{Timeout: cfg.HTTPTimeout}

	c := &chained{
		logger: logger.Named("ai.llm"),
	}

	if cfg.GroqAPIKey != "" {
		c.primary = &openAICompatible{
			name:    "groq",
			baseURL: strings.TrimRight(cfg.GroqBaseURL, "/"),
			apiKey:  cfg.GroqAPIKey,
			model:   cfg.GroqModel,
			http:    httpClient,
			logger:  logger.Named("ai.llm.groq"),
		}
	}

	c.fallback = &ollama{
		baseURL: strings.TrimRight(cfg.OllamaBaseURL, "/"),
		model:   cfg.OllamaModel,
		http:    httpClient,
		logger:  logger.Named("ai.llm.ollama"),
	}

	return c
}

// chained tries primary first; if Stream errors before yielding any content,
// falls back to fallback. Mid-stream errors are surfaced as-is.
type chained struct {
	primary  Client
	fallback Client
	used     string
	logger   *zap.Logger
}

func (c *chained) ProviderName() string { return c.used }

func (c *chained) Stream(ctx context.Context, req Request) (<-chan Token, error) {
	out := make(chan Token, 16)

	go func() {
		defer close(out)

		// Try primary, collecting up to first content token before committing.
		if c.primary != nil {
			ch, err := c.primary.Stream(ctx, req)
			if err == nil {
				yieldedContent := false
				for tok := range ch {
					if tok.Reason == "error" && !yieldedContent {
						// Pre-content failure: silently fall back.
						c.logger.Warn("primary failed before any content; falling back",
							zap.String("provider", c.primary.ProviderName()))
						break
					}
					if tok.Content != "" {
						yieldedContent = true
					}
					if yieldedContent || tok.Done {
						c.used = c.primary.ProviderName()
						out <- tok
					}
				}
				if yieldedContent {
					return
				}
			} else {
				c.logger.Warn("primary refused outright; falling back",
					zap.String("provider", c.primary.ProviderName()),
					zap.Error(err))
			}
		}

		ch, err := c.fallback.Stream(ctx, req)
		if err != nil {
			out <- Token{Done: true, Reason: "error", Content: fmt.Sprintf("fallback unavailable: %v", err)}
			return
		}
		c.used = c.fallback.ProviderName()
		for tok := range ch {
			out <- tok
		}
	}()

	return out, nil
}

// openAICompatible speaks the OpenAI Chat Completions API. Groq, vLLM,
// LM-Studio, and most other providers use the same wire format.
type openAICompatible struct {
	name    string
	baseURL string
	apiKey  string
	model   string
	http    *http.Client
	logger  *zap.Logger
}

func (p *openAICompatible) ProviderName() string { return p.name }

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

func (p *openAICompatible) Stream(ctx context.Context, req Request) (<-chan Token, error) {
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
		// Default scanner buf is 64 KiB; raise it for very wide tokens.
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

// ollama speaks Ollama's native /api/chat streaming protocol. Slightly
// different shape than OpenAI; per-line JSON, no `data:` prefix.
type ollama struct {
	baseURL string
	model   string
	http    *http.Client
	logger  *zap.Logger
}

func (o *ollama) ProviderName() string { return "ollama" }

type ollamaChatRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
	Stream   bool      `json:"stream"`
	Options  struct {
		Temperature float32  `json:"temperature,omitempty"`
		NumPredict  int      `json:"num_predict,omitempty"`
		Stop        []string `json:"stop,omitempty"`
	} `json:"options,omitempty"`
}

type ollamaChatChunk struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
	Done            bool   `json:"done"`
	DoneReason      string `json:"done_reason,omitempty"`
	PromptEvalCount int    `json:"prompt_eval_count,omitempty"`
	EvalCount       int    `json:"eval_count,omitempty"`
}

func (o *ollama) Stream(ctx context.Context, req Request) (<-chan Token, error) {
	r := ollamaChatRequest{
		Model:    o.model,
		Messages: req.Messages,
		Stream:   true,
	}
	r.Options.Temperature = req.Temperature
	r.Options.NumPredict = req.MaxTokens
	r.Options.Stop = req.StopSequences
	body, err := json.Marshal(r)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, o.baseURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := o.http.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ollama transport error: %w", err)
	}
	if resp.StatusCode >= 400 {
		buf, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		_ = resp.Body.Close()
		return nil, fmt.Errorf("ollama status %d: %s", resp.StatusCode, string(buf))
	}

	out := make(chan Token, 16)
	go func() {
		defer close(out)
		defer resp.Body.Close()

		dec := json.NewDecoder(resp.Body)
		var usage Usage
		var done bool
		var reason string

		for !done {
			var chunk ollamaChatChunk
			if err := dec.Decode(&chunk); err != nil {
				if errors.Is(err, io.EOF) {
					break
				}
				out <- Token{Done: true, Reason: "error", Content: err.Error(), Model: o.model}
				return
			}
			if chunk.Message.Content != "" {
				select {
				case out <- Token{Content: chunk.Message.Content, Model: o.model}:
				case <-ctx.Done():
					return
				}
			}
			if chunk.Done {
				done = true
				reason = nonEmpty(chunk.DoneReason, "stop")
				usage.PromptTokens = chunk.PromptEvalCount
				usage.CompletionTokens = chunk.EvalCount
				usage.TotalTokens = chunk.PromptEvalCount + chunk.EvalCount
			}
		}
		out <- Token{Done: true, Reason: reason, Model: o.model, Usage: usage}
	}()

	return out, nil
}

func nonEmpty(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}
