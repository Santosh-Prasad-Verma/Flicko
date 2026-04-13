package models

import "time"

type Invite struct {
	Code      string     `json:"code" db:"code"`
	ServerID  string     `json:"server_id" db:"server_id"`
	ChannelID string     `json:"channel_id" db:"channel_id"`
	InviterID string     `json:"inviter_id" db:"inviter_id"`
	MaxAge    int        `json:"max_age" db:"max_age"`   // seconds, 0 = never
	MaxUses   int        `json:"max_uses" db:"max_uses"` // 0 = unlimited
	Uses      int        `json:"uses" db:"uses"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	ExpiresAt *time.Time `json:"expires_at" db:"expires_at"` // Based on created_at + max_age
}

type Notification struct {
	ID        string     `json:"id" db:"id"`
	UserID    string     `json:"user_id" db:"user_id"`
	Type      string     `json:"type" db:"type"` // mention, friend_request, system
	Title     string     `json:"title" db:"title"`
	Body      string     `json:"body" db:"body"`
	Link      *string    `json:"link,omitempty" db:"link"`
	ReadAt    *time.Time `json:"read_at,omitempty" db:"read_at"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
}

type ReadReceipt struct {
	UserID        string    `json:"user_id" db:"user_id"`
	ChannelID     string    `json:"channel_id" db:"channel_id"`
	LastMessageID string    `json:"last_message_id" db:"last_message_id"`
	ReadAt        time.Time `json:"read_at" db:"read_at"`
}
