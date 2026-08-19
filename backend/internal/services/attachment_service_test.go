package services_test

import (
	"bytes"
	"context"
	"mime/multipart"
	"net/textproto"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/config"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

func TestAttachmentService_Validation(t *testing.T) {
	// Create a service instance with a dummy config
	cfg := &config.Config{
		AzureBlobConnectionString: "DefaultEndpointsProtocol=https;AccountName=test;AccountKey=key;EndpointSuffix=core.windows.net",
	}
	svc := services.NewAttachmentService(cfg)
	ctx := context.Background()

	// Property 10: Attachment Validation (Mime Type)
	t.Run("Invalid Mime Type Rejected", func(t *testing.T) {
		content := []byte("fake executable content")
		file := &multipart.FileHeader{
			Filename: "virus.exe",
			Size:     int64(len(content)),
			Header:   make(textproto.MIMEHeader),
		}
		file.Header.Set("Content-Type", "application/x-msdownload")

		_ = bytes.NewReader(content)

		_, err := svc.UploadAttachment(ctx, nil, file, "user-123")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "invalid file type")
	})

	t.Run("Oversized File Rejected", func(t *testing.T) {
		file := &multipart.FileHeader{
			Filename: "big.png",
			Size:     30 * 1024 * 1024, // 30MB
			Header:   make(textproto.MIMEHeader),
		}
		file.Header.Set("Content-Type", "image/png")

		_, err := svc.UploadAttachment(ctx, nil, file, "user-123")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "file too large")
	})
}
