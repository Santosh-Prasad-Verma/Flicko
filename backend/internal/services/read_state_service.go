package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ReadStateService interface {
	MarkAsRead(ctx context.Context, channelID, userID, messageID uuid.UUID) (*models.ReadState, error)
	GetReadStatesForUser(ctx context.Context, userID uuid.UUID) ([]*models.ReadState, error)
}

type readStateService struct {
	db *pgxpool.Pool
}

func NewReadStateService(db *pgxpool.Pool) ReadStateService {
	return &readStateService{
		db: db,
	}
}

func (s *readStateService) MarkAsRead(ctx context.Context, channelID, userID, messageID uuid.UUID) (*models.ReadState, error) {
	query := `
		INSERT INTO public.read_states (channel_id, user_id, last_read_message_id, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT ON CONSTRAINT read_states_pkey DO UPDATE SET
			last_read_message_id = EXCLUDED.last_read_message_id,
			updated_at = NOW()
		RETURNING channel_id, user_id, last_read_message_id, updated_at
	`

	var rs models.ReadState
	err := s.db.QueryRow(ctx, query, channelID, userID, messageID).
		Scan(&rs.ChannelID, &rs.UserID, &rs.LastReadMessageID, &rs.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to upsert read state: %w", err)
	}

	return &rs, nil
}

func (s *readStateService) GetReadStatesForUser(ctx context.Context, userID uuid.UUID) ([]*models.ReadState, error) {
	query := `
		SELECT channel_id, user_id, last_read_message_id, updated_at
		FROM public.read_states
		WHERE user_id = $1
	`
	rows, err := s.db.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to select read states: %w", err)
	}
	defer rows.Close()

	var states []*models.ReadState
	for rows.Next() {
		rs := &models.ReadState{}
		if err := rows.Scan(&rs.ChannelID, &rs.UserID, &rs.LastReadMessageID, &rs.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan error processing read states: %w", err)
		}
		states = append(states, rs)
	}

	return states, nil
}
