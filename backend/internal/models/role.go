package models

import "time"

type Role struct {
	ID          string    `json:"id" db:"id"`
	ServerID    string    `json:"server_id" db:"server_id"`
	Name        string    `json:"name" db:"name"`
	Color       string    `json:"color" db:"color"`
	Position    int       `json:"position" db:"position"`
	Permissions int64     `json:"permissions" db:"permissions"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type MemberRole struct {
	ServerID string    `json:"server_id" db:"server_id"`
	UserID   string    `json:"user_id" db:"user_id"`
	RoleID   string    `json:"role_id" db:"role_id"`
	AddedAt  time.Time `json:"added_at" db:"added_at"`
}

type Permission int64

const (
	PermManageServer    Permission = 1 << 0
	PermManageChannels  Permission = 1 << 1
	PermManageRoles     Permission = 1 << 2
	PermKickMembers     Permission = 1 << 3
	PermBanMembers      Permission = 1 << 4
	PermSendMessages    Permission = 1 << 5
	PermManageMessages  Permission = 1 << 6
	PermConnectVoice    Permission = 1 << 7
	PermSpeakVoice      Permission = 1 << 8
	PermMentionEveryone Permission = 1 << 9
	// Admin overrides all
	PermAdministrator Permission = 1 << 62
)
