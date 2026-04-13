package services

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
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
	Register(ctx context.Context, username, email, password string) (*models.User, string, error)
	Login(ctx context.Context, email, password string) (*models.User, string, error)
}

type authService struct {
	db     database.DatabaseClient
	secret []byte
}

func NewAuthService(db database.DatabaseClient, jwtSecret string, opts ...AuthOption) AuthService {
	// Supabase JWT secrets are base64-encoded. Try to decode; fall back to raw string.
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

// AuthOption configures optional auth service settings.
type AuthOption func(*authService)

// WithSupabase enables Supabase token validation as fallback.
func WithSupabase(supabaseURL, supabaseAPIKey string) AuthOption {
	return func(s *authService) {
		// Set options discarded. Removed per architecture review.
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
	// 1. Try local HMAC (HS256) validation first
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

	// 2. If HMAC validation fails and Supabase is configured, verify via Supabase Auth API.
	//    This handles tokens signed with ES256 (ECC P-256) after key rotation.
	//    Removed per architecture review report (unified HS256 validation only).
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

func (s *authService) Register(ctx context.Context, username, email, password string) (*models.User, string, error) {
	if utf8.RuneCountInString(username) < 2 || utf8.RuneCountInString(username) > 32 {
		return nil, "", errors.New("username must be between 2 and 32 characters")
	}

	_, err := mail.ParseAddress(email)
	if err != nil {
		return nil, "", errors.New("invalid email format")
	}

	hash, err := s.HashPassword(password)
	if err != nil {
		return nil, "", err
	}

	// CRIT-002: Use parameterized query with proper pgx row scanning
	query := `
		INSERT INTO users (username, email, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, username, email, theme, created_at, updated_at
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, username, email, hash)
	err = row.Scan(&user.ID, &user.Username, &user.Email, &user.Theme, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create user: %w", err)
	}

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	return &user, token, nil
}

func (s *authService) Login(ctx context.Context, email, password string) (*models.User, string, error) {
	// CRIT-002: Proper login implementation with parameterized query
	query := `
		SELECT id, username, email, password_hash, theme, created_at, updated_at
		FROM users
		WHERE email = $1
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, email)
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.Password, &user.Theme, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		// Don't reveal whether email exists
		return nil, "", errors.New("invalid email or password")
	}

	if !s.CheckPassword(user.Password, password) {
		return nil, "", errors.New("invalid email or password")
	}

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	// Clear password from response
	user.Password = ""

	return &user, token, nil
}
