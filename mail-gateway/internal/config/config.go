// Package config handles environment variable loading and validation.
// All configuration is loaded from .env files and environment variables.
// Missing required secrets cause a panic at startup (fail-fast pattern).
package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	// Server settings
	Port   string // HTTP server listen port
	AppEnv string // "development" or "production"

	// Application identity
	AppName string // Display name in email templates
	AppURL  string // Frontend URL for redirect links

	// Webhook security
	WebhookSecret string // HMAC-SHA256 signing secret from Supabase
	SendAPIKey    string // API key protecting the POST /send endpoint

	// Security: Development mode must be explicitly enabled
	EnableInsecureDevMode bool // Set ENABLE_INSECURE_DEV_MODE=true to bypass auth (dev only)

	// Azure Communication Services Email
	AzureCommunicationConnectionString string // Connection string for Azure Communication Services
	AzureCommunicationEmailSender       string // Sender address (e.g. DoNotReply@flicko.app)

	// SMTP configuration (Gmail)
	SMTPHost     string // SMTP server hostname (smtp.gmail.com)
	SMTPPort     string // SMTP server port (587 for STARTTLS)
	SMTPUsername string // Gmail address
	SMTPPassword string // Gmail App Password
	SMTPFrom     string // Sender email address

	// Email queue tuning
	QueueSize  int // Buffered channel capacity
	WorkerPool int // Number of concurrent worker goroutines
	MaxRetries int // Max send attempts per email job

	// Logging
	LogLevel  string // debug, info, warn, error
	LogFormat string // json or text

	// Supabase project URL (for building verification links)
	SupabaseURL string // e.g. https://xxxxx.supabase.co

	// Razorpay configuration
	RazorpayKeyID     string
	RazorpayKeySecret string

	// Moonclerk configuration
	MoonclerkWebhookSecret string
}


// Load reads environment variables from .env (if present) and returns
// a validated Config struct. Panics on missing required secrets.
func Load() *Config {
	// Load .env file if it exists — ignore errors in production
	if err := godotenv.Load(); err != nil {
		slog.Warn("no .env file found, using system environment variables")
	}

	cfg := &Config{
		Port:   getEnv("PORT", "8080"),
		AppEnv: getEnv("APP_ENV", "development"),

		AppName: getEnv("APP_NAME", "Flicko"),
		AppURL:  getEnv("APP_URL", "http://localhost:3000"),

		WebhookSecret: os.Getenv("WEBHOOK_SECRET"),
		SendAPIKey:    os.Getenv("SEND_API_KEY"),

		// Security fix: explicit dev mode flag required (not just missing SEND_API_KEY)
		EnableInsecureDevMode: os.Getenv("ENABLE_INSECURE_DEV_MODE") == "true",

		AzureCommunicationConnectionString: os.Getenv("AZURE_COMMUNICATION_CONNECTION_STRING"),
		AzureCommunicationEmailSender:       getEnv("AZURE_COMMUNICATION_EMAIL_SENDER", "DoNotReply@flicko.app"),

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUsername: os.Getenv("SMTP_USERNAME"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getEnv("SMTP_FROM", os.Getenv("SMTP_USERNAME")),
	}

	cfg.validate()
	return cfg
}

func (c *Config) validate() {
	if c.AppEnv == "production" && c.WebhookSecret == "" {
		panic("WEBHOOK_SECRET is required in production")
	}

	if c.AppEnv == "production" && c.SendAPIKey == "" && !c.EnableInsecureDevMode {
		panic("SEND_API_KEY is required in production.")
	}

	// If Azure Communication Services Connection String is set, ACS Email is enabled
	if c.AzureCommunicationConnectionString != "" {
		slog.Info("Azure Communication Services Email enabled for transactional emails")
		return
	}

	// Otherwise, fallback to SMTP credentials
	if c.SMTPUsername == "" {
		slog.Warn("SMTP_USERNAME not set — using dummy dev mailer")
	}

	// Supabase URL needed for building verification links
	if c.SupabaseURL == "" {
		slog.Warn("SUPABASE_URL not set — verification links will use APP_URL as fallback")
		c.SupabaseURL = c.AppURL
	}
}

// IsDevelopment returns true when running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.AppEnv == "development"
}

// getEnv reads an env var with a fallback default value.
func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

// getEnvInt reads an env var as integer with a fallback default.
func getEnvInt(key string, fallback int) int {
	val := os.Getenv(key)
	if val == "" {
		return fallback
	}
	n, err := strconv.Atoi(val)
	if err != nil {
		panic(fmt.Sprintf("%s must be a valid integer, got: %q", key, val))
	}
	return n
}
