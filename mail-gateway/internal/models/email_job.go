package models

import "time"

// EmailJob represents a unit of work in the email queue.
// Each job corresponds to one email that needs to be rendered and sent.
type EmailJob struct {
	// ID is a unique identifier for tracking this job through the pipeline
	ID string `json:"id"`

	// To is the recipient email address
	To string `json:"to"`

	// Subject is the email subject line
	Subject string `json:"subject"`

	// TemplateName references which HTML template to render (e.g. "verify", "reset", "magic_link")
	TemplateName string `json:"template_name"`

	// Data contains all variables passed to the HTML template
	Data EmailData `json:"data"`

	// CreatedAt records when this job was enqueued
	CreatedAt time.Time `json:"created_at"`

	// Attempts tracks how many send attempts have been made (for retry logic)
	Attempts int `json:"attempts"`
}

// EmailData contains the template variables injected into HTML email templates.
// These map directly to the {{.FieldName}} placeholders in templates.
type EmailData struct {
	// To is the recipient's email address
	To string

	// Username is the display name shown in the email greeting (e.g. "john" or "john@example.com")
	Username string

	// AvatarURL is the user's profile picture URL (used in the welcome email profile card)
	AvatarURL string

	// Subject is the email subject (available for template use)
	Subject string

	// ActionURL is the primary CTA link (verify/reset/login URL)
	ActionURL string

	// AppName is the application display name (e.g. "Flicko")
	AppName string

	// AppURL is the application's base URL
	AppURL string

	// ValidFor describes how long the link is valid (e.g. "24 hours", "10 minutes")
	ValidFor string

	// MemberSince is the join date shown in the welcome email (e.g. "February 2026")
	MemberSince string

        // LogoURL is the URL for the app or server logo
        LogoURL string

	// TransactionID is the payment reference (e.g. "ch_3Nabc...")
	TransactionID string

	// TotalAmount is the formatted price paid (e.g. "$9.99")
	TotalAmount string

	// BillingCycle is the formatted billing cycle (e.g. "MONTHLY", "ANNUAL")
	BillingCycle string

	// Token is the verification code (e.g. "816327")
	Token string

	// Year is the current year for copyright notices
	Year int

	// --- Optional fields used by security & notification templates ---

	// Device describes the user-agent / device that triggered the event
	// (e.g. "iPhone 15 · iOS 17.4 · Safari")
	Device string

	// Location is a coarse geo location for security alerts (e.g. "Bengaluru, IN")
	Location string

	// IPAddress is the IP that triggered the event (e.g. "203.0.113.42")
	IPAddress string

	// Timestamp is a human-readable timestamp for the event
	// (e.g. "May 28, 2026 · 14:32 IST")
	Timestamp string

	// Message is free-form body content for the generic notification template
	Message string
}
