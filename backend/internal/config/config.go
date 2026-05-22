package config

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
)

type Config struct {
	DatabaseURL        string
	RedisURL           string
	JWTSecret          string
	PortHTTP           string
	PortWS             string
	SupabaseURL        string
	SupabaseServiceKey string
	EncryptionKey      []byte
	EncryptionKeyID    string
	Environment        string
	LiveKitAPIKey      string
	LiveKitAPISecret   string
	LiveKitURL         string
	RazorpayKeyID      string
	RazorpayKeySecret  string
	MailGatewayURL     string
	InternalToken      string
	// E2EE v2 rollout (Task 3 / R16)
	E2EEV2Enabled        bool
	E2EEV2RolloutPercent int // 0..100; clients with hash(user_id)%100 < this opt in
}

func Load() (*Config, error) {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "development"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, errors.New("DATABASE_URL is required")
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		return nil, errors.New("REDIS_URL is required")
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		return nil, errors.New("JWT_SECRET is required")
	}
	if len(jwtSecret) < 32 {
		return nil, errors.New("JWT_SECRET must be at least 32 characters long")
	}

	portHTTP := os.Getenv("PORT_HTTP")
	if portHTTP == "" {
		portHTTP = "8080"
	}

	portWS := os.Getenv("PORT_WS")
	if portWS == "" {
		portWS = "8081"
	}

	supabaseURL := os.Getenv("SUPABASE_URL")
	if supabaseURL == "" {
		return nil, errors.New("SUPABASE_URL is required")
	}

	supabaseServiceKey := os.Getenv("SUPABASE_SERVICE_ROLE_KEY")
	if supabaseServiceKey == "" {
		return nil, errors.New("SUPABASE_SERVICE_ROLE_KEY is required")
	}

	// CRIT-010: Encryption key is REQUIRED in production
	var encryptionKeyBytes []byte
	var keyIDHex string
	encryptionKey := os.Getenv("ENCRYPTION_KEY")
	if encryptionKey == "" {
		if environment == "production" {
			return nil, errors.New("ENCRYPTION_KEY is required in production. Generate with: openssl rand -hex 32")
		}
		// Generate ephemeral key for development only
		log.Println("WARNING: ENCRYPTION_KEY not set — using ephemeral key (DEV ONLY)")
		encryptionKeyBytes = make([]byte, 32)
		if _, err := rand.Read(encryptionKeyBytes); err != nil {
			return nil, fmt.Errorf("failed to generate ephemeral key: %w", err)
		}
	} else {
		var decErr error
		encryptionKeyBytes, decErr = hex.DecodeString(encryptionKey)
		if decErr != nil {
			return nil, errors.New("ENCRYPTION_KEY must be valid hex. Generate with: openssl rand -hex 32")
		}
		if len(encryptionKeyBytes) != 32 {
			return nil, errors.New("ENCRYPTION_KEY must be exactly 64 hex characters (32 bytes)")
		}

		// Validate key entropy (basic check)
		uniqueBytes := make(map[byte]bool)
		for _, b := range encryptionKeyBytes {
			uniqueBytes[b] = true
		}
		if len(uniqueBytes) < 16 {
			return nil, errors.New("ENCRYPTION_KEY has insufficient entropy (too many repeated bytes)")
		}
	}

	// Store key ID for rotation support
	keyID := sha256.Sum256(encryptionKeyBytes)
	keyIDHex = hex.EncodeToString(keyID[:8])

	return &Config{
		DatabaseURL:        dbURL,
		RedisURL:           redisURL,
		JWTSecret:          jwtSecret,
		PortHTTP:           portHTTP,
		PortWS:             portWS,
		SupabaseURL:        supabaseURL,
		SupabaseServiceKey: supabaseServiceKey,
		EncryptionKey:      encryptionKeyBytes,
		EncryptionKeyID:    keyIDHex,
		Environment:        environment,
		LiveKitAPIKey:      os.Getenv("LIVEKIT_API_KEY"),
		LiveKitAPISecret:   os.Getenv("LIVEKIT_API_SECRET"),
		LiveKitURL:         os.Getenv("LIVEKIT_URL"),
		RazorpayKeyID:      os.Getenv("RAZORPAY_KEY_ID"),
		RazorpayKeySecret:  os.Getenv("RAZORPAY_KEY_SECRET"),
		MailGatewayURL:     os.Getenv("MAIL_GATEWAY_URL"),
		InternalToken:      os.Getenv("INTERNAL_TOKEN"),
		E2EEV2Enabled:      parseBoolEnv("E2EE_V2_ENABLED", false),
		E2EEV2RolloutPercent: parseIntEnv("E2EE_V2_ROLLOUT_PERCENT", 0, 0, 100),
	}, nil
}

// parseBoolEnv returns def when the env var is unset; otherwise returns
// the parsed bool. Invalid values are treated as `def` and logged.
func parseBoolEnv(key string, def bool) bool {
	raw := os.Getenv(key)
	if raw == "" {
		return def
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		log.Printf("WARNING: %s=%q is not a valid bool; using default %v", key, raw, def)
		return def
	}
	return v
}

// parseIntEnv returns def when the env var is unset or invalid. Clamps to [min,max].
func parseIntEnv(key string, def, min, max int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return def
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		log.Printf("WARNING: %s=%q is not a valid int; using default %d", key, raw, def)
		return def
	}
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
