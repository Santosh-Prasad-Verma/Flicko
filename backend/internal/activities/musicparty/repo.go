package musicparty

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository defines the database operations for Music Party.
type Repository interface {
	// Sessions
	CreateSession(ctx context.Context, session *MPSession) error
	GetSession(ctx context.Context, id string) (*MPSession, error)
	UpdateSession(ctx context.Context, session *MPSession) error
	EndSession(ctx context.Context, id string) error
	GetActiveSessionByRoom(ctx context.Context, roomID uuid.UUID) (*MPSession, error)

	// Participants
	AddParticipant(ctx context.Context, p *MPParticipant) error
	RemoveParticipant(ctx context.Context, sessionID string, userID uuid.UUID) error
	GetActiveParticipants(ctx context.Context, sessionID string) ([]*MPParticipant, error)
	GetParticipant(ctx context.Context, sessionID string, userID uuid.UUID) (*MPParticipant, error)
	CountActiveListeners(ctx context.Context, sessionID string) (int, error)

	// Queue
	AddQueueItem(ctx context.Context, item *MPQueueItem) error
	GetQueueItems(ctx context.Context, sessionID string) ([]*MPQueueItem, error)
	GetQueueItem(ctx context.Context, itemID string) (*MPQueueItem, error)
	UpdateQueueItem(ctx context.Context, item *MPQueueItem) error
	RemoveQueueItem(ctx context.Context, itemID string) error
	GetNextQueueItem(ctx context.Context, sessionID string) (*MPQueueItem, error)

	// Vibes
	AddVibe(ctx context.Context, vibe *MPVibe) error
	CountVibesByKind(ctx context.Context, sessionID string, queueItemID string, kind VibeKind) (int, error)
	HasUserVibedForTrack(ctx context.Context, queueItemID string, userID uuid.UUID, kind VibeKind) (bool, error)
}

// postgresRepo implements Repository using pgxpool.
type postgresRepo struct {
	db *pgxpool.Pool
}

// NewRepository creates a new database repository.
func NewRepository(db *pgxpool.Pool) Repository {
	return &postgresRepo{db: db}
}

// ── Sessions ───────────────────────────────────────────────────

func (r *postgresRepo) CreateSession(ctx context.Context, s *MPSession) error {
	settingsJSON, err := json.Marshal(s.Settings)
	if err != nil {
		return err
	}

	query := `INSERT INTO public.mp_sessions
		(id, room_id, dj_user_id, next_dj_user_id, rotation_mode, state,
		 current_track_uri, current_position_ms, current_started_at,
		 anchor_wall_ms, seq, settings, created_at, updated_at, last_active_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`

	_, err = r.db.Exec(ctx, query,
		s.ID, s.RoomID, s.DJUserID, s.NextDJUserID, s.RotationMode, s.State,
		s.CurrentTrackURI, s.CurrentPositionMS, s.CurrentStartedAt,
		s.AnchorWallMS, s.Seq, settingsJSON, s.CreatedAt, s.UpdatedAt, s.LastActiveAt,
	)
	return err
}

func (r *postgresRepo) GetSession(ctx context.Context, id string) (*MPSession, error) {
	query := `SELECT id, room_id, dj_user_id, next_dj_user_id, rotation_mode, state,
		current_track_uri, current_position_ms, current_started_at,
		anchor_wall_ms, seq, settings, created_at, updated_at, ended_at, last_active_at
		FROM public.mp_sessions WHERE id = $1`

	var s MPSession
	var settingsJSON []byte
	var nextDJID *uuid.UUID

	err := r.db.QueryRow(ctx, query, id).Scan(
		&s.ID, &s.RoomID, &s.DJUserID, &nextDJID, &s.RotationMode, &s.State,
		&s.CurrentTrackURI, &s.CurrentPositionMS, &s.CurrentStartedAt,
		&s.AnchorWallMS, &s.Seq, &settingsJSON, &s.CreatedAt, &s.UpdatedAt,
		&s.EndedAt, &s.LastActiveAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("session not found")
		}
		return nil, err
	}

	s.NextDJUserID = nextDJID
	if err := json.Unmarshal(settingsJSON, &s.Settings); err != nil {
		return nil, err
	}

	return &s, nil
}

func (r *postgresRepo) UpdateSession(ctx context.Context, s *MPSession) error {
	settingsJSON, err := json.Marshal(s.Settings)
	if err != nil {
		return err
	}

	query := `UPDATE public.mp_sessions SET
		dj_user_id = $2, next_dj_user_id = $3, rotation_mode = $4, state = $5,
		current_track_uri = $6, current_position_ms = $7, current_started_at = $8,
		anchor_wall_ms = $9, seq = $10, settings = $11, last_active_at = now()
		WHERE id = $1`

	_, err = r.db.Exec(ctx, query,
		s.ID, s.DJUserID, s.NextDJUserID, s.RotationMode, s.State,
		s.CurrentTrackURI, s.CurrentPositionMS, s.CurrentStartedAt,
		s.AnchorWallMS, s.Seq, settingsJSON,
	)
	return err
}

func (r *postgresRepo) EndSession(ctx context.Context, id string) error {
	query := `UPDATE public.mp_sessions SET state = 'ended', ended_at = now() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id)
	return err
}

func (r *postgresRepo) GetActiveSessionByRoom(ctx context.Context, roomID uuid.UUID) (*MPSession, error) {
	query := `SELECT id, room_id, dj_user_id, next_dj_user_id, rotation_mode, state,
		current_track_uri, current_position_ms, current_started_at,
		anchor_wall_ms, seq, settings, created_at, updated_at, ended_at, last_active_at
		FROM public.mp_sessions
		WHERE room_id = $1 AND state IN ('draft', 'ready', 'playing', 'paused', 'degraded')
		ORDER BY created_at DESC LIMIT 1`

	var s MPSession
	var settingsJSON []byte
	var nextDJID *uuid.UUID

	err := r.db.QueryRow(ctx, query, roomID).Scan(
		&s.ID, &s.RoomID, &s.DJUserID, &nextDJID, &s.RotationMode, &s.State,
		&s.CurrentTrackURI, &s.CurrentPositionMS, &s.CurrentStartedAt,
		&s.AnchorWallMS, &s.Seq, &settingsJSON, &s.CreatedAt, &s.UpdatedAt,
		&s.EndedAt, &s.LastActiveAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	s.NextDJUserID = nextDJID
	if err := json.Unmarshal(settingsJSON, &s.Settings); err != nil {
		return nil, err
	}

	return &s, nil
}

// ── Participants ───────────────────────────────────────────────

func (r *postgresRepo) AddParticipant(ctx context.Context, p *MPParticipant) error {
	query := `INSERT INTO public.mp_participants
		(session_id, user_id, role, spotify_tier, joined_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (session_id, user_id)
		DO UPDATE SET left_at = NULL, role = $3, spotify_tier = $4, joined_at = now()`

	_, err := r.db.Exec(ctx, query, p.SessionID, p.UserID, p.Role, p.SpotifyTier, p.JoinedAt)
	return err
}

func (r *postgresRepo) RemoveParticipant(ctx context.Context, sessionID string, userID uuid.UUID) error {
	query := `UPDATE public.mp_participants SET left_at = now()
		WHERE session_id = $1 AND user_id = $2 AND left_at IS NULL`
	_, err := r.db.Exec(ctx, query, sessionID, userID)
	return err
}

func (r *postgresRepo) GetActiveParticipants(ctx context.Context, sessionID string) ([]*MPParticipant, error) {
	query := `SELECT id, session_id, user_id, role, spotify_tier, joined_at, left_at
		FROM public.mp_participants
		WHERE session_id = $1 AND left_at IS NULL
		ORDER BY joined_at ASC`

	rows, err := r.db.Query(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var participants []*MPParticipant
	for rows.Next() {
		var p MPParticipant
		if err := rows.Scan(&p.ID, &p.SessionID, &p.UserID, &p.Role, &p.SpotifyTier, &p.JoinedAt, &p.LeftAt); err != nil {
			return nil, err
		}
		participants = append(participants, &p)
	}
	return participants, rows.Err()
}

func (r *postgresRepo) GetParticipant(ctx context.Context, sessionID string, userID uuid.UUID) (*MPParticipant, error) {
	query := `SELECT id, session_id, user_id, role, spotify_tier, joined_at, left_at
		FROM public.mp_participants
		WHERE session_id = $1 AND user_id = $2 AND left_at IS NULL`

	var p MPParticipant
	err := r.db.QueryRow(ctx, query, sessionID, userID).Scan(
		&p.ID, &p.SessionID, &p.UserID, &p.Role, &p.SpotifyTier, &p.JoinedAt, &p.LeftAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &p, nil
}

func (r *postgresRepo) CountActiveListeners(ctx context.Context, sessionID string) (int, error) {
	query := `SELECT COUNT(*) FROM public.mp_participants
		WHERE session_id = $1 AND left_at IS NULL`
	var count int
	err := r.db.QueryRow(ctx, query, sessionID).Scan(&count)
	return count, err
}

// ── Queue ──────────────────────────────────────────────────────

func (r *postgresRepo) AddQueueItem(ctx context.Context, item *MPQueueItem) error {
	query := `INSERT INTO public.mp_queue
		(id, session_id, spotify_uri, title, artist, duration_ms, album_art_url,
		 preview_url, added_by_user_id, position, state, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`

	_, err := r.db.Exec(ctx, query,
		item.ID, item.SessionID, item.SpotifyURI, item.Title, item.Artist,
		item.DurationMS, item.AlbumArtURL, item.PreviewURL, item.AddedByUserID,
		item.Position, item.State, item.CreatedAt,
	)
	return err
}

func (r *postgresRepo) GetQueueItems(ctx context.Context, sessionID string) ([]*MPQueueItem, error) {
	query := `SELECT id, session_id, spotify_uri, title, artist, duration_ms,
		album_art_url, preview_url, added_by_user_id, position, state,
		created_at, played_at, ended_at
		FROM public.mp_queue
		WHERE session_id = $1 AND state IN ('queued', 'playing')
		ORDER BY position ASC`

	rows, err := r.db.Query(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*MPQueueItem
	for rows.Next() {
		var item MPQueueItem
		if err := rows.Scan(
			&item.ID, &item.SessionID, &item.SpotifyURI, &item.Title, &item.Artist,
			&item.DurationMS, &item.AlbumArtURL, &item.PreviewURL, &item.AddedByUserID,
			&item.Position, &item.State, &item.CreatedAt, &item.PlayedAt, &item.EndedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, &item)
	}
	return items, rows.Err()
}

func (r *postgresRepo) GetQueueItem(ctx context.Context, itemID string) (*MPQueueItem, error) {
	query := `SELECT id, session_id, spotify_uri, title, artist, duration_ms,
		album_art_url, preview_url, added_by_user_id, position, state,
		created_at, played_at, ended_at
		FROM public.mp_queue WHERE id = $1`

	var item MPQueueItem
	err := r.db.QueryRow(ctx, query, itemID).Scan(
		&item.ID, &item.SessionID, &item.SpotifyURI, &item.Title, &item.Artist,
		&item.DurationMS, &item.AlbumArtURL, &item.PreviewURL, &item.AddedByUserID,
		&item.Position, &item.State, &item.CreatedAt, &item.PlayedAt, &item.EndedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

func (r *postgresRepo) UpdateQueueItem(ctx context.Context, item *MPQueueItem) error {
	query := `UPDATE public.mp_queue SET
		position = $2, state = $3, played_at = $4, ended_at = $5
		WHERE id = $1`

	_, err := r.db.Exec(ctx, query,
		item.ID, item.Position, item.State, item.PlayedAt, item.EndedAt,
	)
	return err
}

func (r *postgresRepo) RemoveQueueItem(ctx context.Context, itemID string) error {
	now := time.Now()
	query := `UPDATE public.mp_queue SET state = 'removed', ended_at = $2 WHERE id = $1`
	_, err := r.db.Exec(ctx, query, itemID, now)
	return err
}

func (r *postgresRepo) GetNextQueueItem(ctx context.Context, sessionID string) (*MPQueueItem, error) {
	query := `SELECT id, session_id, spotify_uri, title, artist, duration_ms,
		album_art_url, preview_url, added_by_user_id, position, state,
		created_at, played_at, ended_at
		FROM public.mp_queue
		WHERE session_id = $1 AND state = 'queued'
		ORDER BY position ASC LIMIT 1`

	var item MPQueueItem
	err := r.db.QueryRow(ctx, query, sessionID).Scan(
		&item.ID, &item.SessionID, &item.SpotifyURI, &item.Title, &item.Artist,
		&item.DurationMS, &item.AlbumArtURL, &item.PreviewURL, &item.AddedByUserID,
		&item.Position, &item.State, &item.CreatedAt, &item.PlayedAt, &item.EndedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

// ── Vibes ──────────────────────────────────────────────────────

func (r *postgresRepo) AddVibe(ctx context.Context, vibe *MPVibe) error {
	query := `INSERT INTO public.mp_vibes
		(session_id, queue_item_id, user_id, kind, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (queue_item_id, user_id, kind) DO NOTHING`

	_, err := r.db.Exec(ctx, query,
		vibe.SessionID, vibe.QueueItemID, vibe.UserID, vibe.Kind, vibe.CreatedAt,
	)
	return err
}

func (r *postgresRepo) CountVibesByKind(ctx context.Context, sessionID string, queueItemID string, kind VibeKind) (int, error) {
	query := `SELECT COUNT(*) FROM public.mp_vibes
		WHERE session_id = $1 AND queue_item_id = $2 AND kind = $3`
	var count int
	err := r.db.QueryRow(ctx, query, sessionID, queueItemID, kind).Scan(&count)
	return count, err
}

func (r *postgresRepo) HasUserVibedForTrack(ctx context.Context, queueItemID string, userID uuid.UUID, kind VibeKind) (bool, error) {
	query := `SELECT EXISTS(
		SELECT 1 FROM public.mp_vibes
		WHERE queue_item_id = $1 AND user_id = $2 AND kind = $3
	)`
	var exists bool
	err := r.db.QueryRow(ctx, query, queueItemID, userID, kind).Scan(&exists)
	return exists, err
}
