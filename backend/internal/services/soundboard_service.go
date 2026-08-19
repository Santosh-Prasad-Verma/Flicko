package services

import (
	"context"
	"fmt"
	"io"

	"github.com/flicko-org/flicko-backend/internal/config"
)

type SoundboardSound struct {
	ID        string `json:"id"`
	ServerID  string `json:"server_id"`
	Name      string `json:"name"`
	SoundURL  string `json:"sound_url"`
	EmojiName string `json:"emoji_name"`
	Volume    float64 `json:"volume"`
}

type SoundboardService interface {
	UploadSound(ctx context.Context, serverID string, name string, file io.Reader, contentType string) (*SoundboardSound, error)
	ListServerSounds(ctx context.Context, serverID string) ([]*SoundboardSound, error)
}

type soundboardService struct {
	blobSvc AzureBlobService
	cfg     *config.Config
}

func NewSoundboardService(blobSvc AzureBlobService, cfg *config.Config) SoundboardService {
	return &soundboardService{
		blobSvc: blobSvc,
		cfg:     cfg,
	}
}

func (s *soundboardService) UploadSound(ctx context.Context, serverID string, name string, file io.Reader, contentType string) (*SoundboardSound, error) {
	blobName := fmt.Sprintf("soundboard/%s/%s.mp3", serverID, name)
	soundURL, err := s.blobSvc.UploadBlob(ctx, "soundboard", blobName, file, contentType)
	if err != nil {
		return nil, fmt.Errorf("failed to upload sound to azure blob: %w", err)
	}

	return &SoundboardSound{
		ID:        fmt.Sprintf("sound_%s_%s", serverID, name),
		ServerID:  serverID,
		Name:      name,
		SoundURL:  soundURL,
		Volume:    1.0,
	}, nil
}

func (s *soundboardService) ListServerSounds(ctx context.Context, serverID string) ([]*SoundboardSound, error) {
	return []*SoundboardSound{}, nil
}
