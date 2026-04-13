package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ThreadMemberService interface {
	JoinThread(ctx context.Context, threadID, userID string) (*models.ThreadMember, error)
	LeaveThread(ctx context.Context, threadID, userID string) error
	GetThreadMembers(ctx context.Context, threadID string) ([]*models.ThreadMember, error)
	UpdateNotificationSettings(ctx context.Context, threadID, userID string, settings map[string]interface{}) (*models.ThreadMember, error)
}

type threadMemberService struct {
	db *pgxpool.Pool
}

func NewThreadMemberService(db *pgxpool.Pool) ThreadMemberService {
	return &threadMemberService{
		db: db,
	}
}

func (s *threadMemberService) JoinThread(ctx context.Context, threadID, userID string) (*models.ThreadMember, error) {
	threadUUID, err1 := uuid.Parse(threadID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Check if thread exists and is not archived
	var isArchived bool
	err = tx.QueryRow(ctx, "SELECT is_archived FROM public.threads WHERE id = $1", threadUUID).Scan(&isArchived)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("thread not found")
		}
		return nil, fmt.Errorf("failed to check thread: %w", err)
	}
	if isArchived {
		return nil, fmt.Errorf("cannot join an archived thread")
	}

	defaultSettings := map[string]interface{}{
		"all_messages":  false,
		"mentions_only": true,
	}

	var member models.ThreadMember
	query := `
		INSERT INTO public.thread_members (thread_id, user_id, notification_settings)
		VALUES ($1, $2, $3)
		RETURNING thread_id, user_id, joined_at, last_read_message_id, notification_settings
	`
	err = tx.QueryRow(ctx, query, threadUUID, userUUID, defaultSettings).
		Scan(&member.ThreadID, &member.UserID, &member.JoinedAt, &member.LastReadMessageID, &member.NotificationSettings)

	if err != nil {
		return nil, fmt.Errorf("failed to join thread (might already be member): %w", err)
	}

	// Increment member_count
	_, err = tx.Exec(ctx, "UPDATE public.threads SET member_count = member_count + 1, updated_at = NOW() WHERE id = $1", threadUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to update member count: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit tx: %w", err)
	}

	return &member, nil
}

func (s *threadMemberService) LeaveThread(ctx context.Context, threadID, userID string) error {
	threadUUID, err1 := uuid.Parse(threadID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("failed to begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	res, err := tx.Exec(ctx, "DELETE FROM public.thread_members WHERE thread_id = $1 AND user_id = $2", threadUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to leave thread: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("user is not a member of this thread")
	}

	_, err = tx.Exec(ctx, "UPDATE public.threads SET member_count = GREATEST(0, member_count - 1), updated_at = NOW() WHERE id = $1", threadUUID)
	if err != nil {
		return fmt.Errorf("failed to update member count: %w", err)
	}

	return tx.Commit(ctx)
}

func (s *threadMemberService) GetThreadMembers(ctx context.Context, threadID string) ([]*models.ThreadMember, error) {
	threadUUID, err := uuid.Parse(threadID)
	if err != nil {
		return nil, fmt.Errorf("invalid thread id")
	}

	query := `
		SELECT thread_id, user_id, joined_at, last_read_message_id, notification_settings
		FROM public.thread_members
		WHERE thread_id = $1
		ORDER BY joined_at ASC
	`
	rows, err := s.db.Query(ctx, query, threadUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to query thread members: %w", err)
	}
	defer rows.Close()

	var members []*models.ThreadMember
	for rows.Next() {
		m := &models.ThreadMember{}
		if err := rows.Scan(&m.ThreadID, &m.UserID, &m.JoinedAt, &m.LastReadMessageID, &m.NotificationSettings); err != nil {
			return nil, fmt.Errorf("failed to scan member: %w", err)
		}
		members = append(members, m)
	}

	return members, nil
}

func (s *threadMemberService) UpdateNotificationSettings(ctx context.Context, threadID, userID string, settings map[string]interface{}) (*models.ThreadMember, error) {
	threadUUID, err1 := uuid.Parse(threadID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	query := `
		UPDATE public.thread_members
		SET notification_settings = $1
		WHERE thread_id = $2 AND user_id = $3
		RETURNING thread_id, user_id, joined_at, last_read_message_id, notification_settings
	`
	var m models.ThreadMember
	err := s.db.QueryRow(ctx, query, settings, threadUUID, userUUID).
		Scan(&m.ThreadID, &m.UserID, &m.JoinedAt, &m.LastReadMessageID, &m.NotificationSettings)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("thread member not found")
		}
		return nil, fmt.Errorf("failed to update settings: %w", err)
	}

	return &m, nil
}
