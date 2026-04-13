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

// In a real environment we'd inject a mocked StorageClient interface,
// but for property testing the validation logic we test the error boundaries
// and metadata generation specifically.

func TestAttachmentService_Validation(t *testing.T) {
	// Create a service instance with a dummy config
	cfg := &config.Config{
		SupabaseURL:        "https://test.supabase.co",
		SupabaseServiceKey: "dummy_key",
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

		// To simulate multipart.File we need a buffer that supports Seek
		_ = bytes.NewReader(content)
		// We'll wrap reader in a mock multipart.File if needed,
		// but typically we can use a basic stub or just let it panic if it reaches read
		// because validation happens first.

		// Wait, multipart.File is an interface (io.Reader, io.ReaderAt, io.Seeker, io.Closer)
		// If we pass nil for now since validation happens before reading the body.
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
