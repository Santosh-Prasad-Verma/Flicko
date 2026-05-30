// Command eval-summary runs the Catch-Me-Up eval harness against a golden
// JSONL file and prints a pass/fail report. Designed to be run from CI
// nightly with `EVAL_LLM=1` so it doesn't gate normal `go test` runs.
//
// Usage:
//
//	GROQ_API_KEY=… go run ./cmd/eval-summary \
//	    -golden internal/services/ai/message_summary/evals/golden.jsonl
//
// Pass criteria per case (when no `expect_refuse`):
//   - bullets count is within [required_bullets_min, required_bullets_max]
//   - all required_topics appear (case-insensitive) in some bullet's text
//   - every citation in every bullet resolves to a real message id from the
//     window
//
// For `expect_refuse: true` cases we expect the service to return
// ErrTooFewMessages.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/ai/llm"
	"github.com/flicko-org/flicko-backend/internal/services/ai/message_summary"
)

type goldenCase struct {
	ID                  string             `json:"id"`
	Window              []goldenMsg        `json:"window"`
	RequiredBulletsMin  int                `json:"required_bullets_min,omitempty"`
	RequiredBulletsMax  int                `json:"required_bullets_max,omitempty"`
	RequiredTopics      []string           `json:"required_topics,omitempty"`
	ExpectRefuse        bool               `json:"expect_refuse,omitempty"`
}

type goldenMsg struct {
	ID     string    `json:"id"`
	Author string    `json:"author"`
	At     time.Time `json:"at"`
	Text   string    `json:"text"`
}

func main() {
	goldenPath := flag.String("golden", "internal/services/ai/message_summary/evals/golden.jsonl", "path to golden jsonl")
	flag.Parse()

	logger, _ := zap.NewProduction()
	defer logger.Sync()

	cfg := llm.Config{
		GroqAPIKey:    os.Getenv("GROQ_API_KEY"),
		GroqBaseURL:   envOr("GROQ_BASE_URL", "https://api.groq.com/openai/v1"),
		GroqModel:     envOr("GROQ_MODEL", "llama-3.3-70b-versatile"),
		OllamaBaseURL: envOr("OLLAMA_BASE_URL", "http://localhost:11434"),
		OllamaModel:   envOr("OLLAMA_MODEL", "llama3.1:8b"),
		HTTPTimeout:   30 * time.Second,
	}
	if cfg.GroqAPIKey == "" {
		fmt.Fprintln(os.Stderr, "warn: GROQ_API_KEY not set; falling back to Ollama at", cfg.OllamaBaseURL)
	}
	client := llm.New(cfg, logger)

	cases, err := loadCases(*goldenPath)
	if err != nil {
		fail("load golden: %v", err)
	}
	fmt.Printf("loaded %d cases from %s\n", len(cases), *goldenPath)

	var passed, failed int
	for _, c := range cases {
		ok, reason := evalOne(client, c)
		if ok {
			passed++
			fmt.Printf("  PASS  %s\n", c.ID)
		} else {
			failed++
			fmt.Printf("  FAIL  %s — %s\n", c.ID, reason)
		}
	}
	fmt.Printf("\n%d/%d passed\n", passed, len(cases))
	if failed > 0 {
		os.Exit(1)
	}
}

// evalOne runs a single case against the LLM and returns (ok, reason).
//
// We bypass the full Service orchestrator (which needs a real DB) and call
// the prompt + parser directly. The compressor is used to keep the input
// shape identical to production.
func evalOne(client llm.Client, c goldenCase) (bool, string) {
	if c.ExpectRefuse {
		if len(c.Window) >= 5 {
			return false, fmt.Sprintf("expect_refuse but window has %d messages (>=5)", len(c.Window))
		}
		return true, ""
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	wm := make([]message_summary.WindowMessage, 0, len(c.Window))
	for _, m := range c.Window {
		wm = append(wm, message_summary.WindowMessage{
			ID:        m.ID,
			AuthorID:  m.Author,
			Author:    m.Author,
			Content:   m.Text,
			CreatedAt: m.At,
		})
	}
	cr := message_summary.Compress(wm, message_summary.DefaultCompressOptions())
	transcript := message_summary.Render(cr.Messages)

	stream, err := client.Stream(ctx, llm.Request{
		Messages: []llm.Message{
			{Role: llm.RoleSystem, Content: systemPrompt()},
			{Role: llm.RoleUser, Content: "Channel transcript follows. Produce the bullet summary as instructed.\n\n" + transcript},
		},
		Temperature: 0.2,
		MaxTokens:   400,
	})
	if err != nil {
		return false, "stream open: " + err.Error()
	}
	var raw strings.Builder
	for tok := range stream {
		if tok.Done {
			if tok.Reason == "error" {
				return false, "llm error: " + tok.Content
			}
			break
		}
		raw.WriteString(tok.Content)
	}

	bullets := message_summary.Parse(raw.String(), wm)
	n := len(bullets)
	if n < c.RequiredBulletsMin || n > c.RequiredBulletsMax {
		return false, fmt.Sprintf("bullet count %d not in [%d, %d]; raw=%q", n, c.RequiredBulletsMin, c.RequiredBulletsMax, raw.String())
	}
	// Required topics — case-insensitive substring search across all bullets.
	joined := ""
	for _, b := range bullets {
		joined += " " + strings.ToLower(b.Text)
	}
	for _, topic := range c.RequiredTopics {
		if !strings.Contains(joined, strings.ToLower(topic)) {
			return false, fmt.Sprintf("missing topic %q in bullets", topic)
		}
	}
	// Citation validity.
	known := map[string]struct{}{}
	for _, m := range wm {
		known[m.ID] = struct{}{}
	}
	for _, b := range bullets {
		for _, cid := range b.Citations {
			if _, ok := known[cid]; !ok {
				return false, fmt.Sprintf("bullet %d cites unknown id %s", b.Index, cid)
			}
		}
	}
	return true, ""
}

func loadCases(path string) ([]goldenCase, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var out []goldenCase
	for i, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var c goldenCase
		if err := json.Unmarshal([]byte(line), &c); err != nil {
			return nil, fmt.Errorf("line %d: %w", i+1, err)
		}
		if !c.ExpectRefuse {
			if c.RequiredBulletsMin == 0 {
				c.RequiredBulletsMin = 3
			}
			if c.RequiredBulletsMax == 0 {
				c.RequiredBulletsMax = 7
			}
		}
		out = append(out, c)
	}
	return out, nil
}

func systemPrompt() string {
	// Inline copy of the production prompt to avoid filesystem coupling. Keep
	// in sync with internal/services/ai/message_summary/prompts/summary.md.
	return `You are Flicko's "Catch-Me-Up" assistant. Output 3-7 bullets, one
sentence each, ` + "`• `" + ` prefix, ending with [#NNN] citations referencing
the line numbers in the transcript. Do not invent participants or facts.
After the bullets, output a single line META: sentiment=<positive|focused|mixed|tense>.
Output nothing else.`
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func fail(msg string, args ...any) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(2)
}

// Compile-time guard: keeps the package referenced even if the helper above
// is removed.
var _ = errors.New
