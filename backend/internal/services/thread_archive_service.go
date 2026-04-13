package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ThreadArchiveService interface {
	ArchiveThread(ctx context.Context, userID, threadID string) error
	UnarchiveThread(ctx context.Context, userID, threadID string) error
	AutoArchiveJob(ctx context.Context) error
}

type threadArchiveService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewThreadArchiveService(db *pgxpool.Pool, permService PermissionService) ThreadArchiveService {
	return &threadArchiveService{
		db:          db,
		permService: permService,
	}
}

func (s *threadArchiveService) hasManageThreads(ctx context.Context, userUUID, threadUUID uuid.UUID) (bool, error) {
	var parentChannelUUID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT parent_channel_id FROM public.threads WHERE id = $1", threadUUID).Scan(&parentChannelUUID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return false, fmt.Errorf("thread not found")
		}
		return false, fmt.Errorf("failed to fetch thread: %w", err)
	}

	return s.permService.HasPermission(ctx, userUUID, parentChannelUUID, "MANAGE_THREADS")
}

func (s *threadArchiveService) ArchiveThread(ctx context.Context, userID, threadID string) error {
	userUUID, err1 := uuid.Parse(userID)
	threadUUID, err2 := uuid.Parse(threadID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// Verify permissions
	hasPerm, err := s.hasManageThreads(ctx, userUUID, threadUUID)
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("user does not have MANAGE_THREADS permission in parent channel")
	}

	// Archive thread and set archive_at to now
	res, err := s.db.Exec(ctx, "UPDATE public.threads SET is_archived = true, archive_at = NOW(), updated_at = NOW() WHERE id = $1 AND is_archived = false", threadUUID)
	if err != nil {
		return fmt.Errorf("failed to archive thread: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("thread is already archived or does not exist")
	}

	return nil
}

func (s *threadArchiveService) UnarchiveThread(ctx context.Context, userID, threadID string) error {
	userUUID, err1 := uuid.Parse(userID)
	threadUUID, err2 := uuid.Parse(threadID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// For unarchiving, discord allows anyone who can SEND_MESSAGES to unarchive, or MANAGE_THREADS.
	// We'll stick to MANAGE_THREADS for simplicity matching the requirements outline.
	hasPerm, err := s.hasManageThreads(ctx, userUUID, threadUUID)
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("user does not have MANAGE_THREADS permission in parent channel")
	}

	// Recalculate archive_at (NOW + auto_archive_duration)
	query := `
		UPDATE public.threads 
		SET is_archived = false, 
			archive_at = NOW() + auto_archive_duration, 
			updated_at = NOW() 
		WHERE id = $1 AND is_archived = true
	`
	res, err := s.db.Exec(ctx, query, threadUUID)
	if err != nil {
		return fmt.Errorf("failed to unarchive thread: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("thread is not archived or does not exist")
	}

	return nil
}

func (s *threadArchiveService) AutoArchiveJob(ctx context.Context) error {
	// Finds all unarchived threads where archive_at has passed and sets them to archived
	// We use the same auto_archive_duration parsing from PG interval.

	query := `
		UPDATE public.threads
		SET is_archived = true, updated_at = NOW()
		WHERE is_archived = false AND archive_at <= NOW()
	`
	_, err := s.db.Exec(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to run auto-archive job: %w", err)
	}

	return nil
}
