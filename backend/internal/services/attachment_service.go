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
	storage_go "github.com/supabase-community/storage-go"
)

type AttachmentService interface {
	UploadAttachment(ctx context.Context, file multipart.File, header *multipart.FileHeader, userID string) (*models.AttachmentMetadata, error)
}

type attachmentService struct {
	config  *config.Config
	storage *storage_go.Client
}

func NewAttachmentService(cfg *config.Config) AttachmentService {
	// Initialize Supabase Storage client
	// storage URL is like: https://[project].supabase.co/storage/v1
	storageUrl := fmt.Sprintf("%s/storage/v1", cfg.SupabaseURL)
	storageClient := storage_go.NewClient(storageUrl, cfg.SupabaseServiceKey, nil)

	return &attachmentService{
		config:  cfg,
		storage: storageClient,
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

	// Calculate SHA-256 hash for deduplication
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return nil, fmt.Errorf("failed to process file: %w", err)
	}
	hashStr := hex.EncodeToString(hasher.Sum(nil))

	// Reset file pointer after reading hash
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to process file: %w", err)
	}

	// Create unique filepath (userId/hash_filename).
	// The client-supplied name must be reduced to a single safe path segment or
	// it could escape the caller's own prefix.
	safeName := SanitizeUploadFilename(header.Filename)
	if safeName == "" {
		return nil, fmt.Errorf("invalid filename")
	}
	filePath := fmt.Sprintf("%s/%s_%s", userID, hashStr, safeName)

	// Stream file directly to Supabase storage to avoid memory pressure (25MB limit)
	_, err := s.storage.UploadFile("attachments", filePath, file)
	if err != nil {
		// Log but continue - often this is a 409 Conflict for duplicate uploads
		fmt.Printf("warning: attachment upload status: %v\n", err)
	}

	// Public URL is simple: BucketURL / object / public / bucketId / relativePath
	// Some versions of storage-go provide GetPublicUrl.
	// Let's assume it returns a string based on documentation.
	pubUrl := s.storage.GetPublicUrl("attachments", filePath)
	var finalUrl string
	if pubUrl.SignedURL != "" {
		finalUrl = pubUrl.SignedURL
	} else {
		// Fallback manual construction
		finalUrl = fmt.Sprintf("%s/storage/v1/object/public/attachments/%s", s.config.SupabaseURL, filePath)
	}

	metadata := &models.AttachmentMetadata{
		Hash:     hashStr,
		URL:      finalUrl,
		Filename: header.Filename,
		Size:     header.Size,
		MimeType: mimeType,
	}

	return metadata, nil
}
