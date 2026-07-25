package repo

import (
	"context"
	"errors"
	"time"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

type ChannelBackgroundRepo interface {
	Insert(ctx context.Context, bg *models.ChannelBackground) error
	Update(ctx context.Context, bg *models.ChannelBackground) error
	GetByChannelID(ctx context.Context, channelID string) (*models.ChannelBackground, error)
	Delete(ctx context.Context, channelID string) error
	UpsertOverride(ctx context.Context, o *models.ChannelBackgroundUserOverride) error
	GetOverride(ctx context.Context, userID, channelID string) (*models.ChannelBackgroundUserOverride, error)
}

type channelBackgroundRepo struct {
	db database.DatabaseClient
}

func NewChannelBackgroundRepo(db database.DatabaseClient) ChannelBackgroundRepo {
	return &channelBackgroundRepo{db: db}
}

func (r *channelBackgroundRepo) Insert(ctx context.Context, bg *models.ChannelBackground) error {
	const q = `
		INSERT INTO public.channel_backgrounds (
			id, channel_id, server_id, uploader_id,
			file_id_original, file_id_mobile, file_id_blurred, blurhash,
			width_px, height_px, bytes_original, mime_type, sha256,
			dominant_color, mean_luminance, min_text_contrast, focal_x, focal_y,
			status, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21
		)
	`
	now := time.Now().UTC()
	if bg.CreatedAt.IsZero() {
		bg.CreatedAt = now
	}
	if bg.UpdatedAt.IsZero() {
		bg.UpdatedAt = now
	}

	_, err := r.db.Exec(ctx, q,
		bg.ID, bg.ChannelID, bg.ServerID, bg.UploaderID,
		bg.FileIDOriginal, bg.FileIDMobile, bg.FileIDBlurred, bg.BlurHash,
		bg.WidthPx, bg.HeightPx, bg.BytesOriginal, bg.MimeType, bg.Sha256,
		bg.DominantColor, bg.MeanLuminance, bg.MinTextContrast, bg.FocalX, bg.FocalY,
		bg.Status, bg.CreatedAt, bg.UpdatedAt,
	)
	return err
}

func (r *channelBackgroundRepo) Update(ctx context.Context, bg *models.ChannelBackground) error {
	const q = `
		UPDATE public.channel_backgrounds
		SET file_id_mobile = $1,
		    file_id_blurred = $2,
		    blurhash = $3,
		    status = $4,
		    updated_at = NOW()
		WHERE id = $5
	`
	tag, err := r.db.Exec(ctx, q, bg.FileIDMobile, bg.FileIDBlurred, bg.BlurHash, bg.Status, bg.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("channel background not found for update")
	}
	return nil
}

func (r *channelBackgroundRepo) GetByChannelID(ctx context.Context, channelID string) (*models.ChannelBackground, error) {
	const q = `
		SELECT id, channel_id, server_id, uploader_id,
		       file_id_original, file_id_mobile, file_id_blurred, blurhash,
		       width_px, height_px, bytes_original, mime_type, sha256,
		       dominant_color, mean_luminance, min_text_contrast, focal_x, focal_y,
		       status, created_at, updated_at
		FROM public.channel_backgrounds
		WHERE channel_id = $1
	`
	var bg models.ChannelBackground
	row := r.db.QueryRow(ctx, q, channelID)
	err := row.Scan(
		&bg.ID, &bg.ChannelID, &bg.ServerID, &bg.UploaderID,
		&bg.FileIDOriginal, &bg.FileIDMobile, &bg.FileIDBlurred, &bg.BlurHash,
		&bg.WidthPx, &bg.HeightPx, &bg.BytesOriginal, &bg.MimeType, &bg.Sha256,
		&bg.DominantColor, &bg.MeanLuminance, &bg.MinTextContrast, &bg.FocalX, &bg.FocalY,
		&bg.Status, &bg.CreatedAt, &bg.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &bg, nil
}

func (r *channelBackgroundRepo) Delete(ctx context.Context, channelID string) error {
	const q = `
		DELETE FROM public.channel_backgrounds
		WHERE channel_id = $1
	`
	_, err := r.db.Exec(ctx, q, channelID)
	return err
}

func (r *channelBackgroundRepo) UpsertOverride(ctx context.Context, o *models.ChannelBackgroundUserOverride) error {
	const q = `
		INSERT INTO public.channel_background_user_overrides (user_id, channel_id, opacity, enabled, updated_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id, channel_id)
		DO UPDATE SET opacity = EXCLUDED.opacity, enabled = EXCLUDED.enabled, updated_at = NOW()
	`
	_, err := r.db.Exec(ctx, q, o.UserID, o.ChannelID, o.Opacity, o.Enabled)
	return err
}

func (r *channelBackgroundRepo) GetOverride(ctx context.Context, userID, channelID string) (*models.ChannelBackgroundUserOverride, error) {
	const q = `
		SELECT user_id, channel_id, opacity, enabled, updated_at
		FROM public.channel_background_user_overrides
		WHERE user_id = $1 AND channel_id = $2
	`
	var o models.ChannelBackgroundUserOverride
	row := r.db.QueryRow(ctx, q, userID, channelID)
	err := row.Scan(&o.UserID, &o.ChannelID, &o.Opacity, &o.Enabled, &o.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &o, nil
}
