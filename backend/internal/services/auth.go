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
	Register(ctx context.Context, username, email, phone, password string) (*models.User, string, error)
	Login(ctx context.Context, identifier, password string) (*models.User, string, error)
}

type authService struct {
	db     database.DatabaseClient
	secret []byte
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

func WithSupabase(supabaseURL, supabaseAPIKey string) AuthOption {
	return func(s *authService) {
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

	query := `
		INSERT INTO users (username, email, phone, encrypted_password)
		VALUES ($1, $2, $3, $4)
		RETURNING id, username, COALESCE(email, ''), created_at, updated_at
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, username, email, phone, hash)
	err = row.Scan(&user.ID, &user.Username, &user.Email, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create user: %w", err)
	}

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	return &user, token, nil
}

func (s *authService) Login(ctx context.Context, identifier, password string) (*models.User, string, error) {
	query := `
		SELECT id, username, COALESCE(email, ''), encrypted_password, created_at, updated_at
		FROM users
		WHERE email = $1 OR username = $1 OR phone = $1
	`

	var user models.User
	row := s.db.QueryRow(ctx, query, identifier)
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.Password, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", errors.New("invalid credentials")
	}

	if !s.CheckPassword(user.Password, password) {
		return nil, "", errors.New("invalid credentials")
	}

	token, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate token: %w", err)
	}

	user.Password = ""

	return &user, token, nil
}
