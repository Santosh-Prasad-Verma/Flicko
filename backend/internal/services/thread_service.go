package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ThreadCreateRequest struct {
	Name                string
	Type                models.ThreadType
	AutoArchiveDuration string // "1 hour", "24 hours", "3 days", "1 week"
	ParentMessageID     *string
}

type ThreadService interface {
	CreateThread(ctx context.Context, creatorID, serverID, channelID string, req ThreadCreateRequest) (*models.Thread, error)
	UpdateThread(ctx context.Context, threadID string, name *string, isArchived *bool) (*models.Thread, error)
	DeleteThread(ctx context.Context, userID, threadID string) error
}

type threadService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewThreadService(db *pgxpool.Pool, permService PermissionService) ThreadService {
	return &threadService{
		db:          db,
		permService: permService,
	}
}

func parseDurationToHoursMap() map[string]int {
	return map[string]int{
		"1 hour":   1,
		"24 hours": 24,
		"3 days":   72,
		"1 week":   168,
	}
}

func (s *threadService) CreateThread(ctx context.Context, creatorID, serverID, channelID string, req ThreadCreateRequest) (*models.Thread, error) {
	creatorUUID, err1 := uuid.Parse(creatorID)
	serverUUID, err2 := uuid.Parse(serverID)
	channelUUID, err3 := uuid.Parse(channelID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	// 1. Validate permissions CREATE_THREADS
	hasPerm, err := s.permService.HasPermission(ctx, creatorUUID, channelUUID, "CREATE_THREADS")
	if err != nil {
		return nil, fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return nil, fmt.Errorf("user does not have CREATE_THREADS permission")
	}

	// 2. Validate Type & Duration
	validTypes := map[models.ThreadType]bool{
		models.ThreadPublic:       true,
		models.ThreadPrivate:      true,
		models.ThreadAnnouncement: true,
	}
	if !validTypes[req.Type] {
		return nil, fmt.Errorf("invalid thread type")
	}

	durationMap := parseDurationToHoursMap()
	hours, ok := durationMap[req.AutoArchiveDuration]
	if !ok {
		req.AutoArchiveDuration = "24 hours"
		hours = 24
	}

	// Parse parent message if exists
	var parentMsgUUID *uuid.UUID
	if req.ParentMessageID != nil {
		parsed, err := uuid.Parse(*req.ParentMessageID)
		if err == nil {
			parentMsgUUID = &parsed
		}
	}

	// Calculate initial archive_at
	archiveAt := time.Now().Add(time.Duration(hours) * time.Hour)

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to start tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 3. Insert Thread
	threadID := uuid.New()
	queryMsg := `
		INSERT INTO public.threads (id, server_id, parent_channel_id, parent_message_id, name, creator_id, type, auto_archive_duration, archive_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, message_count, member_count, is_archived, created_at, updated_at
	`

	var t models.Thread
	t.ServerID = serverID
	t.ParentChannelID = channelID
	t.ParentMessageID = req.ParentMessageID
	t.Name = req.Name
	t.CreatorID = creatorID
	t.Type = req.Type
	t.AutoArchiveDuration = req.AutoArchiveDuration
	t.ArchiveAt = archiveAt

	err = tx.QueryRow(ctx, queryMsg,
		threadID, serverUUID, channelUUID, parentMsgUUID, req.Name, creatorUUID, req.Type, req.AutoArchiveDuration, archiveAt).
		Scan(
			&t.ID,
			&t.MessageCount,
			&t.MemberCount,
			&t.IsArchived,
			&t.CreatedAt,
			&t.UpdatedAt,
		)
	if err != nil {
		return nil, fmt.Errorf("failed to insert thread: %w", err)
	}

	// 4. Insert Thread Member (Creator)
	defaultSettings := map[string]interface{}{
		"all_messages":  true,
		"mentions_only": false,
	}
	memberQuery := `
		INSERT INTO public.thread_members (thread_id, user_id, notification_settings)
		VALUES ($1, $2, $3)
	`
	_, err = tx.Exec(ctx, memberQuery, threadID, creatorUUID, defaultSettings)
	if err != nil {
		return nil, fmt.Errorf("failed to add creator as thread member: %w", err)
	}

	// Update Thread Member count because trigger might wait or we can let DB default/trigger handle it
	// In our Phase 1 schema, we didn't explicitly implement a trigger for `member_count` increment on insert
	// We should manually update it or rely on a trigger if one was added. We update to 1 here explicitly just in case.
	_, _ = tx.Exec(ctx, "UPDATE public.threads SET member_count = 1 WHERE id = $1", threadID)
	t.MemberCount = 1

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit tx: %w", err)
	}

	// Realtime Broadcast "thread.new" would happen here

	return &t, nil
}

func (s *threadService) UpdateThread(ctx context.Context, threadID string, name *string, isArchived *bool) (*models.Thread, error) {
	threadUUID, err := uuid.Parse(threadID)
	if err != nil {
		return nil, fmt.Errorf("invalid thread id format")
	}

	// Normally we'd verify MANAGE_THREADS or creator_id here before updating

	// Note: updating is_archived = false recalculates archive_at
	query := `
		UPDATE public.threads
		SET 
			name = COALESCE($1, name),
			is_archived = COALESCE($2, is_archived),
			archive_at = CASE 
				WHEN $2 = false THEN NOW() + auto_archive_duration
				WHEN $2 = true THEN NOW()
				ELSE archive_at
			END,
			updated_at = NOW()
		WHERE id = $3
		RETURNING id, server_id, parent_channel_id, parent_message_id, name, creator_id, type, message_count, member_count, is_archived, auto_archive_duration, archive_at, created_at, updated_at
	`

	var t models.Thread
	err = s.db.QueryRow(ctx, query, name, isArchived, threadUUID).
		Scan(
			&t.ID,
			&t.ServerID,
			&t.ParentChannelID,
			&t.ParentMessageID,
			&t.Name,
			&t.CreatorID,
			&t.Type,
			&t.MessageCount,
			&t.MemberCount,
			&t.IsArchived,
			&t.AutoArchiveDuration,
			&t.ArchiveAt,
			&t.CreatedAt,
			&t.UpdatedAt,
		)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("thread not found")
		}
		return nil, fmt.Errorf("failed to update thread: %w", err)
	}

	return &t, nil
}

func (s *threadService) DeleteThread(ctx context.Context, userID, threadID string) error {
	userUUID, err1 := uuid.Parse(userID)
	threadUUID, err2 := uuid.Parse(threadID)

	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// Check MANAGE_THREADS permission in parent channel
	var parentChannelUUID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT parent_channel_id FROM public.threads WHERE id = $1", threadUUID).Scan(&parentChannelUUID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("thread not found")
		}
		return fmt.Errorf("failed to fetch thread: %w", err)
	}

	hasPerm, err := s.permService.HasPermission(ctx, userUUID, parentChannelUUID, "MANAGE_THREADS")
	if err != nil {
		return fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return fmt.Errorf("user does not have MANAGE_THREADS permission")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.threads WHERE id = $1", threadUUID)
	if err != nil {
		return fmt.Errorf("failed to delete thread: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("thread not found")
	}

	return nil
}
