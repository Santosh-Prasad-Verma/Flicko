package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PresenceService interface {
	SetPresence(ctx context.Context, userID string, status models.PresenceStatus) error
	GetPresence(ctx context.Context, userID string) (*models.Presence, error)
	HandleDisconnect(ctx context.Context, userID string) error
	HandleIdle(ctx context.Context, userID string) error
}

type presenceService struct {
	db *pgxpool.Pool
}

func NewPresenceService(db *pgxpool.Pool) PresenceService {
	return &presenceService{
		db: db,
	}
}

func (s *presenceService) SetPresence(ctx context.Context, userID string, status models.PresenceStatus) error {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id format")
	}

	validStatuses := map[models.PresenceStatus]bool{
		models.StatusOnline:  true,
		models.StatusIdle:    true,
		models.StatusDND:     true,
		models.StatusOffline: true,
	}

	if !validStatuses[status] {
		return fmt.Errorf("invalid presence status")
	}

	query := `
		INSERT INTO public.presence (user_id, status, last_changed)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			status = EXCLUDED.status,
			last_changed = EXCLUDED.last_changed
	`

	_, err = s.db.Exec(ctx, query, userUUID, status)
	if err != nil {
		return fmt.Errorf("failed to update presence: %w", err)
	}

	// In a complete implementation we'd also trigger a Broadcast presence.update via WebPubSub here.

	return nil
}

func (s *presenceService) GetPresence(ctx context.Context, userID string) (*models.Presence, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	var presence models.Presence
	query := `
		SELECT user_id, status, last_changed
		FROM public.presence
		WHERE user_id = $1
	`
	err = s.db.QueryRow(ctx, query, userUUID).Scan(
		&presence.UserID,
		&presence.Status,
		&presence.UpdatedAt,
	)

	if err != nil {
		// Default to offline if no record exists
		return &models.Presence{
			UserID:    userID,
			Status:    models.StatusOffline,
			UpdatedAt: time.Time{}, // zero value is fine
		}, nil
	}

	return &presence, nil
}

func (s *presenceService) HandleDisconnect(ctx context.Context, userID string) error {
	go func() {
		time.Sleep(500 * time.Millisecond)

		userUUID, err := uuid.Parse(userID)
		if err != nil {
			return
		}

		// Only set offline if there hasn't been a status change in the last 400ms.
		// This prevents setting the user offline if they quickly reconnected.
		query := `
			UPDATE public.presence 
			SET status = $1, last_changed = NOW()
			WHERE user_id = $2 
			AND status != $1
			AND last_changed < (NOW() - INTERVAL '400 milliseconds')
		`

		_, err = s.db.Exec(context.Background(), query, models.StatusOffline, userUUID)
		if err != nil {
			fmt.Printf("[Presence] Failed to set offline securely for user %s: %v\n", userID, err)
		}
	}()

	return nil
}

func (s *presenceService) HandleIdle(ctx context.Context, userID string) error {
	// Usually called from WS when client hasn't sent ping/events for 10 minutes.
	return s.SetPresence(ctx, userID, models.StatusIdle)
}
