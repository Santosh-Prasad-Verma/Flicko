package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PinService interface {
	PinMessage(ctx context.Context, userID, channelID, messageID string) error
	UnpinMessage(ctx context.Context, userID, channelID, messageID string) error
}

type pinService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewPinService(db *pgxpool.Pool, permService PermissionService) PinService {
	return &pinService{
		db:          db,
		permService: permService,
	}
}

func (s *pinService) PinMessage(ctx context.Context, userID, channelID, messageID string) error {
	userUUID, err1 := uuid.Parse(userID)
	channelUUID, err2 := uuid.Parse(channelID)
	msgUUID, err3 := uuid.Parse(messageID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// 1. Verify permissions (MANAGE_MESSAGES)
	hasPerm, err := s.permService.HasPermission(ctx, userUUID, channelUUID, "MANAGE_MESSAGES")
	if err != nil {
		return fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return fmt.Errorf("user does not have MANAGE_MESSAGES permission")
	}

	// 2. Check current pin count for the channel
	var pinCount int
	err = s.db.QueryRow(ctx, "SELECT count(*) FROM public.pinned_messages WHERE channel_id = $1", channelUUID).Scan(&pinCount)
	if err != nil {
		return fmt.Errorf("failed to get pin count: %w", err)
	}

	if pinCount >= 50 {
		return fmt.Errorf("channel has reached the maximum limit of 50 pinned messages")
	}

	// 3. Insert pinned message record
	// The DB schema sets pinned_at = NOW() automatically
	pinID := uuid.New()
	query := `
		INSERT INTO public.pinned_messages (id, channel_id, message_id, pinned_by) 
		VALUES ($1, $2, $3, $4) 
		ON CONFLICT (channel_id, message_id) DO NOTHING
	`
	res, err := s.db.Exec(ctx, query, pinID, channelUUID, msgUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to pin message: %w", err)
	}

	if res.RowsAffected() == 0 {
		return fmt.Errorf("message is already pinned")
	}

	return nil
}

func (s *pinService) UnpinMessage(ctx context.Context, userID, channelID, messageID string) error {
	userUUID, err1 := uuid.Parse(userID)
	channelUUID, err2 := uuid.Parse(channelID)
	msgUUID, err3 := uuid.Parse(messageID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// Verify permissions (MANAGE_MESSAGES)
	hasPerm, err := s.permService.HasPermission(ctx, userUUID, channelUUID, "MANAGE_MESSAGES")
	if err != nil {
		return fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return fmt.Errorf("user does not have MANAGE_MESSAGES permission")
	}

	// Delete pin
	res, err := s.db.Exec(ctx, "DELETE FROM public.pinned_messages WHERE channel_id = $1 AND message_id = $2", channelUUID, msgUUID)
	if err != nil {
		return fmt.Errorf("failed to unpin message: %w", err)
	}

	if res.RowsAffected() == 0 {
		return fmt.Errorf("message is not pinned")
	}

	return nil
}
