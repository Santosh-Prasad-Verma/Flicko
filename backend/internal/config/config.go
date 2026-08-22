package config

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DatabaseURL                     string
	RedisURL                        string
	JWTSecret                       string
	PortHTTP                        string
	PortWS                          string
	AzureBlobConnectionString       string
	AzureWebPubSubConnectionString  string
	AzureCommunicationConnectionString string
	AzureCosmosEndpoint             string
	AzureCosmosKey                  string
	AzureCosmosDatabaseName         string
	EncryptionKey                   []byte
	EncryptionKeyID                 string
	Environment                     string
	RazorpayKeyID                   string
	RazorpayKeySecret               string
	MailGatewayURL                  string
	InternalToken                   string
	CentrifugoAPIURL                string // e.g. http://centrifugo:8000/api
	CentrifugoAPIKey                string
	// E2EE v2 rollout (Task 3 / R16)
	E2EEV2Enabled        bool
	E2EEV2RolloutPercent int // 0..100; clients with hash(user_id)%100 < this opt in

	// AI / LLM (Google Gemini for message-summary, Aura assistant, moderation)
	GeminiAPIKey     string
	GeminiBaseURL    string // default https://generativelanguage.googleapis.com/v1beta/openai
	GeminiModel      string // default gemini-2.5-flash
	AIRequestTimeout time.Duration // default 12s

	// Feature flags
	AIMessageSummaryEnabled bool
	AIAutoTranslateEnabled  bool
	AIModerationEnabled     bool
	ActivitiesWatchTogetherEnabled bool
	ActivitiesMusicPartyEnabled    bool

	// Auto-translate
	LibreTranslateBaseURL string // default http://libretranslate:5000
	LibreTranslateAPIKey  string // optional
	DeepLAPIKey           string // optional fallback

	// Astra DB
	AstraDBEndpoint string
	AstraDBToken    string
	FlickoGeminiAPIKey string

	// Ed25519 signing keys for cross-service JWT auth.
	// In production: loaded from ED25519_PRIVATE_KEY / ED25519_PUBLIC_KEY env vars (hex-encoded).
	// In development: ephemeral keypair generated at startup.
	Ed25519PrivateKey ed25519.PrivateKey
	Ed25519PublicKey  ed25519.PublicKey
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

	// Ed25519 signing keypair for JWT tokens (cross-service compatible with shared/auth).
	var ed25519Priv ed25519.PrivateKey
	var ed25519Pub ed25519.PublicKey

	ed25519PrivHex := os.Getenv("ED25519_PRIVATE_KEY")
	ed25519PubHex := os.Getenv("ED25519_PUBLIC_KEY")

	if ed25519PrivHex != "" && ed25519PubHex != "" {
		privBytes, err := hex.DecodeString(ed25519PrivHex)
		if err != nil {
			return nil, errors.New("ED25519_PRIVATE_KEY must be valid hex")
		}
		if len(privBytes) != ed25519.PrivateKeySize {
			return nil, fmt.Errorf("ED25519_PRIVATE_KEY must be %d bytes (got %d)", ed25519.PrivateKeySize, len(privBytes))
		}
		ed25519Priv = ed25519.PrivateKey(privBytes)

		pubBytes, err := hex.DecodeString(ed25519PubHex)
		if err != nil {
			return nil, errors.New("ED25519_PUBLIC_KEY must be valid hex")
		}
		if len(pubBytes) != ed25519.PublicKeySize {
			return nil, fmt.Errorf("ED25519_PUBLIC_KEY must be %d bytes (got %d)", ed25519.PublicKeySize, len(pubBytes))
		}
		ed25519Pub = ed25519.PublicKey(pubBytes)
	} else {
		if environment == "production" {
			return nil, errors.New("ED25519_PRIVATE_KEY and ED25519_PUBLIC_KEY are required in production. Generate with: go run crypto/ed25519 generate")
		}
		// Generate ephemeral keypair for development only.
		log.Println("WARNING: ED25519 keys not set — using ephemeral keypair (DEV ONLY)")
		var err error
		ed25519Pub, ed25519Priv, err = ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, fmt.Errorf("failed to generate ephemeral Ed25519 keypair: %w", err)
		}
	}

	azureBlobConn := os.Getenv("AZURE_BLOB_CONNECTION_STRING")
	azureWebPubSubConn := os.Getenv("AZURE_WEBPUBSUB_CONNECTION_STRING")

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

	geminiKey := os.Getenv("FLICKO_GEMINI_API_KEY")
	if geminiKey == "" {
		geminiKey = os.Getenv("GEMINI_API_KEY")
	}

	cfg := &Config{
		DatabaseURL:                    dbURL,
		RedisURL:                       redisURL,
		JWTSecret:                      jwtSecret,
		PortHTTP:                       portHTTP,
		PortWS:                         portWS,
		AzureBlobConnectionString:          azureBlobConn,
		AzureWebPubSubConnectionString:     azureWebPubSubConn,
		AzureCommunicationConnectionString: envOr("AZURE_COMMUNICATION_CONNECTION_STRING", ""),
		AzureCosmosEndpoint:            envOr("AZURE_COSMOS_ENDPOINT", ""),
		AzureCosmosKey:                 os.Getenv("AZURE_COSMOS_KEY"),
		AzureCosmosDatabaseName:        envOr("AZURE_COSMOS_DATABASE_NAME", "flicko_db"),
		EncryptionKey:                  encryptionKeyBytes,
		EncryptionKeyID:                keyIDHex,
		Environment:        environment,
		RazorpayKeyID:      os.Getenv("RAZORPAY_KEY_ID"),
		RazorpayKeySecret:  os.Getenv("RAZORPAY_KEY_SECRET"),
		MailGatewayURL:     os.Getenv("MAIL_GATEWAY_URL"),
		InternalToken:      os.Getenv("INTERNAL_TOKEN"),
		CentrifugoAPIURL:   os.Getenv("CENTRIFUGO_API_URL"),
		CentrifugoAPIKey:   os.Getenv("CENTRIFUGO_API_KEY"),
		E2EEV2Enabled:      parseBoolEnv("E2EE_V2_ENABLED", false),
		E2EEV2RolloutPercent: parseIntEnv("E2EE_V2_ROLLOUT_PERCENT", 0, 0, 100),
		AstraDBEndpoint:    envOr("ASTRA_DB_API_ENDPOINT", ""),
		AstraDBToken:       envOr("ASTRA_DB_APPLICATION_TOKEN", ""),
		FlickoGeminiAPIKey: geminiKey,
		GeminiAPIKey:       geminiKey,
		GeminiBaseURL:      envOr("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai"),
		GeminiModel:        envOr("GEMINI_MODEL", envOr("FLICKO_GEMINI_TEXT_MODEL", "gemini-2.5-flash")),
		AIRequestTimeout:   time.Duration(parseIntEnv("AI_REQUEST_TIMEOUT_SECONDS", 12, 1, 120)) * time.Second,
		AIMessageSummaryEnabled: parseBoolEnv("FEATURE_AI_MESSAGE_SUMMARY", false),
		AIAutoTranslateEnabled:  parseBoolEnv("FEATURE_AI_AUTO_TRANSLATE", false),
		AIModerationEnabled:     parseBoolEnv("FEATURE_AI_MODERATION", false),
		ActivitiesWatchTogetherEnabled: parseBoolEnv("FEATURE_ACTIVITIES_WATCH_TOGETHER", true),
		ActivitiesMusicPartyEnabled:    parseBoolEnv("FEATURE_ACTIVITIES_MUSIC_PARTY", true),
		LibreTranslateBaseURL: envOr("LIBRETRANSLATE_BASE_URL", "http://libretranslate:5000"),
		LibreTranslateAPIKey:  os.Getenv("LIBRETRANSLATE_API_KEY"),
		DeepLAPIKey:           os.Getenv("DEEPL_API_KEY"),
		Ed25519PrivateKey:     ed25519Priv,
		Ed25519PublicKey:      ed25519Pub,
	}

	return cfg, nil
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
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
