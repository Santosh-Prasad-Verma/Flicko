package auth

import (
"encoding/base64"
"errors"
"fmt"

"github.com/golang-jwt/jwt/v5"
)

var (
ErrInvalidAlgorithm = errors.New("auth: invalid signing algorithm, expected HS256")
)

type JWTValidator struct {
secret []byte
}

func NewJWTValidator(secret string) (*JWTValidator, error) {
if secret == "" {
return nil, errors.New("auth: JWT secret cannot be empty")
}

decoded, err := base64.StdEncoding.DecodeString(secret)
if err != nil {
decoded = []byte(secret)
}

return &JWTValidator{secret: decoded}, nil
}

func (v *JWTValidator) ValidateToken(tokenString string) (*jwt.RegisteredClaims, error) {
token, err := jwt.ParseWithClaims(tokenString, &jwt.RegisteredClaims{}, func(token *jwt.Token) (interface{}, error) {
if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
return nil, ErrInvalidAlgorithm
}
return v.secret, nil
})

if err != nil {
return nil, fmt.Errorf("invalid token: %w", err)
}

if claims, ok := token.Claims.(*jwt.RegisteredClaims); ok && token.Valid {
return claims, nil
}

return nil, errors.New("invalid claims")
}
