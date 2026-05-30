package models

import (
	"encoding/json"
	"time"
)

// SummaryOutcome captures the terminal state of a summary request.
type SummaryOutcome string

const (
	SummaryPending     SummaryOutcome = "pending"
	SummaryDone        SummaryOutcome = "done"
	SummaryRefused     SummaryOutcome = "refused"
	SummaryError       SummaryOutcome = "error"
	SummaryRateLimited SummaryOutcome = "rate_limited"
)

// SummaryBullet is one line of an AI summary along with the source message
// IDs it cites. Citations let the client render "peek" sheets jumping back
// to the original messages.
type SummaryBullet struct {
	Index     int      `json:"idx"`
	Text      string   `json:"text"`
	Citations []string `json:"citations"`
}

// AISummary mirrors the ai_summaries table. Bullets are stored as JSONB and
// hydrated/persisted via the helper methods below.
type AISummary struct {
	ID             string          `json:"id" db:"id"`
	RequestID      string          `json:"request_id" db:"request_id"`
	ServerID       string          `json:"server_id" db:"server_id"`
	ChannelID      string          `json:"channel_id" db:"channel_id"`
	RequestedBy    string          `json:"requested_by" db:"requested_by"`
	AnchorMsgID    *string         `json:"anchor_msg_id,omitempty" db:"anchor_msg_id"`
	LatestMsgID    *string         `json:"latest_msg_id,omitempty" db:"latest_msg_id"`
	WindowStart    time.Time       `json:"window_start" db:"window_start"`
	WindowEnd      time.Time       `json:"window_end" db:"window_end"`
	MessageCount   int             `json:"message_count" db:"message_count"`
	Bullets        []SummaryBullet `json:"bullets"`
	Participants   []string        `json:"participants" db:"participants"`
	Sentiment      *string         `json:"sentiment,omitempty" db:"sentiment"`
	ModelUsed      string          `json:"model_used" db:"model_used"`
	TokensIn       *int            `json:"tokens_in,omitempty" db:"tokens_in"`
	TokensOut      *int            `json:"tokens_out,omitempty" db:"tokens_out"`
	TTFBMs         *int            `json:"ttfb_ms,omitempty" db:"ttfb_ms"`
	TotalMs        *int            `json:"total_ms,omitempty" db:"total_ms"`
	Outcome        SummaryOutcome  `json:"outcome" db:"outcome"`
	RefusalReason  *string         `json:"refusal_reason,omitempty" db:"refusal_reason"`
	CacheKey       string          `json:"cache_key" db:"cache_key"`
	CachedHit      bool            `json:"cached_hit" db:"cached_hit"`
	CreatedAt      time.Time       `json:"created_at" db:"created_at"`
	FinishedAt     *time.Time      `json:"finished_at,omitempty" db:"finished_at"`
}

// EncodeBullets returns the JSON encoding to write into the bullets column.
func (s *AISummary) EncodeBullets() ([]byte, error) {
	if s.Bullets == nil {
		return []byte("[]"), nil
	}
	return json.Marshal(s.Bullets)
}

// DecodeBullets parses the bullets column into the Bullets field.
func (s *AISummary) DecodeBullets(raw []byte) error {
	if len(raw) == 0 {
		s.Bullets = []SummaryBullet{}
		return nil
	}
	return json.Unmarshal(raw, &s.Bullets)
}

// SummaryFeedback mirrors ai_summary_feedback.
type SummaryFeedback struct {
	ID        string    `json:"id" db:"id"`
	SummaryID string    `json:"summary_id" db:"summary_id"`
	UserID    string    `json:"user_id" db:"user_id"`
	Rating    int16     `json:"rating" db:"rating"` // -1 or +1
	Reason    *string   `json:"reason,omitempty" db:"reason"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
