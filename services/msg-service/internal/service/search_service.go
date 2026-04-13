package service

import (
	"context"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// SearchInput is the input for searching messages.
type SearchInput struct {
	ChannelID string
	UserID    string
	Query     string
	Before    string
	Limit     int
}

// SearchService handles message search.
type SearchService struct {
	messages repository.MessageRepository
	channels repository.ChannelRepository
	log      *zap.Logger
}

// NewSearchService creates a SearchService.
func NewSearchService(
	msgs repository.MessageRepository,
	channels repository.ChannelRepository,
	log *zap.Logger,
) *SearchService {
	return &SearchService{messages: msgs, channels: channels, log: log}
}

// SearchMessages performs full-text search on messages in a channel.
func (s *SearchService) SearchMessages(ctx context.Context, in SearchInput) ([]*repository.Message, error) {
	if in.Query == "" {
		return nil, fkerr.ErrValidation("search query cannot be empty")
	}
	if len(in.Query) < 3 {
		return nil, fkerr.ErrValidation("search query must be at least 3 characters")
	}
	if in.Limit <= 0 || in.Limit > 50 {
		in.Limit = 25
	}

	// Access check
	isMember, err := s.channels.IsMember(ctx, in.ChannelID, in.UserID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, fkerr.ErrForbidden("not a member of this channel's server")
	}

	return s.messages.Search(ctx, in.ChannelID, in.Query, in.Before, in.Limit)
}
