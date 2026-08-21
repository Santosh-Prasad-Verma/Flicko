package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"math/big"
	"net/mail"
	"time"
	"unicode/utf8"

	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type AuthService interface {
	GenerateToken(userID, email string) (string, error)
	ValidateToken(tokenString string) (*jwt.RegisteredClaims, error)
	HashPassword(password string) (string, error)
	CheckPassword(hash, password string) bool
	Register(ctx context.Context, username, email, phone, password string) (*models.User, string, error)
	Login(ctx context.Context, identifier, password string) (*models.User, string, error)
	VerifyEmail(ctx context.Context, email, token string) error
	ResendVerification(ctx context.Context, email string) error
}

type authService struct {
	db      database.DatabaseClient
	secret  []byte
	mailSvc *MailService
}

func NewAuthService(db database.DatabaseClient, jwtSecret string, opts ...AuthOption) AuthService {
	secret, err := base64.StdEncoding.DecodeString(jwtSecret)
	if err != nil {
		secret = []byte(jwtSecret)
	}
	svc := &authService{
		db:     db,
		secret: secret,
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
	claims := jwt.MapClaims{
		"sub":   userID,
		"email": email,
		"iss":   "flicko-backend",
		"exp":   time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat":   time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.secret)
}

func (s *authService) ValidateToken(tokenString string) (*jwt.RegisteredClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &jwt.RegisteredClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.secret, nil
	})

	if err == nil {
		if claims, ok := token.Claims.(*jwt.RegisteredClaims); ok && token.Valid {
			return claims, nil
		}
	}
	return nil, err
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

	if email != "" {
		_, err := mail.ParseAddress(email)
		if err != nil {
			return nil, "", errors.New("invalid email format")
		}
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
		VALUES ($1, NULLIF($2, ''), $3, jsonb_build_object('username', $4), $5, NOW() + INTERVAL '24 hours')
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

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	// Send verification email (not welcome email) — verification must happen first
	if s.mailSvc != nil && user.Email != "" {
		go func(toEmail, toUsername, code string) {
			_ = s.mailSvc.SendVerificationEmail(toEmail, toUsername, code)
		}(user.Email, user.Username, verificationCode)
	}

	return &user, token, nil
}

// VerifyEmail validates the verification code and marks the user's email as confirmed.
func (s *authService) VerifyEmail(ctx context.Context, email, token string) error {
	if email == "" || token == "" {
		return errors.New("email and verification code are required")
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
		  AND verification_token_expires_at > NOW()
		  AND email_confirmed_at IS NULL
	`

	result, err := s.db.Exec(ctx, query, email, token)
	if err != nil {
		return fmt.Errorf("failed to verify email: %w", err)
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("invalid or expired verification code")
	}

	return nil
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
		    verification_token_expires_at = NOW() + INTERVAL '24 hours',
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
			_ = s.mailSvc.SendVerificationEmail(toEmail, toUsername, code)
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
