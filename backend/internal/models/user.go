package models

import (
	"encoding/json"
	"errors"
	"regexp"
	"time"
)

var emailRegex = regexp.MustCompile(`^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,4}$`)

type User struct {
	ID                  string     `json:"id" db:"id"`
	Username            string     `json:"username" db:"username"`
	Discriminator       string     `json:"discriminator" db:"discriminator"`
	DisplayName         *string    `json:"display_name" db:"display_name"`
	Pronouns            *string    `json:"pronouns" db:"pronouns"`
	Email               string     `json:"email" db:"email"`
	AvatarURL           *string    `json:"avatar" db:"avatar"`
	BannerURL           *string    `json:"banner" db:"banner"`
	Bio                 *string    `json:"bio" db:"bio"`
	Status              string     `json:"status" db:"status"`
	CustomStatus        *string    `json:"custom_status" db:"custom_status"`
	CustomStatusEmoji   *string    `json:"custom_status_emoji" db:"custom_status_emoji"`
	CustomStatusExpires *time.Time `json:"custom_status_expires_at" db:"custom_status_expires_at"`
	AccentColor         string          `json:"accent_color" db:"accent_color"`
	Badges              json.RawMessage `json:"badges" db:"badges"` // JSONB
	Flags               int             `json:"flags" db:"flags"`
	Verified            bool       `json:"verified" db:"verified"`
	Theme               string     `json:"theme" db:"theme"`
	Password            string     `json:"-" db:"password_hash"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
	LastSeen            time.Time  `json:"last_seen" db:"last_seen"`
	Phone               *string    `json:"phone" db:"phone"`
	TwoFactorEnabled    bool       `json:"two_factor_enabled" db:"two_factor_enabled"`

	// Email verification fields (from users table)
	EmailConfirmedAt            *time.Time `json:"email_confirmed_at,omitempty" db:"email_confirmed_at"`
	VerificationToken           string     `json:"-" db:"verification_token"`
	VerificationTokenExpiresAt  *time.Time `json:"-" db:"verification_token_expires_at"`
}

type PresenceStatus string

const (
	StatusOnline  PresenceStatus = "online"
	StatusIdle    PresenceStatus = "idle"
	StatusDND     PresenceStatus = "dnd"
	StatusOffline PresenceStatus = "offline"
)

type Presence struct {
	UserID    string         `json:"user_id"`
	Status    PresenceStatus `json:"status"`
	Custom    string         `json:"custom_status,omitempty"`
	UpdatedAt time.Time      `json:"updated_at"`
}

func (u *User) Validate() error {
	if len(u.Username) < 2 || len(u.Username) > 32 {
		return errors.New("username must be between 2 and 32 characters")
	}
	if !emailRegex.MatchString(u.Email) {
		return errors.New("invalid email format")
	}
	return nil
}
