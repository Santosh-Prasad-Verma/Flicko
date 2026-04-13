package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Notification Service Interface ─────────────────────────────────────────

type NotificationService interface {
	GetNotifications(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]*models.Notification, error)
	MarkAsRead(ctx context.Context, userID, notificationID string) error
	MarkAllAsRead(ctx context.Context, userID string) error
	CreateNotification(ctx context.Context, userID, notificationType, title, body string, link *string) (*models.Notification, error)
	GetUnreadCount(ctx context.Context, userID string) (int, error)
}

type notificationService struct {
	db *pgxpool.Pool
}

func NewNotificationService(db *pgxpool.Pool) NotificationService {
	return &notificationService{db: db}
}

func (s *notificationService) CreateNotification(ctx context.Context, userID, notificationType, title, body string, link *string) (*models.Notification, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	validTypes := map[string]bool{"mention": true, "friend_request": true, "system": true, "dm": true, "server_event": true, "warning": true}
	if !validTypes[notificationType] {
		return nil, fmt.Errorf("invalid notification type: %s", notificationType)
	}

	query := `
		INSERT INTO public.notifications (user_id, type, title, body, link)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, user_id, type, title, body, link, read_at, created_at
	`

	var n models.Notification
	err = s.db.QueryRow(ctx, query, userUUID, notificationType, title, body, link).
		Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Link, &n.ReadAt, &n.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create notification: %w", err)
	}

	return &n, nil
}

func (s *notificationService) GetNotifications(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]*models.Notification, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	if limit <= 0 || limit > 50 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	whereExtra := ""
	if unreadOnly {
		whereExtra = " AND read_at IS NULL"
	}

	query := fmt.Sprintf(`
		SELECT id, user_id, type, title, body, link, read_at, created_at
		FROM public.notifications
		WHERE user_id = $1 %s
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, whereExtra)

	rows, err := s.db.Query(ctx, query, userUUID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get notifications: %w", err)
	}
	defer rows.Close()

	var notifications []*models.Notification
	for rows.Next() {
		n := &models.Notification{}
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Link, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}

	return notifications, nil
}

func (s *notificationService) MarkAsRead(ctx context.Context, userID, notificationID string) error {
	userUUID, err1 := uuid.Parse(userID)
	notifUUID, err2 := uuid.Parse(notificationID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	now := time.Now()
	res, err := s.db.Exec(ctx,
		"UPDATE public.notifications SET read_at = $3 WHERE id = $1 AND user_id = $2 AND read_at IS NULL",
		notifUUID, userUUID, now,
	)
	if err != nil {
		return fmt.Errorf("failed to mark notification as read: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("notification not found or already read")
	}

	return nil
}

func (s *notificationService) MarkAllAsRead(ctx context.Context, userID string) error {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user uuid")
	}

	now := time.Now()
	_, err = s.db.Exec(ctx,
		"UPDATE public.notifications SET read_at = $2 WHERE user_id = $1 AND read_at IS NULL",
		userUUID, now,
	)
	return err
}

func (s *notificationService) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return 0, fmt.Errorf("invalid user uuid")
	}

	var count int
	err = s.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM public.notifications WHERE user_id = $1 AND read_at IS NULL",
		userUUID,
	).Scan(&count)
	return count, err
}
