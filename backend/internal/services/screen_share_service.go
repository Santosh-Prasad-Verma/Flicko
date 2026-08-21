package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ScreenShareService interface {
	StartScreenShare(ctx context.Context, userID, channelID, sessionID string, shareType models.ScreenShareType, resolution string, frameRate int) (*models.ScreenShare, error)
	StopScreenShare(ctx context.Context, userID, shareID string) error
	GetActiveScreenShares(ctx context.Context, channelID string) ([]*models.ScreenShare, error)
}

type screenShareService struct {
	db          *pgxpool.Pool
	voiceSvc    VoiceService
	permService PermissionService
}

func NewScreenShareService(db *pgxpool.Pool, voiceSvc VoiceService, permService PermissionService) ScreenShareService {
	return &screenShareService{
		db:          db,
		voiceSvc:    voiceSvc,
		permService: permService,
	}
}

func (s *screenShareService) StartScreenShare(ctx context.Context, userID, channelID, sessionID string, shareType models.ScreenShareType, resolution string, frameRate int) (*models.ScreenShare, error) {
	userUUID, err1 := uuid.Parse(userID)
	channelUUID, err2 := uuid.Parse(channelID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	validTypes := map[models.ScreenShareType]bool{
		models.ShareTypeScreen: true,
		models.ShareTypeWindow: true,
		models.ShareTypeTab:    true,
	}

	if !validTypes[shareType] {
		return nil, fmt.Errorf("invalid share type")
	}
	if sessionID == "" {
		return nil, fmt.Errorf("session_id is required")
	}

	// 1. Verify user is in the voice channel (via voice_states)
	var activeSessionID string
	err := s.db.QueryRow(ctx, "SELECT session_id FROM public.voice_states WHERE user_id = $1 AND channel_id = $2", userUUID, channelUUID).Scan(&activeSessionID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user is not connected to this voice channel")
		}
		return nil, fmt.Errorf("failed to verify voice state: %w", err)
	}

	if activeSessionID != sessionID {
		return nil, fmt.Errorf("session ID mismatch, must use active voice session")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update voice_states to indicate streaming
	_, err = tx.Exec(ctx, "UPDATE public.voice_states SET is_streaming = true, updated_at = NOW() WHERE session_id = $1", sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to update stream voice state: %w", err)
	}

	shareID := uuid.New()
	query := `
		INSERT INTO public.screen_shares (id, user_id, channel_id, session_id, share_type, resolution, frame_rate)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, user_id, channel_id, session_id, share_type, resolution, frame_rate, viewer_count, started_at, ended_at
	`

	var share models.ScreenShare
	err = tx.QueryRow(ctx, query, shareID, userUUID, channelUUID, sessionID, shareType, resolution, frameRate).
		Scan(&share.ID, &share.UserID, &share.ChannelID, &share.SessionID, &share.ShareType, &share.Resolution, &share.FrameRate, &share.ViewerCount, &share.StartedAt, &share.EndedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create screen share record: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit tx: %w", err)
	}

	// WebPubSub broadcast would occur here.

	return &share, nil
}

func (s *screenShareService) StopScreenShare(ctx context.Context, userID, shareID string) error {
	userUUID, err1 := uuid.Parse(userID)
	shareUUID, err2 := uuid.Parse(shareID)

	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("failed to begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. Find the screen share to get session_id
	var sessionID string
	err = tx.QueryRow(ctx, "SELECT session_id FROM public.screen_shares WHERE id = $1 AND user_id = $2 AND ended_at IS NULL", shareUUID, userUUID).Scan(&sessionID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("active screen share not found or unauthorized")
		}
		return fmt.Errorf("failed to query screen share: %w", err)
	}

	// 2. Mark screen share ended
	_, err = tx.Exec(ctx, "UPDATE public.screen_shares SET ended_at = NOW() WHERE id = $1", shareUUID)
	if err != nil {
		return fmt.Errorf("failed to end screen share: %w", err)
	}

	// 3. Mark voice state is_streaming = false
	_, err = tx.Exec(ctx, "UPDATE public.voice_states SET is_streaming = false, updated_at = NOW() WHERE session_id = $1", sessionID)
	if err != nil {
		return fmt.Errorf("failed to update stream voice state: %w", err)
	}

	return tx.Commit(ctx)
}

func (s *screenShareService) GetActiveScreenShares(ctx context.Context, channelID string) ([]*models.ScreenShare, error) {
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		return nil, fmt.Errorf("invalid channel uuid")
	}

	query := `
		SELECT id, user_id, channel_id, session_id, share_type, resolution, frame_rate, viewer_count, started_at, ended_at
		FROM public.screen_shares
		WHERE channel_id = $1 AND ended_at IS NULL
		ORDER BY started_at ASC
	`
	rows, err := s.db.Query(ctx, query, channelUUID)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var shares []*models.ScreenShare
	for rows.Next() {
		sh := &models.ScreenShare{}
		if err := rows.Scan(&sh.ID, &sh.UserID, &sh.ChannelID, &sh.SessionID, &sh.ShareType, &sh.Resolution, &sh.FrameRate, &sh.ViewerCount, &sh.StartedAt, &sh.EndedAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		shares = append(shares, sh)
	}

	return shares, nil
}
