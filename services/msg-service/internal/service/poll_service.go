package service

import (
	"context"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
)

// ── Input / Output types ────────────────────────────────────────────

// PollOptionInput represents a single poll option submitted by the client.
type PollOptionInput struct {
	Text  string
	Emoji string
}

// CreatePollInput is the input for creating a poll.
type CreatePollInput struct {
	ChannelID       string
	CreatorID       string
	Question        string
	Options         []PollOptionInput
	DurationSeconds int
	AllowMultiVote  bool
}

// PollResult is the API response for a poll with its options and vote counts.
type PollResult struct {
	ID             string             `json:"id"`
	ChannelID      string             `json:"channel_id"`
	CreatorID      string             `json:"creator_id"`
	Question       string             `json:"question"`
	Options        []PollOptionResult `json:"options"`
	AllowMultiVote bool               `json:"allow_multi_vote"`
	ExpiresAt      *time.Time         `json:"expires_at,omitempty"`
	EndedAt        *time.Time         `json:"ended_at,omitempty"`
	TotalVotes     int                `json:"total_votes"`
	CreatedAt      time.Time          `json:"created_at"`
}

// PollOptionResult is a single option with its vote count.
type PollOptionResult struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	Emoji     string `json:"emoji,omitempty"`
	VoteCount int    `json:"vote_count"`
}

// ── Service ─────────────────────────────────────────────────────────

// PollService handles poll business logic.
type PollService struct {
	polls    repository.PollRepository
	channels repository.ChannelRepository
	log      *zap.Logger
}

// NewPollService creates a PollService.
func NewPollService(
	polls repository.PollRepository,
	channels repository.ChannelRepository,
	log *zap.Logger,
) *PollService {
	return &PollService{polls: polls, channels: channels, log: log}
}

// CreatePoll validates and creates a poll with its options.
func (s *PollService) CreatePoll(ctx context.Context, in CreatePollInput) (*PollResult, error) {
	// Validate
	if in.Question == "" || len(in.Question) > 300 {
		return nil, fkerr.ErrValidation("question must be 1-300 characters")
	}
	if len(in.Options) < 2 || len(in.Options) > 10 {
		return nil, fkerr.ErrValidation("polls require 2-10 options")
	}
	for _, o := range in.Options {
		if o.Text == "" || len(o.Text) > 100 {
			return nil, fkerr.ErrValidation("each option must be 1-100 characters")
		}
	}

	// Membership check
	isMember, err := s.channels.IsMember(ctx, in.ChannelID, in.CreatorID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, fkerr.ErrForbidden("not a member of this channel's server")
	}

	// Build poll model
	pollID := id.New()
	var expiresAt *time.Time
	if in.DurationSeconds > 0 {
		t := time.Now().Add(time.Duration(in.DurationSeconds) * time.Second)
		expiresAt = &t
	}

	poll := &repository.Poll{
		ID:             pollID,
		ChannelID:      in.ChannelID,
		CreatorID:      in.CreatorID,
		Question:       in.Question,
		AllowMultiVote: in.AllowMultiVote,
		ExpiresAt:      expiresAt,
	}

	options := make([]*repository.PollOption, len(in.Options))
	for i, o := range in.Options {
		options[i] = &repository.PollOption{
			ID:       id.New(),
			PollID:   pollID,
			Text:     o.Text,
			Emoji:    o.Emoji,
			Position: i,
		}
	}

	if err := s.polls.CreateWithOptions(ctx, poll, options); err != nil {
		return nil, err
	}

	// Build result
	optResults := make([]PollOptionResult, len(options))
	for i, o := range options {
		optResults[i] = PollOptionResult{
			ID:    o.ID,
			Text:  o.Text,
			Emoji: o.Emoji,
		}
	}

	return &PollResult{
		ID:             poll.ID,
		ChannelID:      poll.ChannelID,
		CreatorID:      poll.CreatorID,
		Question:       poll.Question,
		Options:        optResults,
		AllowMultiVote: poll.AllowMultiVote,
		ExpiresAt:      poll.ExpiresAt,
		CreatedAt:      time.Now(),
	}, nil
}

// GetPoll fetches a poll with its options and vote counts.
func (s *PollService) GetPoll(ctx context.Context, pollID string) (*PollResult, error) {
	poll, err := s.polls.GetByID(ctx, pollID)
	if err != nil {
		return nil, err
	}
	if poll == nil {
		return nil, fkerr.ErrNotFound("poll")
	}

	options, err := s.polls.GetOptions(ctx, pollID)
	if err != nil {
		return nil, err
	}

	optResults := make([]PollOptionResult, len(options))
	var totalVotes int
	for i, o := range options {
		optResults[i] = PollOptionResult{
			ID:        o.ID,
			Text:      o.Text,
			Emoji:     o.Emoji,
			VoteCount: o.VoteCount,
		}
		totalVotes += o.VoteCount
	}

	return &PollResult{
		ID:             poll.ID,
		ChannelID:      poll.ChannelID,
		CreatorID:      poll.CreatorID,
		Question:       poll.Question,
		Options:        optResults,
		AllowMultiVote: poll.AllowMultiVote,
		ExpiresAt:      poll.ExpiresAt,
		EndedAt:        poll.EndedAt,
		TotalVotes:     totalVotes,
		CreatedAt:      poll.CreatedAt,
	}, nil
}

// Vote casts or replaces a vote on a poll.
func (s *PollService) Vote(ctx context.Context, pollID, userID, optionID string) error {
	poll, err := s.polls.GetByID(ctx, pollID)
	if err != nil {
		return err
	}
	if poll == nil {
		return fkerr.ErrNotFound("poll")
	}
	if poll.EndedAt != nil {
		return fkerr.ErrValidation("poll has ended")
	}
	if poll.ExpiresAt != nil && time.Now().After(*poll.ExpiresAt) {
		return fkerr.ErrValidation("poll has expired")
	}

	if !poll.AllowMultiVote {
		// Remove existing vote before casting new one
		_ = s.polls.RemoveVote(ctx, pollID, userID)
	}

	return s.polls.AddVote(ctx, pollID, optionID, userID)
}

// Unvote removes a user's vote from a poll.
func (s *PollService) Unvote(ctx context.Context, pollID, userID string) error {
	return s.polls.RemoveVote(ctx, pollID, userID)
}

// EndPoll manually ends a poll (creator only).
func (s *PollService) EndPoll(ctx context.Context, pollID, userID string) error {
	poll, err := s.polls.GetByID(ctx, pollID)
	if err != nil {
		return err
	}
	if poll == nil {
		return fkerr.ErrNotFound("poll")
	}
	if poll.CreatorID != userID {
		return fkerr.ErrForbidden("only the creator can end the poll")
	}

	return s.polls.EndPoll(ctx, pollID)
}
