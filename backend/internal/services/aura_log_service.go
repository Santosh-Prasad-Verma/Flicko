package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

var (
	// ErrAuraInvalidInput indicates missing or malformed input for Aura log operations.
	ErrAuraInvalidInput = errors.New("invalid input")
	// ErrAuraBatchTooLarge indicates the conversation batch exceeds the maximum allowed size.
	ErrAuraBatchTooLarge = errors.New("batch too large")
)

const maxAuraBatchSize = 100

// AuraLogService manages AI Aura conversation persistence and retrieval.
type AuraLogService interface {
	SaveConversation(ctx context.Context, userID string, turns []AuraLogTurn) error
	GetHistory(ctx context.Context, userID string, limit int) ([]*repo.AuraChatLog, error)
	Search(ctx context.Context, userID string, query string, limit int) ([]*repo.AuraChatLog, error)
}

// AuraLogTurn represents a single conversation turn submitted by the mobile client.
type AuraLogTurn struct {
	SessionID string           `json:"session_id"`
	Role      string           `json:"role"`
	Content   string           `json:"content"`
	ToolCalls []repo.ToolCall  `json:"tool_calls,omitempty"`
	Metadata  map[string]any   `json:"metadata,omitempty"`
}

type auraLogService struct {
	repo   repo.AuraLogRepo
	logger *zap.Logger
}

// NewAuraLogService creates a new AuraLogService.
func NewAuraLogService(repo repo.AuraLogRepo, logger *zap.Logger) AuraLogService {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &auraLogService{
		repo:   repo,
		logger: logger.Named("service.aura_log"),
	}
}

func (s *auraLogService) SaveConversation(ctx context.Context, userID string, turns []AuraLogTurn) error {
	if userID == "" {
		return fmt.Errorf("%w: user_id is required", ErrAuraInvalidInput)
	}
	if len(turns) == 0 {
		return fmt.Errorf("%w: at least one turn is required", ErrAuraInvalidInput)
	}
	if len(turns) > maxAuraBatchSize {
		return fmt.Errorf("%w: maximum %d turns per batch", ErrAuraBatchTooLarge, maxAuraBatchSize)
	}

	logs := make([]*repo.AuraChatLog, 0, len(turns))
	for _, t := range turns {
		if t.Role != "user" && t.Role != "assistant" {
			return fmt.Errorf("%w: role must be 'user' or 'assistant'", ErrAuraInvalidInput)
		}
		logs = append(logs, &repo.AuraChatLog{
			ID:        uuid.NewString(),
			UserID:    userID,
			SessionID: t.SessionID,
			Role:      t.Role,
			Content:   t.Content,
			ToolCalls: t.ToolCalls,
			Metadata:  t.Metadata,
		})
	}

	if err := s.repo.SaveConversationBatch(ctx, logs); err != nil {
		s.logger.Error("failed to save conversation batch",
			zap.String("user_id", userID),
			zap.Int("turn_count", len(turns)),
			zap.Error(err),
		)
		return fmt.Errorf("save conversation: %w", err)
	}

	s.logger.Info("saved aura conversation",
		zap.String("user_id", userID),
		zap.Int("turn_count", len(turns)),
	)
	return nil
}

func (s *auraLogService) GetHistory(ctx context.Context, userID string, limit int) ([]*repo.AuraChatLog, error) {
	if userID == "" {
		return nil, fmt.Errorf("%w: user_id is required", ErrAuraInvalidInput)
	}
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}

	logs, err := s.repo.GetHistory(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("get aura history: %w", err)
	}
	return logs, nil
}

func (s *auraLogService) Search(ctx context.Context, userID string, query string, limit int) ([]*repo.AuraChatLog, error) {
	if userID == "" {
		return nil, fmt.Errorf("%w: user_id is required", ErrAuraInvalidInput)
	}
	if limit <= 0 {
		limit = 10
	}

	// TODO: Generate embedding vector from query text using Gemini Embedding API.
	// Once the embedding endpoint is integrated, call it here and pass the
	// resulting []float32 vector to s.repo.SemanticSearch(ctx, userID, vector, limit).
	// For now, return an empty result set.
	s.logger.Info("semantic search requested (embedding generation not yet implemented)",
		zap.String("user_id", userID),
		zap.String("query", query),
	)
	return []*repo.AuraChatLog{}, nil
}
