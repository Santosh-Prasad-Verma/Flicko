package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ActivityService interface {
	SetActivity(ctx context.Context, userID string, activity *models.Activity) (*models.Activity, error)
	GetActivities(ctx context.Context, userID string) ([]*models.Activity, error)
	ClearActivity(ctx context.Context, userID, activityID string) error
	CleanupExpiredActivities(ctx context.Context) error
}

type activityService struct {
	db *pgxpool.Pool
}

func NewActivityService(db *pgxpool.Pool) ActivityService {
	return &activityService{
		db: db,
	}
}

func (s *activityService) SetActivity(ctx context.Context, userID string, activity *models.Activity) (*models.Activity, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	validTypes := map[models.ActivityType]bool{
		models.ActivityPlaying:   true,
		models.ActivityStreaming: true,
		models.ActivityListening: true,
		models.ActivityWatching:  true,
		models.ActivityCustom:    true,
	}
	if !validTypes[activity.Type] {
		return nil, fmt.Errorf("invalid activity type")
	}

	if activity.Name == "" {
		return nil, fmt.Errorf("activity name must not be empty")
	}

	activityID := uuid.New()
	query := `
		INSERT INTO public.activities (id, user_id, type, name, details, state, metadata, started_at, ends_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, user_id, type, name, details, state, metadata, started_at, ends_at, created_at
	`

	var a models.Activity
	startedAt := activity.StartedAt
	if startedAt.IsZero() {
		startedAt = time.Now()
	}

	err = s.db.QueryRow(ctx, query,
		activityID, userUUID, activity.Type, activity.Name,
		activity.Details, activity.State, activity.Metadata,
		startedAt, activity.EndsAt).Scan(
		&a.ID, &a.UserID, &a.Type, &a.Name, &a.Details,
		&a.State, &a.Metadata, &a.StartedAt, &a.EndsAt, &a.CreatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to insert activity: %w", err)
	}

	// Realtime push logic would normally happen here or via DB trigger.

	return &a, nil
}

func (s *activityService) GetActivities(ctx context.Context, userID string) ([]*models.Activity, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	// Filter out expired automatically when fetching
	query := `
		SELECT id, user_id, type, name, details, state, metadata, started_at, ends_at, created_at
		FROM public.activities
		WHERE user_id = $1 AND (ends_at IS NULL OR ends_at > NOW())
		ORDER BY started_at DESC
	`

	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to query activities: %w", err)
	}
	defer rows.Close()

	var activities []*models.Activity
	for rows.Next() {
		a := &models.Activity{}
		if err := rows.Scan(
			&a.ID, &a.UserID, &a.Type, &a.Name, &a.Details,
			&a.State, &a.Metadata, &a.StartedAt, &a.EndsAt, &a.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan activity: %w", err)
		}
		activities = append(activities, a)
	}

	return activities, nil
}

func (s *activityService) ClearActivity(ctx context.Context, userID, activityID string) error {
	userUUID, err1 := uuid.Parse(userID)
	actUUID, err2 := uuid.Parse(activityID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.activities WHERE id = $1 AND user_id = $2", actUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to clear activity: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("activity not found or unauthorized")
	}

	return nil
}

func (s *activityService) CleanupExpiredActivities(ctx context.Context) error {
	_, err := s.db.Exec(ctx, "DELETE FROM public.activities WHERE ends_at IS NOT NULL AND ends_at <= NOW()")
	return err
}
