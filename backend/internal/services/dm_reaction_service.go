package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DMReactionService is NOT wired into the HTTP router (cmd/server/main.go): DM
// reactions are served by direct REST endpoints. Retained as a
// reference / ready-made backend-owned path.
type DMReactionService interface {
	AddReaction(ctx context.Context, channelID, messageID, userID, emoji string) (*models.Reaction, error)
	RemoveReaction(ctx context.Context, channelID, messageID, userID, emoji string) error
	GetReactions(ctx context.Context, messageID string) ([]*models.Reaction, error)
}

type dmReactionService struct {
	db       *pgxpool.Pool
	dmMsgSvc DMMessageService
}

func NewDMReactionService(db *pgxpool.Pool, dmMsgSvc DMMessageService) DMReactionService {
	return &dmReactionService{
		db:       db,
		dmMsgSvc: dmMsgSvc,
	}
}

func (s *dmReactionService) checkParticipationByMessage(ctx context.Context, msgUUID, userUUID uuid.UUID) error {
	var convUUID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT conversation_id FROM public.dm_messages WHERE id = $1", msgUUID).Scan(&convUUID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("message not found")
		}
		return fmt.Errorf("failed to get message conversation: %w", err)
	}

	var exists bool
	err = s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.group_dm_participants WHERE group_dm_id = $1 AND user_id = $2)", convUUID, userUUID).Scan(&exists)
	if err != nil || !exists {
		return fmt.Errorf("user is not an active participant in this dm conversation")
	}

	return nil
}

func (s *dmReactionService) AddReaction(ctx context.Context, channelID, messageID, userID, emoji string) (*models.Reaction, error) {
	msgUUID, err1 := uuid.Parse(messageID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	emoji = strings.TrimSpace(emoji)
	if emoji == "" {
		return nil, fmt.Errorf("emoji cannot be empty")
	}

	// 1. Validate participation
	if err := s.checkParticipationByMessage(ctx, msgUUID, userUUID); err != nil {
		return nil, err
	}

	query := `
		INSERT INTO public.reactions (message_id, user_id, emoji, created_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id, message_id, user_id, emoji, created_at
	`
	var react models.Reaction
	err := s.db.QueryRow(ctx, query, msgUUID, userUUID, emoji).
		Scan(&react.ID, &react.MessageID, &react.UserID, &react.Emoji, &react.CreatedAt)

	if err != nil {
		// Postgres duplicate key exception usually caught here if already reacted
		return nil, fmt.Errorf("failed to add reaction: %w", err)
	}

	return &react, nil
}

func (s *dmReactionService) RemoveReaction(ctx context.Context, channelID, messageID, userID, emoji string) error {
	msgUUID, err1 := uuid.Parse(messageID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3", msgUUID, userUUID, emoji)
	if err != nil {
		return fmt.Errorf("failed to remove reaction: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("reaction not found")
	}

	return nil
}

func (s *dmReactionService) GetReactions(ctx context.Context, messageID string) ([]*models.Reaction, error) {
	msgUUID, err := uuid.Parse(messageID)
	if err != nil {
		return nil, fmt.Errorf("invalid message uuid")
	}

	query := `
		SELECT id, message_id, user_id, emoji, created_at
		FROM public.reactions
		WHERE message_id = $1
		ORDER BY created_at ASC
	`
	rows, err := s.db.Query(ctx, query, msgUUID)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var reactions []*models.Reaction
	for rows.Next() {
		r := &models.Reaction{}
		if err := rows.Scan(&r.ID, &r.MessageID, &r.UserID, &r.Emoji, &r.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		reactions = append(reactions, r)
	}

	return reactions, nil
}
