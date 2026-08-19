package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid or expired jwt token")
	ErrMissingSub   = errors.New("token missing subject claim")
)

type JWTClaims struct {
	UserID string `json:"sub"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

type JWTValidator interface {
	ValidateToken(tokenString string) (*JWTClaims, error)
}

type jwtValidator struct {
	secretKey []byte
}

func NewJWTValidator(secretKey string) JWTValidator {
	return &jwtValidator{
		secretKey: []byte(secretKey),
	}
}

func (v *jwtValidator) ValidateToken(tokenString string) (*JWTClaims, error) {
	if tokenString == "" {
		return nil, ErrInvalidToken
	}

	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return v.secretKey, nil
	})

	if err != nil || !token.Valid {
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok || claims.UserID == "" {
		return nil, ErrMissingSub
	}

	if claims.ExpiresAt != nil && claims.ExpiresAt.Before(time.Now()) {
		return nil, ErrInvalidToken
	}

	return claims, nil
}
