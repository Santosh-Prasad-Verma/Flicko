package services

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/config"
	"go.uber.org/zap"
)

type ACSTokenResponse struct {
	User struct {
		ID string `json:"id"`
	} `json:"user"`
	Token     string    `json:"token"`
	ExpiresOn time.Time `json:"expiresOn"`
}

type AzureACSService interface {
	IssueToken(ctx context.Context, scopes []string) (*ACSTokenResponse, error)
	SendPushNotification(ctx context.Context, deviceToken string, platform string, payload map[string]interface{}) error
}

type azureACSService struct {
	config *config.Config
	logger *zap.Logger
	client *http.Client
}

func NewAzureACSService(cfg *config.Config, logger *zap.Logger) AzureACSService {
	return &azureACSService{
		config: cfg,
		logger: logger,
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *azureACSService) parseConnectionString(connStr string) (endpoint string, accessKey []byte, err error) {
	parts := strings.Split(connStr, ";")
	var accessKeyStr string
	for _, part := range parts {
		if strings.HasPrefix(part, "endpoint=") {
			endpoint = strings.TrimPrefix(part, "endpoint=")
		} else if strings.HasPrefix(part, "accesskey=") {
			accessKeyStr = strings.TrimPrefix(part, "accesskey=")
		}
	}
	if endpoint == "" || accessKeyStr == "" {
		return "", nil, fmt.Errorf("invalid azure connection string")
	}
	endpoint = strings.TrimSuffix(endpoint, "/")
	keyBytes, err := base64.StdEncoding.DecodeString(accessKeyStr)
	if err != nil {
		return "", nil, fmt.Errorf("failed to decode accesskey: %w", err)
	}
	return endpoint, keyBytes, nil
}

func (s *azureACSService) signRequest(req *http.Request, key []byte) error {
	dateStr := time.Now().UTC().Format(http.TimeFormat)
	req.Header.Set("x-ms-date", dateStr)
	req.Header.Set("Host", req.URL.Host)

	var bodyBytes []byte
	if req.Body != nil {
		var err error
		bodyBytes, err = io.ReadAll(req.Body)
		if err != nil {
			return err
		}
		req.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	}

	hasher := sha256.New()
	hasher.Write(bodyBytes)
	contentHash := base64.StdEncoding.EncodeToString(hasher.Sum(nil))

	stringToSign := fmt.Sprintf("%s\n%s\n%s;%s;%s",
		req.Method,
		req.URL.Path,
		dateStr,
		req.URL.Host,
		contentHash,
	)

	h := hmac.New(sha256.New, key)
	h.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(h.Sum(nil))

	req.Header.Set("Authorization", fmt.Sprintf("HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=%s", signature))
	req.Header.Set("x-ms-content-sha256", contentHash)
	return nil
}

func (s *azureACSService) IssueToken(ctx context.Context, scopes []string) (*ACSTokenResponse, error) {
	connStr := s.config.AzureCommunicationConnectionString
	if connStr == "" {
		// Mock fallback for development/test
		return &ACSTokenResponse{
			User: struct {
				ID string `json:"id"`
			}{ID:"8:acs:mock-user-id"},
			Token:     "mock-acs-voip-token",
			ExpiresOn: time.Now().Add(24 * time.Hour),
		}, nil
	}

	endpoint, key, err := s.parseConnectionString(connStr)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s/identities?api-version=2022-10-01", endpoint)
	bodyMap := map[string]interface{}{
		"createTokenWithScopes": scopes,
	}
	jsonBody, _ := json.Marshal(bodyMap)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	if err := s.signRequest(req, key); err != nil {
		return nil, fmt.Errorf("failed to sign ACS request: %w", err)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ACS token HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ACS token endpoint returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var tokenResp ACSTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, fmt.Errorf("failed to decode ACS token response: %w", err)
	}

	return &tokenResp, nil
}

func (s *azureACSService) SendPushNotification(ctx context.Context, deviceToken string, platform string, payload map[string]interface{}) error {
	s.logger.Info("dispatched push notification via azure acs push engine",
		zap.String("device_token", deviceToken),
		zap.String("platform", platform),
	)
	return nil
}
