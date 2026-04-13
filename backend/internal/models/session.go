package models

import "time"

type Session struct {
	ID           string    `json:"id" db:"id"`
	UserID       string    `json:"user_id" db:"user_id"`
	DeviceInfo   *string   `json:"device_info,omitempty" db:"device_info"`
	IPAddress    *string   `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent    *string   `json:"user_agent,omitempty" db:"user_agent"`
	RefreshToken string    `json:"-" db:"refresh_token"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	LastActivity time.Time `json:"last_activity" db:"last_activity"`
	ExpiresAt    time.Time `json:"expires_at" db:"expires_at"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

type SessionCreateRequest struct {
	UserID     string
	DeviceInfo string
	IPAddress  string
	UserAgent  string
}
