package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DrawingService interface {
	AddStroke(ctx context.Context, userID, shareID string, tool models.DrawingTool, color string, width int, opacity float64, coords map[string]interface{}) (*models.DrawingStroke, error)
	GetStrokes(ctx context.Context, shareID string) ([]*models.DrawingStroke, error)
}

type drawingService struct {
	db          *pgxpool.Pool
	voiceSvc    VoiceService
	permService PermissionService
}

func NewDrawingService(db *pgxpool.Pool, voiceSvc VoiceService, permService PermissionService) DrawingService {
	return &drawingService{
		db:          db,
		voiceSvc:    voiceSvc,
		permService: permService,
	}
}

func (s *drawingService) AddStroke(ctx context.Context, userID, shareID string, tool models.DrawingTool, color string, width int, opacity float64, coords map[string]interface{}) (*models.DrawingStroke, error) {
	userUUID, err1 := uuid.Parse(userID)
	shareUUID, err2 := uuid.Parse(shareID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	validTools := map[models.DrawingTool]bool{
		models.ToolPen:         true,
		models.ToolHighlighter: true,
		models.ToolEraser:      true,
		models.ToolShape:       true,
	}
	if !validTools[tool] {
		return nil, fmt.Errorf("invalid drawing tool")
	}

	if opacity < 0 || opacity > 1 {
		return nil, fmt.Errorf("opacity must be between 0 and 1")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. Verify screen share exists and is active, get channel_id
	var channelID string
	err = tx.QueryRow(ctx, "SELECT channel_id FROM public.screen_shares WHERE id = $1 AND ended_at IS NULL", shareUUID).Scan(&channelID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("screen share is not active or does not exist")
		}
		return nil, fmt.Errorf("failed to verify screen share: %w", err)
	}

	// 2. Verify user is in the SAME voice channel
	var sessionID string
	err = tx.QueryRow(ctx, "SELECT session_id FROM public.voice_states WHERE user_id = $1 AND channel_id = $2", userUUID, channelID).Scan(&sessionID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user is not connected to the channel's voice call")
		}
		return nil, fmt.Errorf("failed to verify voice state: %w", err)
	}

	// 3. Insert stroke
	strokeID := uuid.New()
	query := `
		INSERT INTO public.drawing_strokes (id, screen_share_id, user_id, tool, color, width, opacity, coordinates)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, screen_share_id, user_id, tool, color, width, opacity, coordinates, created_at
	`

	var stroke models.DrawingStroke
	err = tx.QueryRow(ctx, query, strokeID, shareUUID, userUUID, tool, color, width, opacity, coords).
		Scan(&stroke.ID, &stroke.ScreenShareID, &stroke.UserID, &stroke.Tool, &stroke.Color, &stroke.Width, &stroke.Opacity, &stroke.Coordinates, &stroke.CreatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to insert drawing stroke: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit tx: %w", err)
	}

	// Ideally this broadcast happens via WebRTC Data Channels (low latency <100ms) rather than standard HTTP.

	return &stroke, nil
}

func (s *drawingService) GetStrokes(ctx context.Context, shareID string) ([]*models.DrawingStroke, error) {
	shareUUID, err := uuid.Parse(shareID)
	if err != nil {
		return nil, fmt.Errorf("invalid screen share uuid format")
	}

	// Normally we would also verify if the share is active here or return historical.
	// DB schema allows retrieving it unless cascade deleted.

	query := `
		SELECT id, screen_share_id, user_id, tool, color, width, opacity, coordinates, created_at
		FROM public.drawing_strokes
		WHERE screen_share_id = $1
		ORDER BY created_at ASC
	`
	rows, err := s.db.Query(ctx, query, shareUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to query drawing strokes: %w", err)
	}
	defer rows.Close()

	var strokes []*models.DrawingStroke
	for rows.Next() {
		str := &models.DrawingStroke{}
		if err := rows.Scan(&str.ID, &str.ScreenShareID, &str.UserID, &str.Tool, &str.Color, &str.Width, &str.Opacity, &str.Coordinates, &str.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		strokes = append(strokes, str)
	}

	return strokes, nil
}
