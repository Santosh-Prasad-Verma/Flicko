package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"mime/multipart"

	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type AttachmentService interface {
	UploadAttachment(ctx context.Context, file multipart.File, header *multipart.FileHeader, userID string) (*models.AttachmentMetadata, error)
}

type attachmentService struct {
	config *config.Config
}

func NewAttachmentService(cfg *config.Config) AttachmentService {
	return &attachmentService{
		config: cfg,
	}
}

func (s *attachmentService) UploadAttachment(ctx context.Context, file multipart.File, header *multipart.FileHeader, userID string) (*models.AttachmentMetadata, error) {
	mimeType := header.Header.Get("Content-Type")
	if !models.IsMimeTypeAllowed(mimeType) {
		return nil, fmt.Errorf("invalid file type: %s", mimeType)
	}

	const MaxFileSize = 25 * 1024 * 1024
	if header.Size > MaxFileSize {
		return nil, fmt.Errorf("file too large, max size is 25MB")
	}

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, fmt.Errorf("failed to process file: %w", err)
	}
	hashStr := hex.EncodeToString(hasher.Sum(nil))

	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to process file: %w", err)
	}

	safeName := SanitizeUploadFilename(header.Filename)
	if safeName == "" {
		return nil, fmt.Errorf("invalid filename")
	}
	blobName := fmt.Sprintf("%s/%s_%s", userID, hashStr, safeName)
	
	blobSvc := NewAzureBlobService(s.config)
	blobURL, err := blobSvc.UploadBlob(ctx, "attachments", blobName, file, mimeType)
	if err != nil {
		return nil, fmt.Errorf("failed to upload blob to azure: %w", err)
	}

	metadata := &models.AttachmentMetadata{
		Hash:     hashStr,
		URL:      blobURL,
		Filename: header.Filename,
		Size:     header.Size,
		MimeType: mimeType,
	}

	return metadata, nil
}
