package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/flicko-org/mail-gateway/internal/mailer"
	"github.com/flicko-org/mail-gateway/internal/models"
	"github.com/flicko-org/mail-gateway/internal/templates"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables from .env
	godotenv.Load("../../../.env")

	host := os.Getenv("SMTP_HOST")
	port := os.Getenv("SMTP_PORT")
	username := os.Getenv("SMTP_USERNAME")
	password := os.Getenv("SMTP_PASSWORD")
	from := os.Getenv("SMTP_FROM")

	if host == "" || username == "" || password == "" {
		host = "smtp.gmail.com"
		port = "587"
		username = "flickochat@gmail.com"
		password = "xplt elyr dikl zvoi"
		from = "flickochat@gmail.com"
	}

	fmt.Printf("SMTP Config: Host=%s, Port=%s, User=%s, From=%s\n", host, port, username, from)

	// Initialize template renderer
	renderer, err := templates.NewRenderer("../../templates")
	if err != nil {
		log.Fatalf("Failed to initialize templates: %v", err)
	}

	// Initialize SMTP mailer
	smtpMailer := mailer.NewSMTPMailer(host, port, username, password, from, renderer)

	to := "bittutrial1@gmail.com"

	// List of templates to test
	templatesToTest := []struct {
		name    string
		subject string
		data    models.EmailData
	}{
		{
			name:    "welcome",
			subject: "[Flicko] Welcome to Flicko!",
			data: models.EmailData{
				To:          to,
				Username:    "bittutrial1",
				AppName:     "Flicko",
				ActionURL:   "io.flicko.app://login-callback/",
				AppURL:      "https://flicko.focko.tech",
				MemberSince: "May 2026",
				Year:        2026,
			},
		},
		{
			name:    "flicko_plus",
			subject: "[Flicko] ✨ Welcome to Flicko Plus — You're in!",
			data: models.EmailData{
				To:            to,
				Username:      "bittutrial1",
				AppName:       "Flicko",
				ActionURL:     "io.flicko.app://login-callback/",
				AppURL:        "https://flicko.focko.tech",
				TransactionID: "ch_test_flicko_plus_12345",
				BillingCycle:  "MONTHLY",
				TotalAmount:   "$9.99",
				Year:          2026,
			},
		},
		{
			name:    "verify",
			subject: "[Flicko] Verify your Flicko account",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_123&type=signup&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "reset",
			subject: "[Flicko] Reset your Flicko password",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_reset&type=recovery&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "magic_link",
			subject: "[Flicko] Your Flicko login link",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_magic&type=magiclink&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "confirm_email_change",
			subject: "[Flicko] Confirm your new Flicko email",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_email_change&type=email_change&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "invite",
			subject: "[Flicko] You've been invited to Flicko",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_invite&type=invite&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "reauthentication",
			subject: "[Flicko] Confirm your identity on Flicko",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://zliclxzqkopxgnlwlqsu.supabase.co/auth/v1/verify?token=test_token_reauth&type=reauthentication&redirect_to=io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "account_deleted",
			subject: "[Flicko] Account deleted",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				ActionURL: "https://flicko.focko.tech",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "notification",
			subject: "[Flicko] Notification: New updates available",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				Subject:   "SYSTEM UPDATE",
				Message:   "We have rolled out new features! Emojis have been fully replaced with pre-colored SVGs, and your dark mode templates are now better structured.",
				ActionURL: "io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "password_changed",
			subject: "[Flicko] Your password was changed",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				Timestamp: "May 28, 2026 · 22:00 IST",
				Device:    "Android Emulator · Pixel 8 Pro",
				IPAddress: "127.0.0.1",
				ActionURL: "io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "payment_failed",
			subject: "[Flicko] Payment failed - Action required",
			data: models.EmailData{
				To:            to,
				Username:      "bittutrial1",
				AppName:       "Flicko",
				TransactionID: "ch_test_failed_9876",
				BillingCycle:  "MONTHLY",
				TotalAmount:   "$9.99",
				ActionURL:     "https://flicko.focko.tech/billing",
				AppURL:        "https://flicko.focko.tech",
				Year:          2026,
			},
		},
		{
			name:    "security_alert",
			subject: "[Flicko] New sign-in detected on your Flicko account",
			data: models.EmailData{
				To:        to,
				Username:  "bittutrial1",
				AppName:   "Flicko",
				Device:    "Chrome Browser · Windows 11",
				Location:  "Bengaluru, IN",
				IPAddress: "203.0.113.55",
				Timestamp: "May 28, 2026 · 22:05 IST",
				ActionURL: "io.flicko.app://login-callback/",
				AppURL:    "https://flicko.focko.tech",
				Year:      2026,
			},
		},
		{
			name:    "subscription_canceled",
			subject: "[Flicko] Subscription canceled - We're sorry to see you go",
			data: models.EmailData{
				To:            to,
				Username:      "bittutrial1",
				AppName:       "Flicko",
				TransactionID: "ch_test_cancel_3456",
				BillingCycle:  "MONTHLY",
				TotalAmount:   "$9.99",
				ActionURL:     "https://flicko.focko.tech/billing",
				AppURL:        "https://flicko.focko.tech",
				Year:          2026,
			},
		},
		{
			name:    "upgrade",
			subject: "[Flicko] Subscription updated",
			data: models.EmailData{
				To:            to,
				Username:      "bittutrial1",
				AppName:       "Flicko",
				TransactionID: "ch_test_upg_4567",
				BillingCycle:  "MONTHLY",
				TotalAmount:   "$9.99",
				AppURL:        "https://flicko.focko.tech",
				Year:          2026,
			},
		},
	}

	for _, tc := range templatesToTest {
		fmt.Printf("Sending template %q to %s...\n", tc.name, to)
		err := smtpMailer.Send(to, tc.subject, tc.name, tc.data)
		if err != nil {
			log.Printf("Failed to send template %q: %v\n", tc.name, err)
		} else {
			fmt.Printf("Successfully sent template %q!\n", tc.name)
		}
		// Pause to prevent hitting SMTP relay limits too fast
		time.Sleep(1 * time.Second)
	}

	fmt.Println("All done!")
}
