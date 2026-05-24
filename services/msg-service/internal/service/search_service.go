package service

import (
	"context"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	"github.com/flicko-org/flicko/services/msg-service/internal/search"
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
	meili    *search.MeiliSearchClient
	log      *zap.Logger
}

// NewSearchService creates a SearchService.
func NewSearchService(
	msgs repository.MessageRepository,
	channels repository.ChannelRepository,
	meili *search.MeiliSearchClient,
	log *zap.Logger,
) *SearchService {
	return &SearchService{
		messages: msgs,
		channels: channels,
		meili:    meili,
		log:      log,
	}
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

	// Try Meilisearch query first if configured
	if s.meili != nil {
		var beforeTime *time.Time
		if in.Before != "" {
			if beforeMsg, err := s.messages.GetByMessageID(ctx, in.Before); err == nil && beforeMsg != nil {
				beforeTime = &beforeMsg.CreatedAt
			}
		}

		res, err := s.meili.Search(ctx, in.ChannelID, in.Query, beforeTime, in.Limit)
		if err == nil {
			s.log.Debug("meilisearch search hit", zap.String("query", in.Query), zap.Int("count", len(res)))
			return res, nil
		}

		// Log warning and fall back on failure (Availability > Performance)
		s.log.Warn("meilisearch query failed, falling back to PostgreSQL",
			zap.Error(err),
			zap.String("query", in.Query),
		)
	}

	return s.messages.Search(ctx, in.ChannelID, in.Query, in.Before, in.Limit)
}
