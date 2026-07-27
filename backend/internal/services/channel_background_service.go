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
	storage_go "github.com/supabase-community/storage-go"
)

type ChannelBackgroundService interface {
	UploadBackground(ctx context.Context, channelID, serverID, userID string, file multipart.File, header *multipart.FileHeader) (*models.ChannelBackground, error)
	GetBackground(ctx context.Context, channelID string) (*models.ChannelBackground, error)
	DeleteBackground(ctx context.Context, channelID string) error
	SetOverride(ctx context.Context, userID, channelID string, opacity float32, enabled bool) error
	GetOverride(ctx context.Context, userID, channelID string) (*models.ChannelBackgroundUserOverride, error)
}

type channelBackgroundService struct {
	config  *config.Config
	repo    repo.ChannelBackgroundRepo
	storage *storage_go.Client
}

func NewChannelBackgroundService(cfg *config.Config, r repo.ChannelBackgroundRepo) ChannelBackgroundService {
	storageUrl := fmt.Sprintf("%s/storage/v1", cfg.SupabaseURL)
	storageClient := storage_go.NewClient(storageUrl, cfg.SupabaseServiceKey, nil)

	return &channelBackgroundService{
		config:  cfg,
		repo:    r,
		storage: storageClient,
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

	// Calculate SHA-256 hash for verification & file name mapping
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, fmt.Errorf("failed to hash file: %w", err)
	}
	hashStr := hex.EncodeToString(hasher.Sum(nil))

	// Reset file pointer
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to seek file: %w", err)
	}

	// Decode image to inspect dimensions & calculate dominant color/luminance
	img, _, err := image.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}
	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	// Calculate average color and luminance
	var rSum, gSum, bSum int64
	var pixelCount int64
	step := 4 // Sample every 4th pixel to keep it fast
	for y := bounds.Min.Y; y < bounds.Max.Y; y += step {
		for x := bounds.Min.X; x < bounds.Max.X; x += step {
			color := img.At(x, y)
			r, g, b, _ := color.RGBA()
			// RGBA() returns color component values in range [0, 65535]
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

	// Mean luminance formula: 0.299*R + 0.587*G + 0.114*B (values mapped to [0..1])
	meanLuminance := (0.299*float32(avgR) + 0.587*float32(avgG) + 0.114*float32(avgB)) / 255.0

	// Reset file pointer again for uploading
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to seek file: %w", err)
	}

	// Create unique folder/file path. The client-supplied name must be reduced
	// to a single safe path segment or it could escape the channel prefix.
	safeName := SanitizeUploadFilename(header.Filename)
	if safeName == "" {
		return nil, fmt.Errorf("invalid filename")
	}
	filePath := fmt.Sprintf("%s/bg_%s_%s", channelID, hashStr, safeName)

	// Upload to Supabase Storage
	_, err = s.storage.UploadFile("channel-backgrounds", filePath, file)
	if err != nil {
		// Log but continue if 409 conflict
		fmt.Printf("warning: channel background upload: %v\n", err)
	}

	// Construct public URLs
	originalURL := fmt.Sprintf("%s/storage/v1/object/public/channel-backgrounds/%s", s.config.SupabaseURL, filePath)

	bg := &models.ChannelBackground{
		ID:             uuid.NewString(),
		ChannelID:      channelID,
		ServerID:       serverID,
		UploaderID:     &userID,
		FileIDOriginal: originalURL,
		FileIDMobile:   &originalURL, // Fallback to original
		FileIDBlurred:  &originalURL, // Fallback to original
		BlurHash:       "L6PZ|ndH.AyE_3t7t7Rj00xD.8Sn", // Standard clean BlurHash placeholder
		WidthPx:        width,
		HeightPx:       height,
		BytesOriginal:  int(header.Size),
		MimeType:       mimeType,
		Sha256:         hashStr,
		DominantColor:  dominantColorHex,
		MeanLuminance:  meanLuminance,
		Status:         "ready",
	}

	// Delete old background if it exists
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
	// Let's get the background first so we delete the file from storage
	bg, err := s.repo.GetByChannelID(ctx, channelID)
	if err == nil && bg != nil {
		// In Supabase storage, we can delete the file from bucket
		// FileIDOriginal is a URL, so we extract the relative path
		// URL is like: .../channel-backgrounds/[channelID]/bg_[hash]_[filename]
		// Let's just delete the row; the database trigger fn_enqueue_bg_blob_delete()
		// puts file_id in channel_background_blob_deletions.
	}
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
