// Package message_summary implements the Catch-Me-Up AI feature: it pulls
// recent messages from a channel, compresses them, asks the LLM for a short
// bulleted summary with citations, and streams the bullets back to the user.
//
// Spec: missing-features/03-ai/ai-message-summary/{TRD,SCHEMA,IMPL}.md
package message_summary

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/flicko-org/flicko-backend/internal/services/ai/llm"
)

//go:embed prompts/summary.md
var systemPrompt string

// Service is the public entry point used by the HTTP handler.
type Service interface {
	// Request validates ACL + rate limit, kicks off generation in the
	// background, and returns the request envelope. The handler then
	// streams the bullets to the client via Stream.
	Request(ctx context.Context, in RequestInput) (*RequestResponse, error)

	// Stream returns a channel of events for an in-flight request_id. The
	// channel closes when the LLM stream finishes (or errors). Events
	// follow the SSE shape documented in the TRD.
	Stream(ctx context.Context, requestID, userID string) (<-chan Event, error)

	// Get returns the persisted summary by id (RLS already enforces owner).
	Get(ctx context.Context, id, userID string) (*models.AISummary, error)

	// Feedback records a thumbs-up/down rating.
	Feedback(ctx context.Context, summaryID, userID string, rating int16, reason *string) error

	// SummarizeChatDirect performs a direct/blocking summary of a custom list of messages.
	SummarizeChatDirect(ctx context.Context, messages []WindowMessage) (string, error)
}

// RequestInput is the validated payload from the HTTP handler.
type RequestInput struct {
	UserID    string
	ChannelID string
	ServerID  string
	SinceTS   time.Time
	// AnchorMsgID is the user's last-read pointer at request time, used
	// for cache key stability when the same window is fetched repeatedly.
	AnchorMsgID *string
}

// RequestResponse mirrors the REST envelope.
type RequestResponse struct {
	RequestID string `json:"request_id"`
	StreamURL string `json:"stream_url"`
	Cached    bool   `json:"cached"`
}

// Event is one SSE-style event published to the stream.
type Event struct {
	Type string         `json:"type"` // bullet | meta | done | error
	Data map[string]any `json:"data"`
}

// Config wires the service to its dependencies and tunes runtime behavior.
type Config struct {
	WindowMaxMessages int
	WindowMinMessages int
	MaxBullets        int
	LLMTimeout        time.Duration
	ModelName         string
}

// DefaultConfig returns sensible defaults aligned with the PRD/TRD.
func DefaultConfig() Config {
	return Config{
		WindowMaxMessages: 500,
		WindowMinMessages: 5,
		MaxBullets:        7,
		LLMTimeout:        12 * time.Second,
		ModelName:         "groq:llama-3.3-70b",
	}
}

type service struct {
	db        database.DatabaseClient
	repo      repo.AISummaryRepo
	cache     *CacheStore
	rateLimit *RateLimit
	llm       llm.Client
	cfg       Config
	logger    *zap.Logger

	// streams is an in-process map of request_id → event channel for
	// active generations. The handler subscribes via Stream(); when the
	// generator finishes it closes the channel and removes the key.
	streams streamRegistry
}

// New constructs a Service.
func New(
	db database.DatabaseClient,
	r repo.AISummaryRepo,
	c *CacheStore,
	rl *RateLimit,
	l llm.Client,
	cfg Config,
	logger *zap.Logger,
) Service {
	if logger == nil {
		logger = zap.NewNop()
	}
	if cfg.WindowMaxMessages == 0 {
		cfg = DefaultConfig()
	}
	return &service{
		db:        db,
		repo:      r,
		cache:     c,
		rateLimit: rl,
		llm:       l,
		cfg:       cfg,
		logger:    logger.Named("ai.message_summary"),
		streams:   newStreamRegistry(),
	}
}

// Errors surfaced to the handler.
var (
	ErrTooFewMessages = errors.New("not_enough_messages")
	ErrRateLimited    = errors.New("rate_limited")
	ErrACLDenied      = errors.New("acl_denied")
	ErrUnknownRequest = errors.New("unknown_request")
)

func (s *service) Request(ctx context.Context, in RequestInput) (*RequestResponse, error) {
	if err := s.checkChannelACL(ctx, in.UserID, in.ChannelID); err != nil {
		return nil, err
	}

	allowed, remaining, _ := s.rateLimit.Allow(ctx, in.UserID)
	if !allowed {
		s.logger.Info("ratelimit hit", zap.String("user", in.UserID))
		_ = remaining
		return nil, ErrRateLimited
	}

	now := time.Now().UTC()
	w, err := FetchWindow(ctx, s.db, in.ChannelID, in.ServerID, in.SinceTS, now, WindowOptions{
		MaxMessages: s.cfg.WindowMaxMessages,
		MinMessages: s.cfg.WindowMinMessages,
	})
	if err != nil {
		return nil, fmt.Errorf("fetch window: %w", err)
	}
	if len(w.Messages) < s.cfg.WindowMinMessages {
		return nil, ErrTooFewMessages
	}
	w.AnchorMsgID = in.AnchorMsgID

	requestID := uuid.NewString()
	cacheKey := CacheKey(in.ChannelID, w.AnchorMsgID, w.LatestMsgID, s.cfg.ModelName)

	row := &models.AISummary{
		ID:           uuid.NewString(),
		RequestID:    requestID,
		ServerID:     in.ServerID,
		ChannelID:    in.ChannelID,
		RequestedBy:  in.UserID,
		AnchorMsgID:  w.AnchorMsgID,
		LatestMsgID:  w.LatestMsgID,
		WindowStart:  w.Start,
		WindowEnd:    w.End,
		MessageCount: len(w.Messages),
		Participants: w.Participants,
		Outcome:      models.SummaryPending,
		ModelUsed:    s.cfg.ModelName,
		CacheKey:     cacheKey,
	}
	if err := s.repo.Insert(ctx, row); err != nil {
		s.logger.Error("insert ai_summary", zap.Error(err))
		return nil, err
	}

	stream := s.streams.create(requestID)

	// Cache hit fast-path: replay cached bullets and finalize immediately.
	if cached, err := s.cache.Get(ctx, cacheKey); err == nil && cached != nil {
		go s.replayCached(context.WithoutCancel(ctx), row, w, cached, stream)
		return &RequestResponse{
			RequestID: requestID,
			StreamURL: "/api/v1/ai/summary/stream/" + requestID,
			Cached:    true,
		}, nil
	}

	go s.generate(context.WithoutCancel(ctx), row, w, stream)

	return &RequestResponse{
		RequestID: requestID,
		StreamURL: "/api/v1/ai/summary/stream/" + requestID,
		Cached:    false,
	}, nil
}

func (s *service) Stream(ctx context.Context, requestID, userID string) (<-chan Event, error) {
	ch, ok := s.streams.subscribe(requestID, userID)
	if !ok {
		return nil, ErrUnknownRequest
	}
	return ch, nil
}

func (s *service) Get(ctx context.Context, id, userID string) (*models.AISummary, error) {
	return s.repo.GetByID(ctx, id, userID)
}

func (s *service) Feedback(ctx context.Context, summaryID, userID string, rating int16, reason *string) error {
	return s.repo.UpsertFeedback(ctx, &models.SummaryFeedback{
		ID:        uuid.NewString(),
		SummaryID: summaryID,
		UserID:    userID,
		Rating:    rating,
		Reason:    reason,
	})
}

// checkChannelACL verifies the user is a member of the channel's server with
// at least basic read access. We deliberately re-check at request time even
// if the client knows the channel id — perms can change.
func (s *service) checkChannelACL(ctx context.Context, userID, channelID string) error {
	const q = `
		SELECT 1
		  FROM public.channels c
		  JOIN public.server_members sm ON sm.server_id = c.server_id
		 WHERE c.id = $1
		   AND sm.user_id = $2
		 LIMIT 1
	`
	row := s.db.QueryRow(ctx, q, channelID, userID)
	var ok int
	if err := row.Scan(&ok); err != nil {
		return ErrACLDenied
	}
	return nil
}

// generate runs the live LLM path. It updates the persisted row at the end
// and pushes Events to the per-request channel.
func (s *service) generate(ctx context.Context, row *models.AISummary, w *Window, ch *streamChannel) {
	defer ch.close()

	startedAt := time.Now()
	ctx, cancel := context.WithTimeout(ctx, s.cfg.LLMTimeout)
	defer cancel()

	cr := Compress(w.Messages, DefaultCompressOptions())
	transcript := Render(cr.Messages)

	user := "Channel transcript follows. Produce the bullet summary as instructed.\n\n" + transcript
	stream, err := s.llm.Stream(ctx, llm.Request{
		Messages: []llm.Message{
			{Role: llm.RoleSystem, Content: systemPrompt},
			{Role: llm.RoleUser, Content: user},
		},
		Temperature: 0.2,
		MaxTokens:   400,
	})
	if err != nil {
		s.finalizeError(ctx, row, ch, "llm_unavailable", err)
		return
	}

	var (
		raw        strings.Builder
		ttfb       *int
		tokensIn   *int
		tokensOut  *int
		modelUsed  = row.ModelUsed
		gotContent bool
	)

	for tok := range stream {
		if tok.Done {
			if tok.Reason == "error" {
				s.finalizeError(ctx, row, ch, "llm_error", errors.New(tok.Content))
				return
			}
			tokensIn = ptrInt(tok.Usage.PromptTokens)
			tokensOut = ptrInt(tok.Usage.CompletionTokens)
			if tok.Model != "" {
				modelUsed = tok.Model
			}
			break
		}
		if !gotContent {
			ms := int(time.Since(startedAt).Milliseconds())
			ttfb = &ms
			gotContent = true
		}
		raw.WriteString(tok.Content)
		// Bullet streaming: when we cross a newline, parse what we have
		// so far and emit the latest complete bullet as it arrives.
		s.emitProgress(ch, raw.String(), w.Messages)
	}

	bullets := Parse(raw.String(), w.Messages)
	if len(bullets) == 0 {
		s.finalizeError(ctx, row, ch, "no_bullets_parsed", errors.New("model produced no bullets"))
		return
	}
	if len(bullets) > s.cfg.MaxBullets {
		bullets = bullets[:s.cfg.MaxBullets]
	}

	sentiment := extractSentiment(raw.String())
	parts := ResolveParticipants(bullets, w.Messages)

	// Persist and cache.
	totalMs := int(time.Since(startedAt).Milliseconds())
	finalize := repo.FinalizePatch{
		Bullets:      bullets,
		Participants: parts,
		Sentiment:    sentiment,
		ModelUsed:    modelUsed,
		TokensIn:     tokensIn,
		TokensOut:    tokensOut,
		TTFBMs:       ttfb,
		TotalMs:      &totalMs,
		Outcome:      models.SummaryDone,
	}
	if err := s.repo.Finalize(ctx, row.ID, finalize); err != nil {
		s.logger.Warn("finalize summary", zap.Error(err))
	}
	_ = s.cache.Set(ctx, row.CacheKey, CachedSummary{
		Bullets:      bullets,
		Participants: parts,
		Sentiment:    safeStr(sentiment),
		Model:        modelUsed,
		TokensIn:     deref(tokensIn),
		TokensOut:    deref(tokensOut),
	})

	// Final SSE shape. Send any bullets the streaming path didn't emit yet
	// (defensive), then meta + done.
	for _, b := range bullets {
		ch.publish(Event{Type: "bullet", Data: map[string]any{
			"index":     b.Index,
			"text":      b.Text,
			"citations": b.Citations,
		}})
	}
	ch.publish(Event{Type: "meta", Data: map[string]any{
		"participants":  parts,
		"sentiment":     safeStr(sentiment),
		"message_count": len(w.Messages),
		"window_start":  w.Start,
		"window_end":    w.End,
	}})
	ch.publish(Event{Type: "done", Data: map[string]any{
		"summary_id": row.ID,
		"tokens_in":  deref(tokensIn),
		"tokens_out": deref(tokensOut),
		"model":      modelUsed,
	}})
}

func (s *service) replayCached(ctx context.Context, row *models.AISummary, w *Window, cached *CachedSummary, ch *streamChannel) {
	defer ch.close()

	for _, b := range cached.Bullets {
		ch.publish(Event{Type: "bullet", Data: map[string]any{
			"index":     b.Index,
			"text":      b.Text,
			"citations": b.Citations,
		}})
	}
	ch.publish(Event{Type: "meta", Data: map[string]any{
		"participants":  cached.Participants,
		"sentiment":     cached.Sentiment,
		"message_count": len(w.Messages),
		"window_start":  w.Start,
		"window_end":    w.End,
	}})
	zero := 0
	finalize := repo.FinalizePatch{
		Bullets:      cached.Bullets,
		Participants: cached.Participants,
		Sentiment:    optStr(cached.Sentiment),
		ModelUsed:    cached.Model,
		TokensIn:     &zero,
		TokensOut:    &zero,
		Outcome:      models.SummaryDone,
		CachedHit:    true,
	}
	if err := s.repo.Finalize(ctx, row.ID, finalize); err != nil {
		s.logger.Warn("finalize cached", zap.Error(err))
	}
	ch.publish(Event{Type: "done", Data: map[string]any{
		"summary_id": row.ID,
		"tokens_in":  0,
		"tokens_out": 0,
		"model":      cached.Model,
		"cached":     true,
	}})
}

func (s *service) finalizeError(ctx context.Context, row *models.AISummary, ch *streamChannel, code string, err error) {
	s.logger.Warn("summary error", zap.String("code", code), zap.Error(err))
	reason := code
	patch := repo.FinalizePatch{
		Outcome:       models.SummaryError,
		RefusalReason: &reason,
	}
	if e := s.repo.Finalize(ctx, row.ID, patch); e != nil {
		s.logger.Warn("finalize error row", zap.Error(e))
	}
	ch.publish(Event{Type: "error", Data: map[string]any{"code": code, "message": err.Error()}})
}

// emitProgress pushes a "bullet" event the first time we see a complete
// bullet line. Idempotent: it tracks how many bullets it has already sent
// per stream channel via channel-side state.
func (s *service) emitProgress(ch *streamChannel, raw string, window []WindowMessage) {
	bullets := Parse(raw, window)
	already := ch.publishedBullets()
	for i := already; i < len(bullets); i++ {
		// Skip the trailing in-progress bullet — we only emit completed ones,
		// detected by trailing newline in raw.
		if i == len(bullets)-1 && !strings.HasSuffix(raw, "\n") {
			break
		}
		ch.publish(Event{Type: "bullet", Data: map[string]any{
			"index":     bullets[i].Index,
			"text":      bullets[i].Text,
			"citations": bullets[i].Citations,
		}})
		ch.markBulletPublished()
	}
}

// extractSentiment pulls the META: line emitted by the prompt. Returns nil
// when the model omitted it or used an unexpected value.
func extractSentiment(raw string) *string {
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		const pfx = "META: sentiment="
		if strings.HasPrefix(line, pfx) {
			v := strings.TrimSpace(strings.TrimPrefix(line, pfx))
			switch v {
			case "positive", "focused", "mixed", "tense":
				return &v
			}
		}
	}
	return nil
}

func ptrInt(i int) *int       { return &i }
func deref(p *int) int        { if p == nil { return 0 }; return *p }
func safeStr(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
func optStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (s *service) SummarizeChatDirect(ctx context.Context, messages []WindowMessage) (string, error) {
	if len(messages) == 0 {
		return "", errors.New("no messages to summarize")
	}

	var chatBuilder strings.Builder
	for _, m := range messages {
		chatBuilder.WriteString(fmt.Sprintf("%s: %s\n", m.Author, m.Content))
	}

	const dmSystemPrompt = `You are Aura, an AI summarization assistant inside the Flicko messaging app.
Summarize the following chat conversation into a concise bulleted list. Focus on key decisions, questions raised, and main topics.
Be conversational but highly structured and brief. Use markdown bullet points. Return only the summary text.`

	stream, err := s.llm.Stream(ctx, llm.Request{
		Messages: []llm.Message{
			{Role: llm.RoleSystem, Content: dmSystemPrompt},
			{Role: llm.RoleUser, Content: "Chat history:\n" + chatBuilder.String()},
		},
		Temperature: 0.3,
		MaxTokens:   512,
	})
	if err != nil {
		return "", fmt.Errorf("llm stream: %w", err)
	}

	var sb strings.Builder
	for tok := range stream {
		if tok.Done {
			if tok.Reason == "error" {
				return "", fmt.Errorf("llm generation error: %s", tok.Content)
			}
			break
		}
		sb.WriteString(tok.Content)
	}

	return sb.String(), nil
}
