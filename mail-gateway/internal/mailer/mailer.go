// Package mailer defines the email sending interface and implementations.
// The Mailer interface enables swapping between production SMTP and test mocks.
package mailer

import (
	"github.com/flicko-org/mail-gateway/internal/models"
)

// Mailer is the interface for sending emails. Implementations include
// SMTPMailer (production Gmail) and MockMailer (testing).
type Mailer interface {
	// Send delivers an email using the given template and data.
	// Returns an error if the email could not be sent after all retries.
	Send(to, subject, templateName string, data models.EmailData) error
}
