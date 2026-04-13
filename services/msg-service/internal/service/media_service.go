package service

import (
	"context"
	"fmt"
	"net/url"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"go.uber.org/zap"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
)

// AllowedContentTypes is the set of MIME types accepted for upload.
var AllowedContentTypes = map[string]bool{
	"image/png":       true,
	"image/jpeg":      true,
	"image/gif":       true,
	"image/webp":      true,
	"video/mp4":       true,
	"video/webm":      true,
	"audio/mpeg":      true,
	"audio/ogg":       true,
	"application/pdf": true,
}

// MED-020: Map of allowed file extensions per content type.
var AllowedExtensions = map[string][]string{
	"image/png":       {".png"},
	"image/jpeg":      {".jpg", ".jpeg"},
	"image/gif":       {".gif"},
	"image/webp":      {".webp"},
	"video/mp4":       {".mp4"},
	"video/webm":      {".webm"},
	"audio/mpeg":      {".mp3", ".mpeg"},
	"audio/ogg":       {".ogg"},
	"application/pdf": {".pdf"},
}

// safeFilenameRe matches only safe characters for filenames.
var safeFilenameRe = regexp.MustCompile(`[^a-zA-Z0-9._-]`)

// MaxFileSize is the upload limit (25 MiB).
const MaxFileSize = 25 * 1024 * 1024

// PresignedURLTTL is the lifetime of a presigned PUT URL.
const PresignedURLTTL = 15 * time.Minute

// S3Presigner generates presigned PUT URLs.
// This interface decouples the service from the S3-compatible client (minio-go → B2).
type S3Presigner interface {
	PresignedPutObject(ctx context.Context, bucket, object string, expires time.Duration) (*url.URL, error)
}

// MediaService handles presigned URL generation for uploads.
type MediaService struct {
	presigner S3Presigner
	bucket    string
	log       *zap.Logger
}

// NewMediaService creates a MediaService.
func NewMediaService(
	presigner S3Presigner,
	bucket string,
	log *zap.Logger,
) *MediaService {
	return &MediaService{
		presigner: presigner,
		bucket:    bucket,
		log:       log.Named("svc.media"),
	}
}

// PresignRequest is the input for presigned URL generation.
type PresignRequest struct {
	ChannelID   string
	UserID      string
	FileName    string
	ContentType string
	FileSize    int64
}

// PresignResponse is the result of a presigned URL generation.
type PresignResponse struct {
	UploadURL string `json:"upload_url"`
	ObjectKey string `json:"object_key"`
}

// GeneratePresignedURL validates the request and returns a presigned PUT URL.
func (s *MediaService) GeneratePresignedURL(ctx context.Context, req PresignRequest) (*PresignResponse, error) {
	if req.FileName == "" {
		return nil, fkerr.ErrMissingField("file_name")
	}
	if req.ContentType == "" {
		return nil, fkerr.ErrMissingField("content_type")
	}
	if !AllowedContentTypes[req.ContentType] {
		return nil, fkerr.New(fkerr.CodeInvalidFileType,
			fmt.Sprintf("content type %q is not allowed", req.ContentType))
	}
	if req.FileSize <= 0 {
		return nil, fkerr.ErrMissingField("file_size")
	}
	if req.FileSize > MaxFileSize {
		return nil, fkerr.New(fkerr.CodeFileTooLarge,
			fmt.Sprintf("file size %d exceeds maximum %d bytes", req.FileSize, MaxFileSize))
	}

	// MED-020: Validate file extension matches declared content type.
	ext := strings.ToLower(filepath.Ext(req.FileName))
	allowedExts, ok := AllowedExtensions[req.ContentType]
	if !ok || !containsExt(allowedExts, ext) {
		return nil, fkerr.New(fkerr.CodeInvalidFileType,
			fmt.Sprintf("extension %q does not match content type %q", ext, req.ContentType))
	}

	// MED-020: Sanitize filename to prevent path traversal / injection.
	safeName := sanitizeFilename(req.FileName)
	if safeName == "" {
		return nil, fkerr.New(fkerr.CodeInvalidFileType, "invalid file name")
	}

	// Object key: attachments/{channelID}/{ulid}/{filename}
	objectKey := fmt.Sprintf("attachments/%s/%s/%s", req.ChannelID, id.New(), safeName)

	u, err := s.presigner.PresignedPutObject(ctx, s.bucket, objectKey, PresignedURLTTL)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}

	return &PresignResponse{
		UploadURL: u.String(),
		ObjectKey: objectKey,
	}, nil
}

// containsExt checks if ext is in the allowed list.
func containsExt(allowed []string, ext string) bool {
	for _, a := range allowed {
		if a == ext {
			return true
		}
	}
	return false
}

// sanitizeFilename removes path components and unsafe characters.
func sanitizeFilename(name string) string {
	// Strip directory components (path traversal prevention).
	name = filepath.Base(name)
	if name == "." || name == ".." || name == "" {
		return ""
	}
	// Replace unsafe characters.
	name = safeFilenameRe.ReplaceAllString(name, "_")
	// Limit length.
	if len(name) > 255 {
		ext := filepath.Ext(name)
		name = name[:255-len(ext)] + ext
	}
	return name
}
