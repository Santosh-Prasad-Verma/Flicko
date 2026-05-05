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

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUsername: os.Getenv("SMTP_USERNAME"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     os.Getenv("SMTP_FROM"),

		QueueSize:  getEnvInt("EMAIL_QUEUE_SIZE", 100),
		WorkerPool: getEnvInt("EMAIL_WORKER_POOL", 3),
		MaxRetries: getEnvInt("EMAIL_MAX_RETRIES", 3),

		LogLevel:  getEnv("LOG_LEVEL", "info"),
		LogFormat: getEnv("LOG_FORMAT", "json"),

		SupabaseURL: os.Getenv("SUPABASE_URL"),
		
		RazorpayKeyID:     os.Getenv("RAZORPAY_KEY_ID"),
		RazorpayKeySecret: os.Getenv("RAZORPAY_KEY_SECRET"),

		MoonclerkWebhookSecret: os.Getenv("MOONCLERK_WEBHOOK_SECRET"),
	}


	cfg.validate()
	return cfg
}

// validate ensures all required secrets are present.
// Panics on missing required values — this is intentional fail-fast behavior.
func (c *Config) validate() {
	// In production, WEBHOOK_SECRET is mandatory for security
	if c.AppEnv == "production" && c.WebhookSecret == "" {
		panic("WEBHOOK_SECRET is required in production — get it from Supabase Auth Hook dashboard")
	}

	// SECURITY FIX: Stricter SEND_API_KEY validation
	// In production, either SEND_API_KEY must be set OR explicit dev mode must be enabled
	if c.AppEnv == "production" && c.SendAPIKey == "" && !c.EnableInsecureDevMode {
		panic("SEND_API_KEY is required in production. Options:\n" +
			"  1. Set SEND_API_KEY env var (recommended)\n" +
			"  2. Set ENABLE_INSECURE_DEV_MODE=true (development only, not recommended for prod)")
	}

	// Warn if dev mode is accidentally enabled in production
	if c.AppEnv == "production" && c.EnableInsecureDevMode {
		slog.Warn("WARNING: ENABLE_INSECURE_DEV_MODE is enabled in production",
			"severity", "high",
			"action", "change APP_ENV to 'development' or disable ENABLE_INSECURE_DEV_MODE",
		)
	}

	// Warn if no SEND_API_KEY is set
	if c.SendAPIKey == "" && !c.EnableInsecureDevMode {
		slog.Warn("SEND_API_KEY not set and development mode disabled",
			"hint", "set SEND_API_KEY or ENABLE_INSECURE_DEV_MODE=true",
		)
	}

	// SMTP credentials are always required
	if c.SMTPUsername == "" {
		panic("SMTP_USERNAME is required — set your Gmail address")
	}
	if c.SMTPPassword == "" {
		panic("SMTP_PASSWORD is required — generate a Gmail App Password at myaccount.google.com → Security → App Passwords")
	}
	if c.SMTPFrom == "" {
		// Default to SMTP username if FROM not set
		c.SMTPFrom = c.SMTPUsername
	}

	// Supabase URL needed for building verification links
	if c.SupabaseURL == "" {
		slog.Warn("SUPABASE_URL not set — verification links will use APP_URL as fallback")
		c.SupabaseURL = c.AppURL
	}
	
	// Razorpay credentials
	if c.RazorpayKeyID == "" {
		slog.Warn("RAZORPAY_KEY_ID not set — payment features will be disabled")
	}
	if c.RazorpayKeySecret == "" {
		slog.Warn("RAZORPAY_KEY_SECRET not set — payment verification will fail")
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
