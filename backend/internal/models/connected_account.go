package models

import "time"

type ConnectedAccount struct {
	ID               string     `json:"id" db:"id"`
	UserID           string     `json:"user_id" db:"user_id"`
	Provider         string     `json:"provider" db:"provider"`
	ExternalUserID   string     `json:"external_user_id" db:"external_user_id"`
	ExternalUsername *string    `json:"external_username,omitempty" db:"external_username"`
	AccessToken      string     `json:"-" db:"access_token"`
	RefreshToken     *string    `json:"-" db:"refresh_token"`
	TokenExpiresAt   *time.Time `json:"token_expires_at,omitempty" db:"token_expires_at"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}
