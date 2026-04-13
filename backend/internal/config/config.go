package config

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
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

	// Cloudinary media storage (signed uploads)
	CloudinaryCloudName string
	CloudinaryAPIKey    string
	CloudinaryAPISecret string
	CloudinaryPreset    string
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

	// Cloudinary configuration
	cloudinaryCloudName := os.Getenv("CLOUDINARY_CLOUD_NAME")
	if cloudinaryCloudName == "" {
		return nil, errors.New("CLOUDINARY_CLOUD_NAME is required")
	}
	cloudinaryAPIKey := os.Getenv("CLOUDINARY_API_KEY")
	if cloudinaryAPIKey == "" {
		return nil, errors.New("CLOUDINARY_API_KEY is required")
	}
	cloudinaryAPISecret := os.Getenv("CLOUDINARY_API_SECRET")
	if cloudinaryAPISecret == "" {
		return nil, errors.New("CLOUDINARY_API_SECRET is required")
	}
	cloudinaryPreset := os.Getenv("CLOUDINARY_UPLOAD_PRESET")
	if cloudinaryPreset == "" {
		cloudinaryPreset = "flickochat_media"
	}

	return &Config{
		DatabaseURL:         dbURL,
		RedisURL:            redisURL,
		JWTSecret:           jwtSecret,
		PortHTTP:            portHTTP,
		PortWS:              portWS,
		SupabaseURL:         supabaseURL,
		SupabaseServiceKey:  supabaseServiceKey,
		EncryptionKey:       encryptionKeyBytes,
		EncryptionKeyID:     keyIDHex,
		Environment:         environment,
		CloudinaryCloudName: cloudinaryCloudName,
		CloudinaryAPIKey:    cloudinaryAPIKey,
		CloudinaryAPISecret: cloudinaryAPISecret,
		CloudinaryPreset:    cloudinaryPreset,
	}, nil
}
