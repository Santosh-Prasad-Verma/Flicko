// Package moderation runs an AI classifier (Llama-Guard via Groq, with an
// Ollama fallback) over messages before they're published. It returns a
// per-category score, a decision (clean / review / blocked), and persists a
// signal row for audit + analytics.
//
// Spec: missing-features/03-ai/ai-moderation/{TRD,SCHEMA,IMPL}.md
package moderation

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/services/ai/llm"
)

//go:embed prompts/classify.md
var classifyPrompt string

// Categories we score. Keep stable — they're the JSON keys persisted on
// mod_signals.scores and the column keys in mod_thresholds.
const (
	CategoryHate       = "hate"
	CategoryHarassment = "harassment"
	CategorySexual     = "sexual"
	CategorySelfHarm   = "self_harm"
	CategoryViolence   = "violence"
)

var allCategories = []string{
	CategoryHate, CategoryHarassment, CategorySexual, CategorySelfHarm, CategoryViolence,
}

// Decision is the public verdict that flows back to the message handler.
type Decision string

const (
	DecisionClean   Decision = "clean"
	DecisionReview  Decision = "review"
	DecisionBlocked Decision = "blocked"
)

// Result is what the service returns to callers.
type Result struct {
	SignalID  string             `json:"signal_id"`
	Decision  Decision           `json:"decision"`
	Scores    map[string]float64 `json:"scores"`
	TopCat    string             `json:"top_category,omitempty"`
	TopScore  float64            `json:"top_score,omitempty"`
	Reason    string             `json:"reason,omitempty"`
	LatencyMs int                `json:"latency_ms"`
}

// CheckInput bundles everything the classifier needs.
type CheckInput struct {
	UserID    string
	ServerID  string
	ChannelID string
	MessageID string // optional; provided when re-checking an edit
	Text      string
}

// Service is the public interface used by the message handler + moderation
// REST endpoints.
type Service interface {
	// Check classifies a message and writes a mod_signals row. If the
	// decision is "review" or "blocked" the caller is responsible for
	// blocking publish or enqueuing the message in the mod queue (we
	// expose helpers for both).
	Check(ctx context.Context, in CheckInput) (Result, error)

	// EnqueueReview adds a message to the mod queue for human review. The
	// plaintext is persisted on the queue row only and purged on resolve.
	EnqueueReview(ctx context.Context, signalID, serverID, plainText string) error

	// Decide finalizes a queue item. action="approved" lets the message
	// through; action="denied" leaves it blocked and clears the plaintext.
	Decide(ctx context.Context, queueID, modID string, action string) error

	// Appeal lets the offending user request a human review of a `blocked`
	// signal. Capped per user per day.
	Appeal(ctx context.Context, signalID, userID, reason string) error

	// GetThresholds returns per-server thresholds, falling back to defaults.
	GetThresholds(ctx context.Context, serverID string) (Thresholds, error)

	// SetThresholds upserts per-server thresholds. Caller has already
	// validated MANAGE_SERVER permission.
	SetThresholds(ctx context.Context, serverID string, t Thresholds) error
}

// Thresholds carries the block/review cutoffs per category.
type Thresholds struct {
	Block  map[string]float64 `json:"block"`
	Review map[string]float64 `json:"review"`
}

// DefaultThresholds returns the conservative initial cutoffs from the PRD.
//
// Block ≥ 0.95 (we're confident enough to refuse the send). Review ≥ 0.70
// (borderline; show in mod queue but don't refuse).
func DefaultThresholds() Thresholds {
	return Thresholds{
		Block: map[string]float64{
			CategoryHate:       0.92,
			CategoryHarassment: 0.95,
			CategorySexual:     0.97,
			CategorySelfHarm:   0.85,
			CategoryViolence:   0.93,
		},
		Review: map[string]float64{
			CategoryHate:       0.65,
			CategoryHarassment: 0.70,
			CategorySexual:     0.80,
			CategorySelfHarm:   0.55,
			CategoryViolence:   0.70,
		},
	}
}

// Config wires the service to its dependencies.
type Config struct {
	ClassifierName    string // for audit ("groq:llama-guard"|"ollama:llama-guard")
	ClassifierVersion string
	LLMTimeout        time.Duration
	AppealsPerDayCap  int
}

// DefaultConfig returns sensible defaults.
func DefaultConfig() Config {
	return Config{
		ClassifierName:    "groq:llama-3.1-8b-instant",
		ClassifierVersion: "v1",
		LLMTimeout:        4 * time.Second,
		AppealsPerDayCap:  3,
	}
}

type service struct {
	db     database.DatabaseClient
	cache  cache.CacheLayer
	llm    llm.Client
	cfg    Config
	logger *zap.Logger
}

// New constructs a Service.
func New(
	db database.DatabaseClient,
	c cache.CacheLayer,
	l llm.Client,
	cfg Config,
	logger *zap.Logger,
) Service {
	if logger == nil {
		logger = zap.NewNop()
	}
	if cfg.ClassifierName == "" {
		cfg = DefaultConfig()
	}
	return &service{
		db:     db,
		cache:  c,
		llm:    l,
		cfg:    cfg,
		logger: logger.Named("ai.moderation"),
	}
}

var (
	// ErrTextEmpty is returned when there's nothing to classify.
	ErrTextEmpty = errors.New("text empty")
	// ErrAppealCapped is returned when the user has hit AppealsPerDayCap.
	ErrAppealCapped = errors.New("appeal_capped")
	// ErrUnknownQueueItem when Decide can't find the row.
	ErrUnknownQueueItem = errors.New("unknown_queue_item")
)

// Check is the hot path: short text trim, cache lookup, LLM scoring, persist.
func (s *service) Check(ctx context.Context, in CheckInput) (Result, error) {
	if strings.TrimSpace(in.Text) == "" {
		return Result{}, ErrTextEmpty
	}

	textHash := hash(in.Text)

	// Fast accept: text was previously approved by a mod within the last 30d.
	if s.cache != nil {
		if v, _ := s.cache.Get(ctx, "aimod:safe:"+textHash); v == "1" {
			return Result{
				Decision: DecisionClean,
				Scores:   zeroScores(),
				Reason:   "previously_approved",
			}, nil
		}
	}

	thr, err := s.GetThresholds(ctx, in.ServerID)
	if err != nil {
		return Result{}, fmt.Errorf("thresholds: %w", err)
	}

	startedAt := time.Now()
	scores, err := s.classify(ctx, in.Text)
	latencyMs := int(time.Since(startedAt).Milliseconds())
	if err != nil {
		// Fail-open: classifier outage shouldn't take chat down. Emit a
		// `clean` result with the error reason so callers can log it; the
		// existing keyword-based automod still runs upstream.
		s.logger.Warn("classifier failed, failing open", zap.Error(err))
		return Result{
			Decision:  DecisionClean,
			Scores:    zeroScores(),
			Reason:    "classifier_unavailable",
			LatencyMs: latencyMs,
		}, nil
	}

	decision, topCat, topScore := decide(scores, thr)
	signalID := uuid.NewString()
	if err := s.persistSignal(ctx, signalID, in, textHash, scores, decision, latencyMs); err != nil {
		s.logger.Warn("persist mod_signals", zap.Error(err))
	}

	return Result{
		SignalID:  signalID,
		Decision:  decision,
		Scores:    scores,
		TopCat:    topCat,
		TopScore:  topScore,
		LatencyMs: latencyMs,
	}, nil
}

func (s *service) EnqueueReview(ctx context.Context, signalID, serverID, plainText string) error {
	const q = `
		INSERT INTO public.mod_queue_items (id, signal_id, server_id, text_plain)
		VALUES ($1, $2, $3, $4)
	`
	_, err := s.db.Exec(ctx, q, uuid.NewString(), signalID, serverID, plainText)
	return err
}

func (s *service) Decide(ctx context.Context, queueID, modID, action string) error {
	switch action {
	case "approved", "denied":
	default:
		return errors.New("invalid action")
	}
	const q = `
		UPDATE public.mod_queue_items
		   SET status      = $1,
		       decided_by  = $2,
		       decided_at  = now(),
		       text_plain  = NULL
		 WHERE id = $3
		   AND status = 'open'
		RETURNING signal_id
	`
	row := s.db.QueryRow(ctx, q, action, modID, queueID)
	var signalID string
	if err := row.Scan(&signalID); err != nil {
		return ErrUnknownQueueItem
	}
	if action == "approved" && s.cache != nil {
		// Cache the approved hash so identical sends skip the classifier.
		var sigText string
		if err := s.db.QueryRow(ctx,
			`SELECT text_hash FROM public.mod_signals WHERE id=$1`, signalID,
		).Scan(&sigText); err == nil && sigText != "" {
			_ = s.cache.Set(ctx, "aimod:safe:"+sigText, "1", 30*24*time.Hour)
		}
	}
	return nil
}

func (s *service) Appeal(ctx context.Context, signalID, userID, reason string) error {
	// Cap to N per day per user via Postgres count — simpler than Redis here
	// because volume is low.
	var dayCount int
	_ = s.db.QueryRow(ctx, `
		SELECT COUNT(*)
		  FROM public.mod_appeals
		 WHERE user_id = $1
		   AND created_at > now() - interval '24 hours'
	`, userID).Scan(&dayCount)
	if dayCount >= s.cfg.AppealsPerDayCap {
		return ErrAppealCapped
	}
	const q = `
		INSERT INTO public.mod_appeals (id, signal_id, user_id, reason)
		VALUES ($1, $2, $3, NULLIF($4, ''))
	`
	_, err := s.db.Exec(ctx, q, uuid.NewString(), signalID, userID, reason)
	return err
}

func (s *service) GetThresholds(ctx context.Context, serverID string) (Thresholds, error) {
	out := DefaultThresholds()
	if serverID == "" || s.db == nil {
		return out, nil
	}
	rows, err := s.db.Query(ctx,
		`SELECT category, block_th, review_th FROM public.mod_thresholds WHERE server_id=$1`,
		serverID,
	)
	if err != nil {
		return out, nil
	}
	defer rows.Close()
	for rows.Next() {
		var (
			cat   string
			block float64
			rev   float64
		)
		if err := rows.Scan(&cat, &block, &rev); err == nil {
			out.Block[cat] = block
			out.Review[cat] = rev
		}
	}
	return out, nil
}

func (s *service) SetThresholds(ctx context.Context, serverID string, t Thresholds) error {
	for _, cat := range allCategories {
		block, ok := t.Block[cat]
		if !ok {
			continue
		}
		review := t.Review[cat]
		if review > block {
			return fmt.Errorf("review threshold > block for category %q", cat)
		}
		if _, err := s.db.Exec(ctx, `
			INSERT INTO public.mod_thresholds (server_id, category, block_th, review_th)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (server_id, category)
			DO UPDATE SET block_th = EXCLUDED.block_th, review_th = EXCLUDED.review_th
		`, serverID, cat, block, review); err != nil {
			return err
		}
	}
	return nil
}

// --- internals ---

func (s *service) persistSignal(
	ctx context.Context,
	signalID string,
	in CheckInput,
	textHash string,
	scores map[string]float64,
	decision Decision,
	latencyMs int,
) error {
	scoresJSON := scoresToJSON(scores)
	const q = `
		INSERT INTO public.mod_signals
		  (id, message_id, user_id, server_id, channel_id, text_hash,
		   scores, decision, classifier, classifier_v, latency_ms)
		VALUES (
		  $1,
		  NULLIF($2, '')::uuid,
		  $3,
		  NULLIF($4, '')::uuid,
		  NULLIF($5, '')::uuid,
		  $6, $7::jsonb, $8, $9, $10, $11
		)
	`
	_, err := s.db.Exec(ctx, q,
		signalID, in.MessageID, in.UserID, in.ServerID, in.ChannelID,
		textHash, scoresJSON, string(decision), s.cfg.ClassifierName, s.cfg.ClassifierVersion, latencyMs,
	)
	return err
}

func (s *service) classify(ctx context.Context, text string) (map[string]float64, error) {
	ctx, cancel := context.WithTimeout(ctx, s.cfg.LLMTimeout)
	defer cancel()

	prompt := strings.ReplaceAll(classifyPrompt, "{{TEXT}}", text)
	stream, err := s.llm.Stream(ctx, llm.Request{
		Messages:    []llm.Message{{Role: llm.RoleUser, Content: prompt}},
		Temperature: 0.0,
		MaxTokens:   80,
	})
	if err != nil {
		return nil, err
	}
	var raw strings.Builder
	for tok := range stream {
		if tok.Done {
			if tok.Reason == "error" {
				return nil, errors.New(tok.Content)
			}
			break
		}
		raw.WriteString(tok.Content)
	}
	return parseScores(raw.String())
}

// parseScores extracts S1..S5 lines from the LLM output. Each line is
// `S<n>: <prob>` where prob is in [0,1]. Missing categories default to 0.
func parseScores(raw string) (map[string]float64, error) {
	scores := zeroScores()
	mapping := map[string]string{
		"S1": CategoryHate,
		"S2": CategoryHarassment,
		"S3": CategorySexual,
		"S4": CategorySelfHarm,
		"S5": CategoryViolence,
	}
	saw := 0
	re := regexp.MustCompile(`(?m)^\s*(S[1-5])\s*[:=]\s*([01]?\.?\d+)\s*$`)
	for _, m := range re.FindAllStringSubmatch(raw, -1) {
		cat, ok := mapping[m[1]]
		if !ok {
			continue
		}
		v, err := strconv.ParseFloat(m[2], 64)
		if err != nil {
			continue
		}
		if v < 0 {
			v = 0
		}
		if v > 1 {
			v = 1
		}
		scores[cat] = v
		saw++
	}
	if saw == 0 {
		return nil, fmt.Errorf("classifier output unparseable: %q", trim(raw, 200))
	}
	return scores, nil
}

func decide(scores map[string]float64, thr Thresholds) (Decision, string, float64) {
	var (
		topCat   string
		topScore float64
	)
	for _, cat := range allCategories {
		s := scores[cat]
		if s > topScore {
			topCat, topScore = cat, s
		}
		if s >= thr.Block[cat] {
			return DecisionBlocked, cat, s
		}
	}
	for _, cat := range allCategories {
		if scores[cat] >= thr.Review[cat] {
			return DecisionReview, cat, scores[cat]
		}
	}
	return DecisionClean, topCat, topScore
}

func zeroScores() map[string]float64 {
	out := make(map[string]float64, len(allCategories))
	for _, c := range allCategories {
		out[c] = 0
	}
	return out
}

func scoresToJSON(s map[string]float64) string {
	var b strings.Builder
	b.WriteByte('{')
	first := true
	for _, c := range allCategories {
		if !first {
			b.WriteByte(',')
		}
		first = false
		fmt.Fprintf(&b, "%q:%g", c, s[c])
	}
	b.WriteByte('}')
	return b.String()
}

func hash(text string) string {
	canon := strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
	// Cheap SHA-like distinguisher; for the same text + same algo we always
	// get the same key. We don't need cryptographic strength here — just a
	// stable, low-collision id.
	return fmt.Sprintf("%x", fnv64a(strings.ToLower(canon)))
}

func fnv64a(s string) uint64 {
	const (
		offset uint64 = 14695981039346656037
		prime  uint64 = 1099511628211
	)
	h := offset
	for i := 0; i < len(s); i++ {
		h ^= uint64(s[i])
		h *= prime
	}
	return h
}

func trim(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "…"
}
