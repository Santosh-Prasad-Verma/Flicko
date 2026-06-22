package watchtogether

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository interface {
	CreateSession(ctx context.Context, session *WTSession) error
	GetSession(ctx context.Context, id string) (*WTSession, error)
	UpdateSession(ctx context.Context, session *WTSession) error
	GetActiveSessionForRoom(ctx context.Context, roomID uuid.UUID) (*WTSession, error)
	GetPublicLobbies(ctx context.Context) ([]*WTSession, error)
	AddParticipant(ctx context.Context, p *WTParticipant) error
	GetParticipants(ctx context.Context, sessionID string) ([]*WTParticipant, error)
	MarkParticipantLeft(ctx context.Context, sessionID string, userID uuid.UUID) error
	GetOldestActiveParticipant(ctx context.Context, sessionID string) (*WTParticipant, error)
}

type postgresRepo struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) Repository {
	return &postgresRepo{db: db}
}

func (r *postgresRepo) CreateSession(ctx context.Context, s *WTSession) error {
	var roomID *uuid.UUID
	if s.RoomID != uuid.Nil {
		roomID = &s.RoomID
	}
	query := `
		INSERT INTO public.wt_sessions (
			id, room_id, host_user_id, media_kind, media_url, media_title, media_duration_ms, 
			settings, state, anchor_position_ms, anchor_playing, anchor_rate, anchor_wall_ms, 
			seq, is_standalone, is_public, lobby_name, created_at, updated_at, last_active_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
	`
	_, err := r.db.Exec(ctx, query,
		s.ID, roomID, s.HostUserID, s.MediaKind, s.MediaURL, s.MediaTitle, s.MediaDurationMS,
		s.Settings, s.State, s.AnchorPositionMS, s.AnchorPlaying, s.AnchorRate, s.AnchorWallMS,
		s.Seq, s.IsStandalone, s.IsPublic, s.LobbyName, s.CreatedAt, s.UpdatedAt, s.LastActiveAt,
	)
	return err
}

func (r *postgresRepo) GetSession(ctx context.Context, id string) (*WTSession, error) {
	query := `
		SELECT 
			id, room_id, host_user_id, media_kind, media_url, media_title, media_duration_ms, 
			settings, state, anchor_position_ms, anchor_playing, anchor_rate, anchor_wall_ms, 
			seq, is_standalone, is_public, lobby_name, created_at, updated_at, ended_at, last_active_at
		FROM public.wt_sessions
		WHERE id = $1
	`
	var s WTSession
	var roomID *uuid.UUID
	err := r.db.QueryRow(ctx, query, id).Scan(
		&s.ID, &roomID, &s.HostUserID, &s.MediaKind, &s.MediaURL, &s.MediaTitle, &s.MediaDurationMS,
		&s.Settings, &s.State, &s.AnchorPositionMS, &s.AnchorPlaying, &s.AnchorRate, &s.AnchorWallMS,
		&s.Seq, &s.IsStandalone, &s.IsPublic, &s.LobbyName, &s.CreatedAt, &s.UpdatedAt, &s.EndedAt, &s.LastActiveAt,
	)
	if err == pgx.ErrNoRows {
		return nil, errors.New("session not found")
	}
	if roomID != nil {
		s.RoomID = *roomID
	} else {
		s.RoomID = uuid.Nil
	}
	return &s, err
}

func (r *postgresRepo) UpdateSession(ctx context.Context, s *WTSession) error {
	var roomID *uuid.UUID
	if s.RoomID != uuid.Nil {
		roomID = &s.RoomID
	}
	query := `
		UPDATE public.wt_sessions
		SET 
			room_id = $1,
			host_user_id = $2, 
			media_kind = $3, 
			media_url = $4, 
			media_title = $5, 
			media_duration_ms = $6,
			settings = $7, 
			state = $8, 
			anchor_position_ms = $9, 
			anchor_playing = $10, 
			anchor_rate = $11, 
			anchor_wall_ms = $12,
			seq = $13, 
			is_standalone = $14,
			is_public = $15,
			lobby_name = $16,
			ended_at = $17, 
			last_active_at = $18
		WHERE id = $19
	`
	_, err := r.db.Exec(ctx, query,
		roomID, s.HostUserID, s.MediaKind, s.MediaURL, s.MediaTitle, s.MediaDurationMS,
		s.Settings, s.State, s.AnchorPositionMS, s.AnchorPlaying, s.AnchorRate, s.AnchorWallMS,
		s.Seq, s.IsStandalone, s.IsPublic, s.LobbyName, s.EndedAt, s.LastActiveAt, s.ID,
	)
	return err
}

func (r *postgresRepo) GetActiveSessionForRoom(ctx context.Context, roomID uuid.UUID) (*WTSession, error) {
	query := `
		SELECT 
			id, room_id, host_user_id, media_kind, media_url, media_title, media_duration_ms, 
			settings, state, anchor_position_ms, anchor_playing, anchor_rate, anchor_wall_ms, 
			seq, is_standalone, is_public, lobby_name, created_at, updated_at, ended_at, last_active_at
		FROM public.wt_sessions
		WHERE room_id = $1 AND state IN ('ready', 'playing', 'paused')
		LIMIT 1
	`
	var s WTSession
	var rID *uuid.UUID
	err := r.db.QueryRow(ctx, query, roomID).Scan(
		&s.ID, &rID, &s.HostUserID, &s.MediaKind, &s.MediaURL, &s.MediaTitle, &s.MediaDurationMS,
		&s.Settings, &s.State, &s.AnchorPositionMS, &s.AnchorPlaying, &s.AnchorRate, &s.AnchorWallMS,
		&s.Seq, &s.IsStandalone, &s.IsPublic, &s.LobbyName, &s.CreatedAt, &s.UpdatedAt, &s.EndedAt, &s.LastActiveAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil // No active session
	}
	if rID != nil {
		s.RoomID = *rID
	} else {
		s.RoomID = uuid.Nil
	}
	return &s, err
}

func (r *postgresRepo) GetPublicLobbies(ctx context.Context) ([]*WTSession, error) {
	query := `
		SELECT 
			id, room_id, host_user_id, media_kind, media_url, media_title, media_duration_ms, 
			settings, state, anchor_position_ms, anchor_playing, anchor_rate, anchor_wall_ms, 
			seq, is_standalone, is_public, lobby_name, created_at, updated_at, ended_at, last_active_at
		FROM public.wt_sessions
		WHERE is_public = true AND state IN ('ready', 'playing', 'paused')
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []*WTSession
	for rows.Next() {
		var s WTSession
		var rID *uuid.UUID
		err := rows.Scan(
			&s.ID, &rID, &s.HostUserID, &s.MediaKind, &s.MediaURL, &s.MediaTitle, &s.MediaDurationMS,
			&s.Settings, &s.State, &s.AnchorPositionMS, &s.AnchorPlaying, &s.AnchorRate, &s.AnchorWallMS,
			&s.Seq, &s.IsStandalone, &s.IsPublic, &s.LobbyName, &s.CreatedAt, &s.UpdatedAt, &s.EndedAt, &s.LastActiveAt,
		)
		if err != nil {
			return nil, err
		}
		if rID != nil {
			s.RoomID = *rID
		} else {
			s.RoomID = uuid.Nil
		}
		sessions = append(sessions, &s)
	}
	return sessions, rows.Err()
}

func (r *postgresRepo) AddParticipant(ctx context.Context, p *WTParticipant) error {
	query := `
		INSERT INTO public.wt_participants (session_id, user_id, role, joined_at, left_at, last_drift_ms)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (session_id, user_id) 
		DO UPDATE SET left_at = NULL, joined_at = now()
	`
	_, err := r.db.Exec(ctx, query, p.SessionID, p.UserID, p.Role, p.JoinedAt, p.LeftAt, p.LastDriftMS)
	return err
}

func (r *postgresRepo) GetParticipants(ctx context.Context, sessionID string) ([]*WTParticipant, error) {
	query := `
		SELECT id, session_id, user_id, role, joined_at, left_at, last_drift_ms
		FROM public.wt_participants
		WHERE session_id = $1 AND left_at IS NULL
	`
	rows, err := r.db.Query(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var participants []*WTParticipant
	for rows.Next() {
		var p WTParticipant
		if err := rows.Scan(&p.ID, &p.SessionID, &p.UserID, &p.Role, &p.JoinedAt, &p.LeftAt, &p.LastDriftMS); err != nil {
			return nil, err
		}
		participants = append(participants, &p)
	}
	return participants, rows.Err()
}

func (r *postgresRepo) MarkParticipantLeft(ctx context.Context, sessionID string, userID uuid.UUID) error {
	query := `
		UPDATE public.wt_participants
		SET left_at = now()
		WHERE session_id = $1 AND user_id = $2
	`
	_, err := r.db.Exec(ctx, query, sessionID, userID)
	return err
}

func (r *postgresRepo) GetOldestActiveParticipant(ctx context.Context, sessionID string) (*WTParticipant, error) {
	query := `
		SELECT id, session_id, user_id, role, joined_at, left_at, last_drift_ms
		FROM public.wt_participants
		WHERE session_id = $1 AND left_at IS NULL
		ORDER BY joined_at ASC, user_id ASC
		LIMIT 1
	`
	var p WTParticipant
	err := r.db.QueryRow(ctx, query, sessionID).Scan(&p.ID, &p.SessionID, &p.UserID, &p.Role, &p.JoinedAt, &p.LeftAt, &p.LastDriftMS)
	if err == sql.ErrNoRows || err == pgx.ErrNoRows {
		return nil, fmt.Errorf("no active participants found")
	}
	return &p, err
}
