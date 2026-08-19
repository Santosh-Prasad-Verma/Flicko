package services

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type StickerService interface {
	UploadSticker(ctx context.Context, serverID, creatorID, name string, description *string, tags []string, filename string, size int64, file io.Reader) (*models.Sticker, error)
	GetStickers(ctx context.Context, serverID string) ([]*models.Sticker, error)
	DeleteSticker(ctx context.Context, serverID, stickerID, userID string) error
	TrackUsage(ctx context.Context, stickerID string) error
}

type stickerService struct {
	db          *pgxpool.Pool
	permService PermissionService
}

func NewStickerService(db *pgxpool.Pool, permService PermissionService) StickerService {
	return &stickerService{
		db:          db,
		permService: permService,
	}
}

func (s *stickerService) UploadSticker(ctx context.Context, serverID, creatorID, name string, description *string, tags []string, filename string, size int64, file io.Reader) (*models.Sticker, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	creatorUUID, err2 := uuid.Parse(creatorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	if size > 512*1024 {
		return nil, fmt.Errorf("sticker file size must be <= 512KB")
	}

	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".png" && ext != ".apng" && ext != ".gif" {
		return nil, fmt.Errorf("invalid sticker format: must be PNG, APNG, or GIF")
	}

	var boostLevel int
	err := s.db.QueryRow(ctx, "SELECT boost_level FROM public.server_boost_status WHERE server_id = $1", serverUUID).Scan(&boostLevel)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("server is not boosted enough to upload stickers")
		}
		return nil, fmt.Errorf("failed to verify server boost level: %w", err)
	}
	if boostLevel < 1 {
		return nil, fmt.Errorf("server boost level must be at least 1 to upload stickers")
	}

	hasPerm, err := s.permService.HasPermission(ctx, creatorUUID, serverUUID, "MANAGE_EMOJIS")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_EMOJIS permission")
	}

	stickerID := uuid.New()
	storagePath := fmt.Sprintf("%s/%s%s", serverID, stickerID.String(), ext)
	imageURL := fmt.Sprintf("/storage/stickers/%s", storagePath)

	query := `
		INSERT INTO public.stickers (id, server_id, name, description, tags, image_url, creator_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, server_id, name, description, tags, image_url, creator_id, usage_count, created_at, updated_at
	`
	var st models.Sticker
	err = s.db.QueryRow(ctx, query, stickerID, serverUUID, name, description, tags, imageURL, creatorUUID).
		Scan(&st.ID, &st.ServerID, &st.Name, &st.Description, &st.Tags, &st.ImageURL, &st.CreatorID, &st.UsageCount, &st.CreatedAt, &st.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert sticker to db: %w", err)
	}

	return &st, nil
}

func (s *stickerService) GetStickers(ctx context.Context, serverID string) ([]*models.Sticker, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server uuid")
	}

	rows, err := s.db.Query(ctx, "SELECT id, server_id, name, description, tags, image_url, creator_id, usage_count, created_at, updated_at FROM public.stickers WHERE server_id = $1 ORDER BY created_at DESC", serverUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stickers []*models.Sticker
	for rows.Next() {
		st := &models.Sticker{}
		if err := rows.Scan(&st.ID, &st.ServerID, &st.Name, &st.Description, &st.Tags, &st.ImageURL, &st.CreatorID, &st.UsageCount, &st.CreatedAt, &st.UpdatedAt); err != nil {
			return nil, err
		}
		stickers = append(stickers, st)
	}
	return stickers, nil
}

func (s *stickerService) DeleteSticker(ctx context.Context, serverID, stickerID, userID string) error {
	serverUUID, err1 := uuid.Parse(serverID)
	stickerUUID, err2 := uuid.Parse(stickerID)
	userUUID, err3 := uuid.Parse(userID)
	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, userUUID, serverUUID, "MANAGE_EMOJIS")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_EMOJIS")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.stickers WHERE id = $1 AND server_id = $2", stickerUUID, serverUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("sticker not found")
	}

	return nil
}

func (s *stickerService) TrackUsage(ctx context.Context, stickerID string) error {
	stickerUUID, err := uuid.Parse(stickerID)
	if err != nil {
		return fmt.Errorf("invalid sticker id")
	}

	_, err = s.db.Exec(ctx, "UPDATE public.stickers SET usage_count = usage_count + 1 WHERE id = $1", stickerUUID)
	return err
}
