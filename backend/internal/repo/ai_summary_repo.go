package repo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

// AISummaryRepo persists ai_summaries / ai_summary_feedback rows.
type AISummaryRepo interface {
	Insert(ctx context.Context, s *models.AISummary) error
	Finalize(ctx context.Context, id string, patch FinalizePatch) error
	GetByID(ctx context.Context, id, requesterID string) (*models.AISummary, error)
	GetByRequestID(ctx context.Context, requestID, requesterID string) (*models.AISummary, error)
	UpsertFeedback(ctx context.Context, f *models.SummaryFeedback) error
}

// FinalizePatch carries the fields written when a streaming summary completes.
type FinalizePatch struct {
	Bullets       []models.SummaryBullet
	Participants  []string
	Sentiment     *string
	ModelUsed     string
	TokensIn      *int
	TokensOut     *int
	TTFBMs        *int
	TotalMs       *int
	Outcome       models.SummaryOutcome
	RefusalReason *string
	CachedHit     bool
}

type aiSummaryRepo struct {
	db database.DatabaseClient
}

// NewAISummaryRepo wires a repo backed by the standard DB client.
func NewAISummaryRepo(db database.DatabaseClient) AISummaryRepo {
	return &aiSummaryRepo{db: db}
}

func (r *aiSummaryRepo) Insert(ctx context.Context, s *models.AISummary) error {
	bullets, err := s.EncodeBullets()
	if err != nil {
		return fmt.Errorf("encode bullets: %w", err)
	}

	const q = `
		INSERT INTO public.ai_summaries (
			id, request_id, server_id, channel_id, requested_by,
			anchor_msg_id, latest_msg_id, window_start, window_end,
			message_count, bullets, participants, sentiment, model_used,
			outcome, cache_key, cached_hit, created_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9,
			$10, $11::jsonb, $12, $13, $14, $15, $16, $17, $18
		)
	`
	if s.CreatedAt.IsZero() {
		s.CreatedAt = time.Now().UTC()
	}
	if s.Outcome == "" {
		s.Outcome = models.SummaryPending
	}
	if s.Participants == nil {
		s.Participants = []string{}
	}

	_, err = r.db.Exec(ctx, q,
		s.ID, s.RequestID, s.ServerID, s.ChannelID, s.RequestedBy,
		s.AnchorMsgID, s.LatestMsgID, s.WindowStart, s.WindowEnd,
		s.MessageCount, string(bullets), s.Participants, s.Sentiment, s.ModelUsed,
		string(s.Outcome), s.CacheKey, s.CachedHit, s.CreatedAt,
	)
	return err
}

func (r *aiSummaryRepo) Finalize(ctx context.Context, id string, patch FinalizePatch) error {
	bullets, err := (&models.AISummary{Bullets: patch.Bullets}).EncodeBullets()
	if err != nil {
		return fmt.Errorf("encode bullets: %w", err)
	}
	if patch.Participants == nil {
		patch.Participants = []string{}
	}

	const q = `
		UPDATE public.ai_summaries
		   SET bullets        = $1::jsonb,
		       participants   = $2,
		       sentiment      = $3,
		       model_used     = COALESCE(NULLIF($4, ''), model_used),
		       tokens_in      = $5,
		       tokens_out     = $6,
		       ttfb_ms        = $7,
		       total_ms       = $8,
		       outcome        = $9,
		       refusal_reason = $10,
		       cached_hit     = $11,
		       finished_at    = now()
		 WHERE id = $12
	`
	tag, err := r.db.Exec(ctx, q,
		string(bullets), patch.Participants, patch.Sentiment, patch.ModelUsed,
		patch.TokensIn, patch.TokensOut, patch.TTFBMs, patch.TotalMs,
		string(patch.Outcome), patch.RefusalReason, patch.CachedHit, id,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("ai_summaries: row not found")
	}
	return nil
}

func (r *aiSummaryRepo) GetByID(ctx context.Context, id, requesterID string) (*models.AISummary, error) {
	return r.fetch(ctx, "id = $1 AND requested_by = $2", id, requesterID)
}

func (r *aiSummaryRepo) GetByRequestID(ctx context.Context, requestID, requesterID string) (*models.AISummary, error) {
	return r.fetch(ctx, "request_id = $1 AND requested_by = $2", requestID, requesterID)
}

func (r *aiSummaryRepo) fetch(ctx context.Context, where string, args ...any) (*models.AISummary, error) {
	q := `
		SELECT id, request_id, server_id, channel_id, requested_by,
		       anchor_msg_id, latest_msg_id, window_start, window_end,
		       message_count, bullets::text, participants, sentiment, model_used,
		       tokens_in, tokens_out, ttfb_ms, total_ms,
		       outcome, refusal_reason, cache_key, cached_hit,
		       created_at, finished_at
		  FROM public.ai_summaries
		 WHERE ` + where

	row := r.db.QueryRow(ctx, q, args...)
	var s models.AISummary
	var bullets string
	if err := row.Scan(
		&s.ID, &s.RequestID, &s.ServerID, &s.ChannelID, &s.RequestedBy,
		&s.AnchorMsgID, &s.LatestMsgID, &s.WindowStart, &s.WindowEnd,
		&s.MessageCount, &bullets, &s.Participants, &s.Sentiment, &s.ModelUsed,
		&s.TokensIn, &s.TokensOut, &s.TTFBMs, &s.TotalMs,
		&s.Outcome, &s.RefusalReason, &s.CacheKey, &s.CachedHit,
		&s.CreatedAt, &s.FinishedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := s.DecodeBullets([]byte(bullets)); err != nil {
		return nil, fmt.Errorf("decode bullets: %w", err)
	}
	return &s, nil
}

func (r *aiSummaryRepo) UpsertFeedback(ctx context.Context, f *models.SummaryFeedback) error {
	const q = `
		INSERT INTO public.ai_summary_feedback (id, summary_id, user_id, rating, reason)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (summary_id, user_id)
		DO UPDATE SET rating = EXCLUDED.rating, reason = EXCLUDED.reason, created_at = now()
	`
	_, err := r.db.Exec(ctx, q, f.ID, f.SummaryID, f.UserID, f.Rating, f.Reason)
	return err
}

// ErrNotFound is returned when a row matching the query does not exist.
var ErrNotFound = errors.New("not found")
