package service

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
	"os"
	"strings"
	"time"

	"go.uber.org/zap"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// VoiceTokenInput is the input for generating a voice token.
type VoiceTokenInput struct {
	UserID    string
	ChannelID string
	ServerID  string
}

// VoiceService generates Azure Communication Services access tokens for voice/video.
type VoiceService struct {
	connStr string
	client  *http.Client
	log     *zap.Logger
}

// NewVoiceService creates a VoiceService.
func NewVoiceService(log *zap.Logger) *VoiceService {
	return &VoiceService{
		connStr: os.Getenv("AZURE_COMMUNICATION_CONNECTION_STRING"),
		client:  &http.Client{Timeout: 10 * time.Second},
		log:     log,
	}
}

func (s *VoiceService) parseConnectionString(connStr string) (endpoint string, accessKey []byte, err error) {
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

func (s *VoiceService) signRequest(req *http.Request, key []byte) error {
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

// GenerateToken creates an Azure Communication Services token for voice/video channels.
func (s *VoiceService) GenerateToken(ctx context.Context, in VoiceTokenInput) (string, error) {
	if in.ChannelID == "" {
		return "", fkerr.ErrValidation("channel_id is required")
	}

	if s.connStr == "" {
		s.log.Info("using mock azure acs token (connection string not set)",
			zap.String("user_id", in.UserID),
			zap.String("channel_id", in.ChannelID),
		)
		return fmt.Sprintf("acs_token_%s_%s", in.ChannelID, in.UserID), nil
	}

	endpoint, key, err := s.parseConnectionString(s.connStr)
	if err != nil {
		return "", fkerr.ErrInternal(fmt.Errorf("invalid azure acs connection string: %w", err))
	}

	url := fmt.Sprintf("%s/identities?api-version=2022-10-01", endpoint)
	bodyMap := map[string]interface{}{
		"createTokenWithScopes": []string{"voip", "chat"},
	}
	jsonBody, _ := json.Marshal(bodyMap)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", fkerr.ErrInternal(fmt.Errorf("failed to create acs request: %w", err))
	}
	req.Header.Set("Content-Type", "application/json")

	if err := s.signRequest(req, key); err != nil {
		return "", fkerr.ErrInternal(fmt.Errorf("failed to sign acs request: %w", err))
	}

	resp, err := s.client.Do(req)
	if err != nil {
		s.log.Error("failed to generate azure acs token", zap.Error(err))
		return "", fkerr.ErrInternal(fmt.Errorf("failed to generate voice token"))
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		s.log.Error("acs token endpoint error", zap.Int("status", resp.StatusCode), zap.String("body", string(respBody)))
		return "", fkerr.ErrInternal(fmt.Errorf("voice provider error"))
	}

	var tokenResp struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fkerr.ErrInternal(fmt.Errorf("failed to decode voice token"))
	}

	s.log.Info("azure acs voice token generated",
		zap.String("user_id", in.UserID),
		zap.String("channel_id", in.ChannelID),
	)

	return tokenResp.Token, nil
}
