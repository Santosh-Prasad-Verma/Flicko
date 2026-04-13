package mailer

import (
	"log/slog"
	"sync"

	"github.com/flicko-org/mail-gateway/internal/models"
)

// MockMailer is a test double that records sent emails instead of
// actually sending them via SMTP. Use it in unit/integration tests.
type MockMailer struct {
	mu    sync.Mutex
	Sent  []SentEmail // All emails "sent" through this mock
	Error error       // If set, Send() will return this error (for testing failures)
}

// SentEmail records the details of a single email sent through the mock.
type SentEmail struct {
	To           string
	Subject      string
	TemplateName string
	Data         models.EmailData
}

// NewMockMailer creates a new MockMailer for testing.
func NewMockMailer() *MockMailer {
	return &MockMailer{
		Sent: make([]SentEmail, 0),
	}
}

// Send records the email details for later assertion in tests.
// If m.Error is set, it returns that error to simulate SMTP failures.
func (m *MockMailer) Send(to, subject, templateName string, data models.EmailData) error {
	if m.Error != nil {
		slog.Warn("mock_mailer: simulating send failure",
			"to", to,
			"error", m.Error,
		)
		return m.Error
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	m.Sent = append(m.Sent, SentEmail{
		To:           to,
		Subject:      subject,
		TemplateName: templateName,
		Data:         data,
	})

	slog.Info("mock_mailer: email recorded (not actually sent)",
		"to", to,
		"subject", subject,
		"template", templateName,
	)

	return nil
}

// SentCount returns the number of emails recorded by this mock.
func (m *MockMailer) SentCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.Sent)
}

// LastSent returns the most recently sent email, or nil if none were sent.
func (m *MockMailer) LastSent() *SentEmail {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.Sent) == 0 {
		return nil
	}
	return &m.Sent[len(m.Sent)-1]
}

// Reset clears all recorded emails and resets the error.
func (m *MockMailer) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Sent = make([]SentEmail, 0)
	m.Error = nil
}
