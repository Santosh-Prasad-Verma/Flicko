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

type AnnouncementService interface {
	CreateAnnouncement(ctx context.Context, serverID, channelID, authorID, title, content, announcementType string, priority int, scheduledFor *time.Time) (*models.Announcement, error)
	GetAnnouncements(ctx context.Context, serverID string) ([]*models.Announcement, error)
	TrackView(ctx context.Context, announcementID string) error
	TogglePin(ctx context.Context, announcementID, executorID string, isPinned bool) error
}

type announcementService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewAnnouncementService(db *pgxpool.Pool, permService PermissionService) AnnouncementService {
	return &announcementService{
		db:          db,
		permService: permService,
	}
}

func (s *announcementService) CreateAnnouncement(ctx context.Context, serverID, channelID, authorID, title, content, announcementType string, priority int, scheduledFor *time.Time) (*models.Announcement, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	channelUUID, err2 := uuid.Parse(channelID)
	authorUUID, err3 := uuid.Parse(authorID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	if announcementType != "news" && announcementType != "update" && announcementType != "alert" && announcementType != "event" {
		return nil, fmt.Errorf("invalid announcement type")
	}

	if priority < 0 || priority > 10 {
		return nil, fmt.Errorf("priority must be between 0 and 10")
	}

	hasPerm, err := s.permService.HasPermission(ctx, authorUUID, channelUUID, "MANAGE_CHANNELS")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_CHANNELS permission")
	}

	var publishedAt *time.Time
	if scheduledFor == nil {
		now := time.Now()
		publishedAt = &now
	}

	query := `
		INSERT INTO public.announcements (server_id, channel_id, author_id, title, content, announcement_type, priority, published_at, scheduled_for)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, server_id, channel_id, author_id, title, content, announcement_type, priority, is_pinned, view_count, published_at, scheduled_for, created_at, updated_at
	`

	var a models.Announcement
	err = s.db.QueryRow(ctx, query, serverUUID, channelUUID, authorUUID, title, content, announcementType, priority, publishedAt, scheduledFor).
		Scan(&a.ID, &a.ServerID, &a.ChannelID, &a.AuthorID, &a.Title, &a.Content, &a.AnnouncementType, &a.Priority, &a.IsPinned, &a.ViewCount, &a.PublishedAt, &a.ScheduledFor, &a.CreatedAt, &a.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create announcement: %w", err)
	}

	return &a, nil
}

func (s *announcementService) GetAnnouncements(ctx context.Context, serverID string) ([]*models.Announcement, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server uuid")
	}

	query := `
		SELECT id, server_id, channel_id, author_id, title, content, announcement_type, priority, is_pinned, view_count, published_at, scheduled_for, created_at, updated_at
		FROM public.announcements
		WHERE server_id = $1 AND published_at IS NOT NULL
		ORDER BY is_pinned DESC, priority DESC, published_at DESC
	`

	rows, err := s.db.Query(ctx, query, serverUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to get announcements: %w", err)
	}
	defer rows.Close()

	var results []*models.Announcement
	for rows.Next() {
		var a models.Announcement
		if err := rows.Scan(
			&a.ID, &a.ServerID, &a.ChannelID, &a.AuthorID, &a.Title, &a.Content, &a.AnnouncementType, &a.Priority, &a.IsPinned, &a.ViewCount, &a.PublishedAt, &a.ScheduledFor, &a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, err
		}
		results = append(results, &a)
	}

	return results, nil
}

func (s *announcementService) TrackView(ctx context.Context, announcementID string) error {
	annID, err := uuid.Parse(announcementID)
	if err != nil {
		return fmt.Errorf("invalid announcement uuid")
	}

	_, err = s.db.Exec(ctx, "UPDATE public.announcements SET view_count = view_count + 1 WHERE id = $1", annID)
	return err
}

func (s *announcementService) TogglePin(ctx context.Context, announcementID, executorID string, isPinned bool) error {
	annID, err1 := uuid.Parse(announcementID)
	executorUUID, err2 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	var channelID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT channel_id FROM public.announcements WHERE id = $1", annID).Scan(&channelID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("announcement not found")
		}
		return err
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, channelID, "MANAGE_MESSAGES")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_MESSAGES permission to pin")
	}

	_, err = s.db.Exec(ctx, "UPDATE public.announcements SET is_pinned = $1 WHERE id = $2", isPinned, annID)
	return err
}
