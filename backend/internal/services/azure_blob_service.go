package services

import (
	"context"
	"fmt"
	"io"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/config"
)

type AzureBlobService interface {
	UploadBlob(ctx context.Context, containerName string, blobName string, content io.Reader, contentType string) (string, error)
	DeleteBlob(ctx context.Context, containerName string, blobName string) error
}

type azureBlobService struct {
	config *config.Config
	client *http.Client
}

func NewAzureBlobService(cfg *config.Config) AzureBlobService {
	return &azureBlobService{
		config: cfg,
		client: &http.Client{},
	}
}

func (s *azureBlobService) UploadBlob(ctx context.Context, containerName string, blobName string, content io.Reader, contentType string) (string, error) {
	accountName := "flickostorage2026"
	if s.config != nil && s.config.AzureCosmosDatabaseName != "" && s.config.AzureCosmosDatabaseName != "flicko_db" {
		accountName = s.config.AzureCosmosDatabaseName
	}
	blobURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", accountName, containerName, blobName)

	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// If connection string is set, perform HTTP PUT BlockBlob upload to Azure Storage
	if s.config != nil && s.config.AzureBlobConnectionString != "" {
		req, err := http.NewRequestWithContext(ctx, http.MethodPut, blobURL, content)
		if err != nil {
			return "", fmt.Errorf("failed to create azure blob upload request: %w", err)
		}

		req.Header.Set("x-ms-blob-type", "BlockBlob")
		req.Header.Set("x-ms-version", "2020-10-02")
		req.Header.Set("Content-Type", contentType)

		resp, err := s.client.Do(req)
		if err != nil {
			return "", fmt.Errorf("azure blob put failed: %w", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
			bodyBytes, _ := io.ReadAll(resp.Body)
			return "", fmt.Errorf("azure blob put returned status %d: %s", resp.StatusCode, string(bodyBytes))
		}
	}

	return blobURL, nil
}

func (s *azureBlobService) DeleteBlob(ctx context.Context, containerName string, blobName string) error {
	accountName := "flickostorage2026"
	if s.config != nil && s.config.AzureCosmosDatabaseName != "" && s.config.AzureCosmosDatabaseName != "flicko_db" {
		accountName = s.config.AzureCosmosDatabaseName
	}
	blobURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", accountName, containerName, blobName)

	if s.config != nil && s.config.AzureBlobConnectionString != "" {
		req, err := http.NewRequestWithContext(ctx, http.MethodDelete, blobURL, nil)
		if err != nil {
			return fmt.Errorf("failed to create delete blob request: %w", err)
		}

		req.Header.Set("x-ms-version", "2020-10-02")

		resp, err := s.client.Do(req)
		if err != nil {
			return fmt.Errorf("azure blob delete failed: %w", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusNotFound {
			bodyBytes, _ := io.ReadAll(resp.Body)
			return fmt.Errorf("azure blob delete returned status %d: %s", resp.StatusCode, string(bodyBytes))
		}
	}

	return nil
}
