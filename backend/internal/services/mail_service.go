package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.uber.org/zap"
)

type MailService struct {
	gatewayURL string
	token      string
	logger     *zap.Logger
}

type MailRequest struct {
	To            string `json:"to"`
	Username      string `json:"username"`
	Type          string `json:"type"`
	AppName       string `json:"app_name"`
	AppURL        string `json:"app_url"`
	TransactionID string `json:"transaction_id,omitempty"`
	TotalAmount   string `json:"total_amount,omitempty"`
	MemberSince   string `json:"member_since,omitempty"`
	Year          int    `json:"year"`
}

func NewMailService(gatewayURL, token string, logger *zap.Logger) *MailService {
	return &MailService{
		gatewayURL: gatewayURL,
		token:      token,
		logger:     logger.Named("service.mail"),
	}
}

func (s *MailService) SendWelcomeEmail(to, username string) error {
	req := MailRequest{
		To:       to,
		Username: username,
		Type:     "welcome",
		AppName:  "Flicko",
		AppURL:   "https://focko.tech",
		Year:     time.Now().Year(),
	}
	return s.send(req)
}

func (s *MailService) SendFlickoPlusConfirmation(to, username, txID, amount string) error {
	req := MailRequest{
		To:            to,
		Username:      username,
		Type:          "flicko_plus",
		AppName:       "Flicko",
		AppURL:        "https://focko.tech",
		TransactionID: txID,
		TotalAmount:   amount,
		MemberSince:   time.Now().Format("Jan 02, 2006"),
		Year:          time.Now().Year(),
	}
	return s.send(req)
}

func (s *MailService) send(mailReq MailRequest) error {
	if s.gatewayURL == "" {
		s.logger.Warn("mail gateway URL not configured, skipping email", zap.String("type", mailReq.Type))
		return nil
	}

	body, err := json.Marshal(mailReq)
	if err != nil {
		return fmt.Errorf("failed to marshal mail request: %w", err)
	}

	req, err := http.NewRequest("POST", s.gatewayURL+"/send", bytes.NewBuffer(body))
	if err != nil {
		return fmt.Errorf("failed to create mail request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.token != "" {
		req.Header.Set("X-Internal-Token", s.token)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send mail request to gateway: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return fmt.Errorf("mail gateway returned status: %d", resp.StatusCode)
	}

	s.logger.Info("email sent successfully via gateway", 
		zap.String("to", mailReq.To), 
		zap.String("type", mailReq.Type))
	return nil
}
