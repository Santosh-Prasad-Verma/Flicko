package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CommunityEventService interface {
	CreateEvent(ctx context.Context, serverID, creatorID, name string, description *string, eventType string, location *string, startTime time.Time, endTime *time.Time, recurrenceRule *string) (*models.CommunityEvent, error)
	GetUpcomingEvents(ctx context.Context, serverID string) ([]*models.CommunityEvent, error)
	SetParticipationStatus(ctx context.Context, eventID, userID, status string) error
}

type communityEventService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewCommunityEventService(db *pgxpool.Pool, permService PermissionService) CommunityEventService {
	return &communityEventService{
		db:          db,
		permService: permService,
	}
}

func (s *communityEventService) CreateEvent(ctx context.Context, serverID, creatorID, name string, description *string, eventType string, location *string, startTime time.Time, endTime *time.Time, recurrenceRule *string) (*models.CommunityEvent, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	creatorUUID, err2 := uuid.Parse(creatorID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	if eventType != "voice" && eventType != "stage" && eventType != "external" && eventType != "text" {
		return nil, fmt.Errorf("invalid event type")
	}

	if startTime.Before(time.Now()) {
		return nil, fmt.Errorf("start time must be in the future")
	}
	if endTime != nil && endTime.Before(startTime) {
		return nil, fmt.Errorf("end time must be after start time")
	}

	hasPerm, err := s.permService.HasPermission(ctx, creatorUUID, serverUUID, "MANAGE_EVENTS")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_EVENTS permission")
	}

	query := `
		INSERT INTO public.community_events (server_id, creator_id, name, description, event_type, location, status, start_time, end_time, recurrence_rule)
		VALUES ($1, $2, $3, $4, $5, $6, 'scheduled', $7, $8, $9)
		RETURNING id, server_id, creator_id, name, description, event_type, location, status, start_time, end_time, recurrence_rule, created_at, updated_at
	`

	var e models.CommunityEvent
	err = s.db.QueryRow(ctx, query, serverUUID, creatorUUID, name, description, eventType, location, startTime, endTime, recurrenceRule).
		Scan(&e.ID, &e.ServerID, &e.CreatorID, &e.Name, &e.Description, &e.EventType, &e.Location, &e.Status, &e.StartTime, &e.EndTime, &e.RecurrenceRule, &e.CreatedAt, &e.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create event: %w", err)
	}

	return &e, nil
}

func (s *communityEventService) GetUpcomingEvents(ctx context.Context, serverID string) ([]*models.CommunityEvent, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server uuid")
	}

	// Aggregate interested/attending counts
	query := `
		SELECT 
			e.id, e.server_id, e.creator_id, e.name, e.description, e.event_type, e.location, e.status, e.start_time, e.end_time, e.recurrence_rule, e.created_at, e.updated_at,
			COALESCE(SUM(CASE WHEN p.status = 'interested' THEN 1 ELSE 0 END), 0) AS interested_count,
			COALESCE(SUM(CASE WHEN p.status = 'attending' THEN 1 ELSE 0 END), 0) AS attending_count
		FROM public.community_events e
		LEFT JOIN public.event_participants p ON e.id = p.event_id
		WHERE e.server_id = $1 AND e.status IN ('scheduled', 'active')
		GROUP BY e.id
		ORDER BY e.start_time ASC
	`

	rows, err := s.db.Query(ctx, query, serverUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to get events: %w", err)
	}
	defer rows.Close()

	var events []*models.CommunityEvent
	for rows.Next() {
		var e models.CommunityEvent
		if err := rows.Scan(
			&e.ID, &e.ServerID, &e.CreatorID, &e.Name, &e.Description, &e.EventType, &e.Location, &e.Status, &e.StartTime, &e.EndTime, &e.RecurrenceRule, &e.CreatedAt, &e.UpdatedAt,
			&e.InterestedCount, &e.AttendingCount,
		); err != nil {
			return nil, err
		}
		events = append(events, &e)
	}

	return events, nil
}

func (s *communityEventService) SetParticipationStatus(ctx context.Context, eventID, userID, status string) error {
	eventUUID, err1 := uuid.Parse(eventID)
	userUUID, err2 := uuid.Parse(userID)

	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	if status != "interested" && status != "attending" {
		return fmt.Errorf("invalid participation status")
	}

	query := `
		INSERT INTO public.event_participants (event_id, user_id, status)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id, user_id) 
		DO UPDATE SET status = EXCLUDED.status, joined_at = NOW()
	`

	_, err := s.db.Exec(ctx, query, eventUUID, userUUID, status)
	if err != nil {
		return fmt.Errorf("failed to set participation status: %w", err)
	}

	return nil
}

// Background cron logic placeholder
// UpdateStatusJobs calculates time.Now() against start_time/end_time and sets 'active' or 'completed'
// This would be run in a separate worker routine like a ticker.
