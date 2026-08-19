package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"

	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/repo"
	"github.com/google/uuid"
)

type ChannelBackgroundService interface {
	UploadBackground(ctx context.Context, channelID, serverID, userID string, file multipart.File, header *multipart.FileHeader) (*models.ChannelBackground, error)
	GetBackground(ctx context.Context, channelID string) (*models.ChannelBackground, error)
	DeleteBackground(ctx context.Context, channelID string) error
	SetOverride(ctx context.Context, userID, channelID string, opacity float32, enabled bool) error
	GetOverride(ctx context.Context, userID, channelID string) (*models.ChannelBackgroundUserOverride, error)
}

type channelBackgroundService struct {
	config *config.Config
	repo   repo.ChannelBackgroundRepo
}

func NewChannelBackgroundService(cfg *config.Config, r repo.ChannelBackgroundRepo) ChannelBackgroundService {
	return &channelBackgroundService{
		config: cfg,
		repo:   r,
	}
}

func (s *channelBackgroundService) UploadBackground(ctx context.Context, channelID, serverID, userID string, file multipart.File, header *multipart.FileHeader) (*models.ChannelBackground, error) {
	mimeType := header.Header.Get("Content-Type")
	if mimeType != "image/jpeg" && mimeType != "image/png" && mimeType != "image/webp" {
		return nil, fmt.Errorf("invalid mime type: %s", mimeType)
	}

	const MaxFileSize = 8 * 1024 * 1024
	if header.Size > MaxFileSize {
		return nil, fmt.Errorf("file too large, max size is 8MB")
	}

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, fmt.Errorf("failed to hash file: %w", err)
	}
	hashStr := hex.EncodeToString(hasher.Sum(nil))

	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to seek file: %w", err)
	}

	img, _, err := image.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}
	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	var rSum, gSum, bSum int64
	var pixelCount int64
	step := 4
	for y := bounds.Min.Y; y < bounds.Max.Y; y += step {
		for x := bounds.Min.X; x < bounds.Max.X; x += step {
			color := img.At(x, y)
			r, g, b, _ := color.RGBA()
			rSum += int64(r >> 8)
			gSum += int64(g >> 8)
			bSum += int64(b >> 8)
			pixelCount++
		}
	}

	avgR := uint8(rSum / pixelCount)
	avgG := uint8(gSum / pixelCount)
	avgB := uint8(bSum / pixelCount)
	dominantColorHex := fmt.Sprintf("#%02X%02X%02X", avgR, avgG, avgB)
	meanLuminance := (0.299*float32(avgR) + 0.587*float32(avgG) + 0.114*float32(avgB)) / 255.0

	safeName := SanitizeUploadFilename(header.Filename)
	if safeName == "" {
		return nil, fmt.Errorf("invalid filename")
	}
	filePath := fmt.Sprintf("%s/bg_%s_%s", channelID, hashStr, safeName)
	originalURL := fmt.Sprintf("/storage/channel-backgrounds/%s", filePath)

	bg := &models.ChannelBackground{
		ID:             uuid.NewString(),
		ChannelID:      channelID,
		ServerID:       serverID,
		UploaderID:     &userID,
		FileIDOriginal: originalURL,
		FileIDMobile:   &originalURL,
		FileIDBlurred:  &originalURL,
		BlurHash:       "L6PZ|ndH.AyE_3t7t7Rj00xD.8Sn",
		WidthPx:        width,
		HeightPx:       height,
		BytesOriginal:  int(header.Size),
		MimeType:       mimeType,
		Sha256:         hashStr,
		DominantColor:  dominantColorHex,
		MeanLuminance:  meanLuminance,
		Status:         "ready",
	}

	_ = s.repo.Delete(ctx, channelID)

	err = s.repo.Insert(ctx, bg)
	if err != nil {
		return nil, fmt.Errorf("failed to save database row: %w", err)
	}

	return bg, nil
}

func (s *channelBackgroundService) GetBackground(ctx context.Context, channelID string) (*models.ChannelBackground, error) {
	return s.repo.GetByChannelID(ctx, channelID)
}

func (s *channelBackgroundService) DeleteBackground(ctx context.Context, channelID string) error {
	return s.repo.Delete(ctx, channelID)
}

func (s *channelBackgroundService) SetOverride(ctx context.Context, userID, channelID string, opacity float32, enabled bool) error {
	override := &models.ChannelBackgroundUserOverride{
		UserID:    userID,
		ChannelID: channelID,
		Opacity:   opacity,
		Enabled:   enabled,
	}
	return s.repo.UpsertOverride(ctx, override)
}

func (s *channelBackgroundService) GetOverride(ctx context.Context, userID, channelID string) (*models.ChannelBackgroundUserOverride, error) {
	return s.repo.GetOverride(ctx, userID, channelID)
}
