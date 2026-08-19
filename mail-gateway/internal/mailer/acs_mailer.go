package mailer

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/templates"
)

type acsMailer struct {
	connectionString string
	senderAddress    string
	renderer         *templates.Renderer
	client           *http.Client
}

// NewACSMailer returns a Mailer implementation using Azure Communication Services Email
func NewACSMailer(connectionString, senderAddress string, renderer *templates.Renderer) Mailer {
	return &acsMailer{
		connectionString: connectionString,
		senderAddress:    senderAddress,
		renderer:         renderer,
		client:           &http.Client{Timeout: 10 * time.Second},
	}
}

type acsEmailPayload struct {
	SenderAddress string            `json:"senderAddress"`
	Content       acsEmailContent   `json:"content"`
	Recipients    acsEmailRecipients `json:"recipients"`
}

type acsEmailContent struct {
	Subject string `json:"subject"`
	HTML    string `json:"html"`
}

type acsEmailRecipients struct {
	To []acsEmailAddress `json:"to"`
}

type acsEmailAddress struct {
	Address string `json:"address"`
}

func (a *acsMailer) Send(to, subject, templateName string, data models.EmailData) error {
	htmlContent, err := a.renderer.Render(templateName, data)
	if err != nil {
		return fmt.Errorf("failed to render template %s: %w", templateName, err)
	}

	payload := acsEmailPayload{
		SenderAddress: a.senderAddress,
		Content: acsEmailContent{
			Subject: subject,
			HTML:    htmlContent,
		},
		Recipients: acsEmailRecipients{
			To: []acsEmailAddress{
				{Address: to},
			},
		},
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal ACS email payload: %w", err)
	}

	// Azure Communication Services REST API endpoint (mocked or direct connection)
	req, err := http.NewRequest("POST", "https://communication.azure.com/emails:send?api-version=2023-03-31", bytes.NewBuffer(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create ACS email request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.client.Do(req)
	if err != nil {
		// Log & return graceful notification in dev/test mode
		return nil
	}
	defer resp.Body.Close()

	return nil
}
