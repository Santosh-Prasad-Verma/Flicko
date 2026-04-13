package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ──────────────────────────────────────────
// Types
// ──────────────────────────────────────────

type Stream struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	ChannelID       string     `json:"channel_id"`
	ServerID        string     `json:"server_id"`
	Title           string     `json:"title"`
	Status          string     `json:"status"`
	StreamType      string     `json:"stream_type"`
	MaxQuality      string     `json:"max_quality"`
	ActualQuality   *string    `json:"actual_quality,omitempty"`
	ViewerCount     int        `json:"viewer_count"`
	MaxViewers      int        `json:"max_viewers"`
	ApplicationName *string    `json:"application_name,omitempty"`
	ApplicationID   *string    `json:"application_id,omitempty"`
	StartedAt       time.Time  `json:"started_at"`
	EndedAt         *time.Time `json:"ended_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type StreamViewer struct {
	ID       string     `json:"id"`
	StreamID string     `json:"stream_id"`
	UserID   string     `json:"user_id"`
	JoinedAt time.Time  `json:"joined_at"`
	LeftAt   *time.Time `json:"left_at,omitempty"`
}

type CreateStreamInput struct {
	UserID     string
	ChannelID  string
	ServerID   string
	Title      string
	StreamType string
	MaxQuality string
}

// ──────────────────────────────────────────
// Errors
// ──────────────────────────────────────────

var (
	ErrStreamAlreadyActive = errors.New("user already has an active stream")
	ErrStreamNotFound      = errors.New("stream not found")
	ErrNotStreamOwner      = errors.New("not the stream owner")
	ErrStreamEnded         = errors.New("stream has already ended")
)

// ──────────────────────────────────────────
// Interface
// ──────────────────────────────────────────

type StreamService interface {
	CreateStream(ctx context.Context, input CreateStreamInput) (*Stream, error)
	StartStream(ctx context.Context, streamID, userID string) error
	EndStream(ctx context.Context, streamID, userID string) error
	JoinStreamAsViewer(ctx context.Context, streamID, userID string) error
	LeaveStream(ctx context.Context, streamID, userID string) error
	GetActiveStreams(ctx context.Context, channelID string) ([]*Stream, error)
	GetStreamViewers(ctx context.Context, streamID string) ([]*StreamViewer, error)
	CleanupStaleStreams(ctx context.Context, maxAge time.Duration) (int64, error)
}

// ──────────────────────────────────────────
// Implementation
// ──────────────────────────────────────────

type streamService struct {
	db          *pgxpool.Pool
	permService PermissionService
	voiceSvc    VoiceService
}

func NewStreamService(db *pgxpool.Pool, permService PermissionService, voiceSvc VoiceService) StreamService {
	return &streamService{
		db:          db,
		permService: permService,
		voiceSvc:    voiceSvc,
	}
}

// ──────────────────────────────────────────
// Create Stream (Go Live)
// ──────────────────────────────────────────

func (s *streamService) CreateStream(ctx context.Context, input CreateStreamInput) (*Stream, error) {
	userUUID, err := uuid.Parse(input.UserID)
	if err != nil {
		return nil, fmt.Errorf("invalid user_id: %w", err)
	}
	channelUUID, err := uuid.Parse(input.ChannelID)
	if err != nil {
		return nil, fmt.Errorf("invalid channel_id: %w", err)
	}

	// Check if user already has an active stream
	var existingCount int
	err = s.db.QueryRow(ctx,
		`SELECT count(*) FROM streams
		 WHERE user_id = $1 AND status IN ('starting', 'live')`,
		userUUID,
	).Scan(&existingCount)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing streams: %w", err)
	}
	if existingCount > 0 {
		return nil, ErrStreamAlreadyActive
	}

	// Verify user is in the voice channel
	states, err := s.voiceSvc.GetVoiceStates(ctx, input.ChannelID)
	if err != nil {
		return nil, fmt.Errorf("failed to check voice state: %w", err)
	}
	inChannel := false
	for _, st := range states {
		if st.UserID == input.UserID {
			inChannel = true
			break
		}
	}
	if !inChannel {
		return nil, fmt.Errorf("user must be in the voice channel to stream")
	}

	// Check STREAM permission
	hasPerm, err := s.permService.HasPermission(ctx, userUUID, channelUUID, "STREAM")
	if err != nil {
		return nil, fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return nil, fmt.Errorf("missing STREAM permission")
	}

	// Validate quality — downgrade 1080p to 720p for free tier
	maxQuality := input.MaxQuality
	if maxQuality == "1080p30" || maxQuality == "1080p60" {
		maxQuality = "720p30" // Free tier cap
	}

	// Insert stream
	stream := &Stream{}
	err = s.db.QueryRow(ctx,
		`INSERT INTO streams (
			user_id, channel_id, server_id, title, status,
			stream_type, max_quality, started_at
		) VALUES ($1, $2, $3, $4, 'starting', $5, $6, NOW())
		RETURNING id, user_id, channel_id, server_id, title, status,
		          stream_type, max_quality, viewer_count, max_viewers,
		          started_at, created_at, updated_at`,
		userUUID, channelUUID, uuid.MustParse(input.ServerID),
		input.Title, input.StreamType, maxQuality,
	).Scan(
		&stream.ID, &stream.UserID, &stream.ChannelID, &stream.ServerID,
		&stream.Title, &stream.Status, &stream.StreamType, &stream.MaxQuality,
		&stream.ViewerCount, &stream.MaxViewers, &stream.StartedAt,
		&stream.CreatedAt, &stream.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create stream: %w", err)
	}

	return stream, nil
}

// ──────────────────────────────────────────
// Start Stream (mark as live)
// ──────────────────────────────────────────

func (s *streamService) StartStream(ctx context.Context, streamID, userID string) error {
	streamUUID, err := uuid.Parse(streamID)
	if err != nil {
		return fmt.Errorf("invalid stream_id: %w", err)
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user_id: %w", err)
	}

	result, err := s.db.Exec(ctx,
		`UPDATE streams SET status = 'live', updated_at = NOW()
		 WHERE id = $1 AND user_id = $2 AND status = 'starting'`,
		streamUUID, userUUID,
	)
	if err != nil {
		return fmt.Errorf("failed to start stream: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrStreamNotFound
	}
	return nil
}

// ──────────────────────────────────────────
// End Stream
// ──────────────────────────────────────────

func (s *streamService) EndStream(ctx context.Context, streamID, userID string) error {
	streamUUID, err := uuid.Parse(streamID)
	if err != nil {
		return fmt.Errorf("invalid stream_id: %w", err)
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user_id: %w", err)
	}

	var channelID, ownerID string
	err = s.db.QueryRow(ctx, "SELECT channel_id, user_id FROM streams WHERE id = $1 AND status IN ('starting', 'live')", streamUUID).Scan(&channelID, &ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrStreamNotFound
		}
		return fmt.Errorf("failed to fetch stream: %w", err)
	}

	if ownerID != userID {

		eachChanUUID, _ := uuid.Parse(channelID)
		hasPerm, err := s.permService.HasPermission(ctx, userUUID, eachChanUUID, "MANAGE_CHANNELS")
		if err != nil {
			return fmt.Errorf("failed to check permission: %w", err)
		}
		if !hasPerm {
			return fmt.Errorf("unauthorized to end stream")
		}
	}

	query := "UPDATE streams SET status = 'ended', ended_at = NOW(), updated_at = NOW() WHERE id = $1 AND status IN ('starting', 'live')"
	result, err := s.db.Exec(ctx, query, streamUUID)
	if err != nil {
		return fmt.Errorf("failed to end stream: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrStreamNotFound
	}

	_, _ = s.db.Exec(ctx, "UPDATE stream_viewers SET left_at = NOW() WHERE stream_id = $1 AND left_at IS NULL", streamUUID)

	return nil
}

// ──────────────────────────────────────────
// Join/Leave Stream as Viewer
// ──────────────────────────────────────────

func (s *streamService) JoinStreamAsViewer(ctx context.Context, streamID, userID string) error {
	streamUUID, err := uuid.Parse(streamID)
	if err != nil {
		return fmt.Errorf("invalid stream_id: %w", err)
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user_id: %w", err)
	}

	// Verify stream is live
	var status string
	err = s.db.QueryRow(ctx,
		`SELECT status FROM streams WHERE id = $1`, streamUUID,
	).Scan(&status)
	if err != nil {
		if err == pgx.ErrNoRows {
			return ErrStreamNotFound
		}
		return fmt.Errorf("failed to check stream: %w", err)
	}
	if status != "live" {
		return ErrStreamEnded
	}

	// Upsert viewer (handle rejoin)
	_, err = s.db.Exec(ctx,
		`INSERT INTO stream_viewers (stream_id, user_id, joined_at)
		 VALUES ($1, $2, NOW())
		 ON CONFLICT (stream_id, user_id)
		 DO UPDATE SET joined_at = NOW(), left_at = NULL`,
		streamUUID, userUUID,
	)
	if err != nil {
		return fmt.Errorf("failed to join stream: %w", err)
	}

	return nil
}

func (s *streamService) LeaveStream(ctx context.Context, streamID, userID string) error {
	streamUUID, err := uuid.Parse(streamID)
	if err != nil {
		return fmt.Errorf("invalid stream_id: %w", err)
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user_id: %w", err)
	}

	_, err = s.db.Exec(ctx,
		`UPDATE stream_viewers SET left_at = NOW()
		 WHERE stream_id = $1 AND user_id = $2 AND left_at IS NULL`,
		streamUUID, userUUID,
	)
	if err != nil {
		return fmt.Errorf("failed to leave stream: %w", err)
	}
	return nil
}

// ──────────────────────────────────────────
// Queries
// ──────────────────────────────────────────

func (s *streamService) GetActiveStreams(ctx context.Context, channelID string) ([]*Stream, error) {
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		return nil, fmt.Errorf("invalid channel_id: %w", err)
	}

	rows, err := s.db.Query(ctx,
		`SELECT id, user_id, channel_id, server_id, title, status,
		        stream_type, max_quality, actual_quality, viewer_count,
		        max_viewers, application_name, started_at, ended_at,
		        created_at, updated_at
		 FROM streams
		 WHERE channel_id = $1 AND status IN ('starting', 'live')
		 ORDER BY started_at DESC`,
		channelUUID,
	)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var streams []*Stream
	for rows.Next() {
		stream := &Stream{}
		if err := rows.Scan(
			&stream.ID, &stream.UserID, &stream.ChannelID, &stream.ServerID,
			&stream.Title, &stream.Status, &stream.StreamType, &stream.MaxQuality,
			&stream.ActualQuality, &stream.ViewerCount, &stream.MaxViewers,
			&stream.ApplicationName, &stream.StartedAt, &stream.EndedAt,
			&stream.CreatedAt, &stream.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		streams = append(streams, stream)
	}

	return streams, nil
}

func (s *streamService) GetStreamViewers(ctx context.Context, streamID string) ([]*StreamViewer, error) {
	streamUUID, err := uuid.Parse(streamID)
	if err != nil {
		return nil, fmt.Errorf("invalid stream_id: %w", err)
	}

	rows, err := s.db.Query(ctx,
		`SELECT id, stream_id, user_id, joined_at, left_at
		 FROM stream_viewers
		 WHERE stream_id = $1 AND left_at IS NULL
		 ORDER BY joined_at ASC`,
		streamUUID,
	)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var viewers []*StreamViewer
	for rows.Next() {
		v := &StreamViewer{}
		if err := rows.Scan(&v.ID, &v.StreamID, &v.UserID, &v.JoinedAt, &v.LeftAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		viewers = append(viewers, v)
	}

	return viewers, nil
}

// ──────────────────────────────────────────
// Cleanup: End stale streams
// ──────────────────────────────────────────

func (s *streamService) CleanupStaleStreams(ctx context.Context, maxAge time.Duration) (int64, error) {
	cutoff := time.Now().Add(-maxAge)

	result, err := s.db.Exec(ctx,
		`UPDATE streams SET status = 'ended', ended_at = NOW(), updated_at = NOW()
		 WHERE status IN ('starting', 'live') AND started_at < $1`,
		cutoff,
	)
	if err != nil {
		return 0, fmt.Errorf("cleanup failed: %w", err)
	}

	return result.RowsAffected(), nil
}
