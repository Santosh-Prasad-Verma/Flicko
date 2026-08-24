package services

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
)

// Claims represents the JWT payload for Flicko access tokens.
// This is compatible with the shared/auth.Claims struct used by msg-service
// and ws-gateway, ensuring cross-service token validation works correctly.
type Claims struct {
	jwt.RegisteredClaims
	Roles    []string `json:"roles,omitempty"`
	DeviceID string   `json:"did,omitempty"`
}

type AuthService interface {
	GenerateToken(userID, email string) (string, error)
	ValidateToken(tokenString string) (*Claims, error)
	HashPassword(password string) (string, error)
	CheckPassword(hash, password string) bool
	Register(ctx context.Context, username, email, phone, password string) (*models.User, string, error)
	Login(ctx context.Context, identifier, password string) (*models.User, string, error)
	VerifyEmail(ctx context.Context, email, token string) (*models.User, string, error)
	ResendVerification(ctx context.Context, email string) error
}

// signingMethod — Ed25519 (EdDSA), matching services/shared/auth/jwt.go.
var signingMethod = jwt.SigningMethodEdDSA

const (
	accessTokenTTL = 24 * time.Hour
	issuer         = "flicko"
)

type authService struct {
	db      database.DatabaseClient
	privKey ed25519.PrivateKey
	pubKeys map[string]ed25519.PublicKey // kid → public key
	kid     string                      // Key ID for the active private key
	mailSvc *MailService
}

// keyIDFromPublic derives a deterministic Key ID (kid) from an Ed25519 public key.
// Compatible with services/shared/auth.KeyIDFromPublic.
func keyIDFromPublic(pub ed25519.PublicKey) string {
	h := sha256.Sum256(pub)
	return hex.EncodeToString(h[:8])
}

// TestKeyIDFromPublic is exported for test packages to derive kid values.
func TestKeyIDFromPublic(pub ed25519.PublicKey) string {
	return keyIDFromPublic(pub)
}

func NewAuthService(db database.DatabaseClient, privKey ed25519.PrivateKey, pubKey ed25519.PublicKey, opts ...AuthOption) AuthService {
	kid := keyIDFromPublic(pubKey)
	svc := &authService{
		db:      db,
		privKey: privKey,
		pubKeys: map[string]ed25519.PublicKey{kid: pubKey},
		kid:     kid,
	}
	for _, opt := range opts {
		opt(svc)
	}
	return svc
}

type AuthOption func(*authService)

func WithMailService(mailSvc *MailService) AuthOption {
	return func(s *authService) {
		s.mailSvc = mailSvc
	}
}

func (s *authService) GenerateToken(userID, email string) (string, error) {
	now := time.Now().UTC()
	claims := &Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Issuer:    issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(accessTokenTTL)),
		},
	}

	token := jwt.NewWithClaims(signingMethod, claims)
	token.Header["kid"] = s.kid

	return token.SignedString(s.privKey)
}

func (s *authService) ValidateToken(tokenString string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		// Verify signing method.
		if t.Method.Alg() != signingMethod.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Method.Alg())
		}

		// Extract kid from header.
		kidRaw, ok := t.Header["kid"]
		if !ok {
			return nil, errors.New("token missing kid header")
		}
		kid, ok := kidRaw.(string)
		if !ok || kid == "" {
			return nil, errors.New("invalid kid header")
		}

		// Look up key.
		pub, exists := s.pubKeys[kid]
		if !exists {
			return nil, fmt.Errorf("unknown key ID: %s", kid)
		}

		return pub, nil
	},
		jwt.WithValidMethods([]string{signingMethod.Alg()}),
		jwt.WithIssuer(issuer),
		jwt.WithIssuedAt(),
		jwt.WithExpirationRequired(),
	)

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

func (s *authService) HashPassword(password string) (string, error) {
	if len(password) < 8 {
		return "", errors.New("password must be at least 8 characters long")
	}
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	return string(bytes), err
}

func (s *authService) CheckPassword(hash, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// generateVerificationCode returns a cryptographically random 6-digit code.
func generateVerificationCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", fmt.Errorf("failed to generate verification code: %w", err)
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// Register creates a new user in the users table (which triggers automatic
// profile creation via the handle_new_user() trigger), generates a verification
// code, and sends a verification email.
//
// The live Azure PostgreSQL users table does NOT have a username column —
// username is stored in the profiles table via raw_user_meta_data->>'username'.
func (s *authService) Register(ctx context.Context, username, email, phone, password string) (*models.User, string, error) {
	if utf8.RuneCountInString(username) < 2 || utf8.RuneCountInString(username) > 32 {
		return nil, "", errors.New("username must be between 2 and 32 characters")
	}

	email = strings.TrimSpace(email)
	if email == "" {
		return nil, "", errors.New("email is required for registration")
	}

	_, err := mail.ParseAddress(email)
	if err != nil {
		return nil, "", errors.New("invalid email format")
	}

	hash, err := s.HashPassword(password)
	if err != nil {
		return nil, "", err
	}

	// Generate a 6-digit verification code
	verificationCode, err := generateVerificationCode()
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate verification code: %w", err)
	}

	// Insert into users table — the handle_new_user() trigger automatically
	// creates a profile row with the username from raw_user_meta_data.
	// The phone parameter is passed as NULL if empty to avoid unique constraint issues.
	query := `
		INSERT INTO users (email, phone, encrypted_password, raw_user_meta_data, verification_token, verification_token_expires_at)
		VALUES ($1, NULLIF($2, ''), $3, jsonb_build_object('username', $4), $5, NOW() + INTERVAL '30 minutes')
		RETURNING id, COALESCE(email, ''), created_at, updated_at
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, email, phone, hash, username, verificationCode)
	err = row.Scan(&user.ID, &user.Email, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create user: %w", err)
	}

	// Fetch username from the auto-created profile
	profileQuery := `SELECT username, discriminator FROM profiles WHERE id = $1`
	profileRow := s.db.QueryRow(ctx, profileQuery, user.ID)
	err = profileRow.Scan(&user.Username, &user.Discriminator)
	if err != nil {
		// Non-fatal — user was created, profile trigger may have failed
		user.Username = username
	}

	// Send verification email (not welcome email) — verification must happen first
	if s.mailSvc != nil && user.Email != "" {
		go func(toEmail, toUsername, code string) {
			if err := s.mailSvc.SendVerificationEmail(toEmail, toUsername, code); err != nil {
				zap.L().Error("failed to send verification email during register", zap.String("email", toEmail), zap.Error(err))
			} else {
				zap.L().Info("verification email dispatched", zap.String("email", toEmail))
			}
		}(user.Email, user.Username, verificationCode)
	}

	// Email is unverified; return user without active token to enforce verification
	return &user, "", nil
}

// VerifyEmail validates the verification code, marks the user's email as confirmed,
// and issues a valid JWT access token.
func (s *authService) VerifyEmail(ctx context.Context, email, token string) (*models.User, string, error) {
	if email == "" || token == "" {
		return nil, "", errors.New("email and verification code are required")
	}

	if s.db == nil {
		// Mock testing mode
		return &models.User{Email: email, Username: "testuser"}, "mock-token", nil
	}

	// Verify the token matches and hasn't expired
	query := `
		UPDATE users
		SET email_confirmed_at = NOW(),
		    verification_token = NULL,
		    verification_token_expires_at = NULL,
		    updated_at = NOW()
		WHERE email = $1
		  AND verification_token = $2
		  AND (verification_token_expires_at IS NULL OR verification_token_expires_at > NOW())
		  AND email_confirmed_at IS NULL
		RETURNING id, COALESCE(email, ''), created_at, updated_at
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, email, token)
	err := row.Scan(&user.ID, &user.Email, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, "", errors.New("invalid or expired verification code")
		}
		return nil, "", fmt.Errorf("failed to verify email: %w", err)
	}

	// Fetch username from the profile
	profileQuery := `SELECT username, discriminator FROM profiles WHERE id = $1`
	profileRow := s.db.QueryRow(ctx, profileQuery, user.ID)
	err = profileRow.Scan(&user.Username, &user.Discriminator)
	if err != nil {
		user.Username = strings.Split(user.Email, "@")[0]
	}

	jwtToken, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	// Send welcome email now that email is verified
	if s.mailSvc != nil && user.Email != "" {
		go func(toEmail, toUsername string) {
			if err := s.mailSvc.SendWelcomeEmail(toEmail, toUsername); err != nil {
				zap.L().Error("failed to send welcome email after verification", zap.String("email", toEmail), zap.Error(err))
			} else {
				zap.L().Info("welcome email dispatched", zap.String("email", toEmail))
			}
		}(user.Email, user.Username)
	}

	return &user, jwtToken, nil
}

// ResendVerification generates a new verification code and sends it to the user's email.
func (s *authService) ResendVerification(ctx context.Context, email string) error {
	if email == "" {
		return errors.New("email is required")
	}

	// Check if user exists and email is not already verified
	var userID string
	var username string
	var emailConfirmedAt *time.Time

	checkQuery := `
		SELECT u.id, p.username, u.email_confirmed_at
		FROM users u
		JOIN profiles p ON p.id = u.id
		WHERE u.email = $1
	`
	row := s.db.QueryRow(ctx, checkQuery, email)
	err := row.Scan(&userID, &username, &emailConfirmedAt)
	if err != nil {
		return errors.New("user not found")
	}

	if emailConfirmedAt != nil {
		return errors.New("email is already verified")
	}

	// Generate new verification code
	verificationCode, err := generateVerificationCode()
	if err != nil {
		return fmt.Errorf("failed to generate verification code: %w", err)
	}

	// Update the verification token
	updateQuery := `
		UPDATE users
		SET verification_token = $1,
		    verification_token_expires_at = NOW() + INTERVAL '30 minutes',
		    updated_at = NOW()
		WHERE email = $2
	`
	_, err = s.db.Exec(ctx, updateQuery, verificationCode, email)
	if err != nil {
		return fmt.Errorf("failed to update verification token: %w", err)
	}

	// Send verification email
	if s.mailSvc != nil {
		go func(toEmail, toUsername, code string) {
			if err := s.mailSvc.SendVerificationEmail(toEmail, toUsername, code); err != nil {
				zap.L().Error("failed to resend verification email", zap.String("email", toEmail), zap.Error(err))
			} else {
				zap.L().Info("resend verification email dispatched", zap.String("email", toEmail))
			}
		}(email, username, verificationCode)
	}

	return nil
}

// Login authenticates a user by email, username, or phone and returns the user
// with a JWT token. Requires email to be verified (email_confirmed_at IS NOT NULL).
//
// The live schema has username in the profiles table, so we JOIN users + profiles.
func (s *authService) Login(ctx context.Context, identifier, password string) (*models.User, string, error) {
	query := `
		SELECT u.id, p.username, COALESCE(u.email, ''), u.encrypted_password,
		       u.email_confirmed_at, u.created_at, u.updated_at
		FROM users u
		JOIN profiles p ON p.id = u.id
		WHERE u.email = $1 OR p.username = $1 OR u.phone = $1
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, identifier)
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.Password,
		&user.EmailConfirmedAt, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", errors.New("invalid credentials")
	}

	if !s.CheckPassword(user.Password, password) {
		return nil, "", errors.New("invalid credentials")
	}

	// Check if email is verified
	if user.EmailConfirmedAt == nil {
		return nil, "", errors.New("email not verified — please check your inbox for the verification code")
	}

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	user.Password = ""

	return &user, token, nil
}
