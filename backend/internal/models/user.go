package models

import (
	"errors"
	"regexp"
	"time"
)

var emailRegex = regexp.MustCompile(`^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,4}$`)

type User struct {
	ID        string    `json:"id" db:"id"`
	Username  string    `json:"username" db:"username"`
	Email     string    `json:"email" db:"email"`
	Password  string    `json:"-" db:"password_hash"`
	AvatarURL string    `json:"avatar_url" db:"avatar_url"`
	BannerURL string    `json:"banner_url" db:"banner_url"`
	Theme     string    `json:"theme" db:"theme"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
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
	if u.Password != "" && len(u.Password) < 8 {
		return errors.New("password must be at least 8 characters")
	}
	return nil
}
