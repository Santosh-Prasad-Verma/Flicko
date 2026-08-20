package mailer

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/templates"
)

type acsMailer struct {
	endpoint      string
	accessKey     []byte
	senderAddress string
	renderer      *templates.Renderer
	client        *http.Client
}

// NewACSMailer returns a Mailer implementation using Azure Communication Services Email
func NewACSMailer(connectionString, senderAddress string, renderer *templates.Renderer) (Mailer, error) {
	var endpoint, accessKeyStr string
	parts := strings.Split(connectionString, ";")
	for _, part := range parts {
		if strings.HasPrefix(part, "endpoint=") {
			endpoint = strings.TrimPrefix(part, "endpoint=")
		} else if strings.HasPrefix(part, "accesskey=") {
			accessKeyStr = strings.TrimPrefix(part, "accesskey=")
		}
	}

	if endpoint == "" || accessKeyStr == "" {
		return nil, fmt.Errorf("invalid Azure Communication Services connection string")
	}

	endpoint = strings.TrimSuffix(endpoint, "/")

	keyBytes, err := base64.StdEncoding.DecodeString(accessKeyStr)
	if err != nil {
		return nil, fmt.Errorf("failed to decode Azure Communication Services access key: %w", err)
	}

	return &acsMailer{
		endpoint:      endpoint,
		accessKey:     keyBytes,
		senderAddress: senderAddress,
		renderer:      renderer,
		client:        &http.Client{Timeout: 15 * time.Second},
	}, nil
}

type acsMessage struct {
	SenderAddress string              `json:"senderAddress"`
	Content       acsContent          `json:"content"`
	Recipients    acsRecipients       `json:"recipients"`
}

type acsContent struct {
	Subject string `json:"subject"`
	HTML    string `json:"html"`
}

type acsRecipients struct {
	To []acsAddress `json:"to"`
}

type acsAddress struct {
	Address string `json:"address"`
}

func (a *acsMailer) Send(to, subject, templateName string, data models.EmailData) error {
	htmlContent, err := a.renderer.Render(templateName, data)
	if err != nil {
		return fmt.Errorf("failed to render template %s: %w", templateName, err)
	}

	msg := acsMessage{
		SenderAddress: a.senderAddress,
		Content: acsContent{
			Subject: subject,
			HTML:    htmlContent,
		},
		Recipients: acsRecipients{
			To: []acsAddress{{Address: to}},
		},
	}

	bodyBytes, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal ACS email payload: %w", err)
	}

	apiURL := fmt.Sprintf("%s/emails/messages:send?api-version=2023-03-31", a.endpoint)
	parsedURL, err := url.Parse(apiURL)
	if err != nil {
		return fmt.Errorf("failed to parse ACS API URL: %w", err)
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create ACS HTTP request: %w", err)
	}

	// Azure HMAC SHA256 signature generation
	now := time.Now().UTC().Format(http.TimeFormat)
	bodyHashBytes := sha256.Sum256(bodyBytes)
	bodyHashBase64 := base64.StdEncoding.EncodeToString(bodyHashBytes[:])

	stringToSign := fmt.Sprintf("POST\n%s\n%s;%s;%s",
		parsedURL.Path+"?"+parsedURL.RawQuery,
		now,
		parsedURL.Host,
		bodyHashBase64,
	)

	h := hmac.New(sha256.New, a.accessKey)
	h.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(h.Sum(nil))

	authHeader := fmt.Sprintf("HMAC-SHA256 SignedHeaders=date;host;x-ms-content-sha256&Signature=%s", signature)

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Repeatability-Request-ID", fmt.Sprintf("%d", time.Now().UnixNano()))
	req.Header.Set("Repeatability-First-Sent", now)
	req.Header.Set("date", now)
	req.Header.Set("x-ms-content-sha256", bodyHashBase64)
	req.Header.Set("Authorization", authHeader)

	resp, err := a.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute ACS HTTP send: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		slog.Info("email sent successfully via Azure Communication Services", "to", to, "subject", subject, "status", resp.Status)
		return nil
	}

	return fmt.Errorf("Azure Communication Services returned status %s", resp.Status)
}
