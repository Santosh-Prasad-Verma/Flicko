package mailer

import (
	"crypto/tls"
	"fmt"
	"log/slog"
	"net"
	"net/smtp"
	"strings"
	"time"

	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/templates"
)

// SMTPMailer sends emails via net/smtp using Gmail SMTP (STARTTLS on port 587).
// It renders HTML templates before sending and builds RFC 2822 compliant messages.
type SMTPMailer struct {
	host     string // SMTP server hostname (smtp.gmail.com)
	port     string // SMTP server port (587)
	username string // Gmail address for authentication
	password string // Gmail App Password
	from     string // Sender email address
	renderer *templates.Renderer
}

// NewSMTPMailer creates a new SMTPMailer with the given SMTP configuration.
func NewSMTPMailer(host, port, username, password, from string, renderer *templates.Renderer) *SMTPMailer {
	return &SMTPMailer{
		host:     host,
		port:     port,
		username: username,
		password: password,
		from:     from,
		renderer: renderer,
	}
}

// Send renders the named template with the given data and sends the resulting
// HTML email to the specified recipient via SMTP.
// Supports both port 587 (STARTTLS) and port 465 (implicit TLS/SSL).
func (m *SMTPMailer) Send(to, subject, templateName string, data models.EmailData) error {
	// Render the HTML template
	htmlBody, err := m.renderer.Render(templateName, data)
	if err != nil {
		return fmt.Errorf("smtp_mailer: failed to render template %q: %w", templateName, err)
	}

	// Build RFC 2822 compliant MIME message with HTML content
	msg := m.buildMessage(to, subject, htmlBody)

	addr := m.host + ":" + m.port
	auth := smtp.PlainAuth("", m.username, m.password, m.host)

	if m.port == "465" {
		// Port 465 — implicit TLS (used by Resend, SendGrid, etc.)
		if err := m.sendWithTLS(addr, auth, to, msg); err != nil {
			return fmt.Errorf("smtp_mailer: failed to send email to %q: %w", to, err)
		}
	} else {
		// Port 587 — STARTTLS (used by Gmail and others)
		if err := smtp.SendMail(addr, auth, m.from, []string{to}, []byte(msg)); err != nil {
			return fmt.Errorf("smtp_mailer: failed to send email to %q: %w", to, err)
		}
	}

	slog.Info("email sent successfully",
		"to", to,
		"subject", subject,
		"template", templateName,
	)

	return nil
}

// sendWithTLS sends an email using implicit TLS on port 465.
// Required for providers like Resend that don't support STARTTLS.
func (m *SMTPMailer) sendWithTLS(addr string, auth smtp.Auth, to, msg string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return err
	}

	tlsCfg := &tls.Config{ServerName: host}
	conn, err := tls.Dial("tcp", addr, tlsCfg)
	if err != nil {
		return fmt.Errorf("tls dial: %w", err)
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, host)
	if err != nil {
		return fmt.Errorf("smtp client: %w", err)
	}
	defer client.Close()

	if err = client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth: %w", err)
	}
	if err = client.Mail(m.from); err != nil {
		return fmt.Errorf("smtp MAIL FROM: %w", err)
	}
	if err = client.Rcpt(to); err != nil {
		return fmt.Errorf("smtp RCPT TO: %w", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("smtp DATA: %w", err)
	}
	if _, err = fmt.Fprint(w, msg); err != nil {
		return fmt.Errorf("smtp write body: %w", err)
	}
	if err = w.Close(); err != nil {
		return fmt.Errorf("smtp close data: %w", err)
	}

	return client.Quit()
}

// buildMessage constructs an RFC 2822 compliant email message with MIME headers
// for HTML content. Uses multipart/alternative to support both HTML and plain text.
func (m *SMTPMailer) buildMessage(to, subject, htmlBody string) string {
	var sb strings.Builder

	// Required RFC 2822 headers
	sb.WriteString("From: " + m.formatSender() + "\r\n")
	sb.WriteString("To: " + to + "\r\n")
	sb.WriteString("Subject: " + subject + "\r\n")

	// Date header — required by RFC 2822; missing date causes spam flagging
	sb.WriteString("Date: " + time.Now().Format(time.RFC1123Z) + "\r\n")

	// Message-ID — required for deduplication and deliverability
	msgID := fmt.Sprintf("<%d.flicko@%s>", time.Now().UnixNano(), m.host)
	sb.WriteString("Message-ID: " + msgID + "\r\n")

	// Reply-To — direct replies back to the app email, not a no-reply sink
	sb.WriteString("Reply-To: " + m.formatSender() + "\r\n")

	// MIME headers for HTML email
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString("Content-Type: multipart/alternative; boundary=\"boundary-flicko-mail\"\r\n")
	sb.WriteString("\r\n")

	// Plain text part (fallback for email clients that don't support HTML)
	sb.WriteString("--boundary-flicko-mail\r\n")
	sb.WriteString("Content-Type: text/plain; charset=\"UTF-8\"\r\n")
	sb.WriteString("Content-Transfer-Encoding: 7bit\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(m.extractPlainText(htmlBody))
	sb.WriteString("\r\n")

	// HTML part (primary)
	sb.WriteString("--boundary-flicko-mail\r\n")
	sb.WriteString("Content-Type: text/html; charset=\"UTF-8\"\r\n")
	sb.WriteString("Content-Transfer-Encoding: 7bit\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(htmlBody)
	sb.WriteString("\r\n")

	// Close boundary
	sb.WriteString("--boundary-flicko-mail--\r\n")

	return sb.String()
}

// formatSender returns the From header value with display name.
func (m *SMTPMailer) formatSender() string {
	return fmt.Sprintf("\"Flicko\" <%s>", m.from)
}

// extractPlainText creates a basic plain-text fallback from the HTML body.
// This is a simple approach — strips HTML for clients that can't render it.
func (m *SMTPMailer) extractPlainText(html string) string {
	// Simple extraction: just provide a basic message
	// In production you could use a proper html-to-text converter
	return "Please view this email in an HTML-compatible email client.\r\n" +
		"If you cannot view the HTML version, copy and paste the action URL from the email."
}
