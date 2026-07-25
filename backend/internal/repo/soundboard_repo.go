package repo

import (
	"context"
	"errors"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

type SoundboardRepo interface {
	InsertSound(ctx context.Context, sound *models.SoundboardSound) error
	GetSoundsByServerID(ctx context.Context, serverID string) ([]*models.SoundboardSound, error)
	GetSoundByID(ctx context.Context, id string) (*models.SoundboardSound, error)
	DeleteSound(ctx context.Context, id string) error
	IncrementPlayCount(ctx context.Context, id string) error
	InsertFavorite(ctx context.Context, userID, soundID string) error
	DeleteFavorite(ctx context.Context, userID, soundID string) error
	GetFavoritesByUserID(ctx context.Context, userID string) ([]*models.SoundboardSound, error)
}

type soundboardRepo struct {
	db database.DatabaseClient
}

func NewSoundboardRepo(db database.DatabaseClient) SoundboardRepo {
	return &soundboardRepo{db: db}
}

func (r *soundboardRepo) InsertSound(ctx context.Context, s *models.SoundboardSound) error {
	const q = `
		INSERT INTO public.soundboard_sounds (
			id, server_id, name, emoji, sound_url, duration, uploaded_by, play_count, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()
		)
	`
	_, err := r.db.Exec(ctx, q, s.ID, s.ServerID, s.Name, s.Emoji, s.SoundURL, s.Duration, s.UploadedBy, s.PlayCount)
	return err
}

func (r *soundboardRepo) GetSoundsByServerID(ctx context.Context, serverID string) ([]*models.SoundboardSound, error) {
	const q = `
		SELECT id, server_id, name, emoji, sound_url, duration, uploaded_by, play_count, created_at, updated_at
		FROM public.soundboard_sounds
		WHERE server_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, q, serverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sounds []*models.SoundboardSound
	for rows.Next() {
		var s models.SoundboardSound
		err := rows.Scan(&s.ID, &s.ServerID, &s.Name, &s.Emoji, &s.SoundURL, &s.Duration, &s.UploadedBy, &s.PlayCount, &s.CreatedAt, &s.UpdatedAt)
		if err != nil {
			return nil, err
		}
		sounds = append(sounds, &s)
	}
	return sounds, nil
}

func (r *soundboardRepo) GetSoundByID(ctx context.Context, id string) (*models.SoundboardSound, error) {
	const q = `
		SELECT id, server_id, name, emoji, sound_url, duration, uploaded_by, play_count, created_at, updated_at
		FROM public.soundboard_sounds
		WHERE id = $1
	`
	var s models.SoundboardSound
	row := r.db.QueryRow(ctx, q, id)
	err := row.Scan(&s.ID, &s.ServerID, &s.Name, &s.Emoji, &s.SoundURL, &s.Duration, &s.UploadedBy, &s.PlayCount, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &s, nil
}

func (r *soundboardRepo) DeleteSound(ctx context.Context, id string) error {
	const q = `
		DELETE FROM public.soundboard_sounds
		WHERE id = $1
	`
	tag, err := r.db.Exec(ctx, q, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *soundboardRepo) IncrementPlayCount(ctx context.Context, id string) error {
	const q = `
		UPDATE public.soundboard_sounds
		SET play_count = play_count + 1,
		    updated_at = NOW()
		WHERE id = $1
	`
	tag, err := r.db.Exec(ctx, q, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *soundboardRepo) InsertFavorite(ctx context.Context, userID, soundID string) error {
	const q = `
		INSERT INTO public.soundboard_favorites (user_id, sound_id, created_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id, sound_id) DO NOTHING
	`
	_, err := r.db.Exec(ctx, q, userID, soundID)
	return err
}

func (r *soundboardRepo) DeleteFavorite(ctx context.Context, userID, soundID string) error {
	const q = `
		DELETE FROM public.soundboard_favorites
		WHERE user_id = $1 AND sound_id = $2
	`
	_, err := r.db.Exec(ctx, q, userID, soundID)
	return err
}

func (r *soundboardRepo) GetFavoritesByUserID(ctx context.Context, userID string) ([]*models.SoundboardSound, error) {
	const q = `
		SELECT s.id, s.server_id, s.name, s.emoji, s.sound_url, s.duration, s.uploaded_by, s.play_count, s.created_at, s.updated_at
		FROM public.soundboard_favorites f
		JOIN public.soundboard_sounds s ON s.id = f.sound_id
		WHERE f.user_id = $1
		ORDER BY f.created_at DESC
	`
	rows, err := r.db.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sounds []*models.SoundboardSound
	for rows.Next() {
		var s models.SoundboardSound
		err := rows.Scan(&s.ID, &s.ServerID, &s.Name, &s.Emoji, &s.SoundURL, &s.Duration, &s.UploadedBy, &s.PlayCount, &s.CreatedAt, &s.UpdatedAt)
		if err != nil {
			return nil, err
		}
		sounds = append(sounds, &s)
	}
	return sounds, nil
}
