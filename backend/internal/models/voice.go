package models

import "time"

type VoiceState struct {
	UserID         string    `json:"user_id" db:"user_id"`
	ChannelID      string    `json:"channel_id" db:"channel_id"`
	ServerID       string    `json:"server_id" db:"server_id"`
	SessionID      string    `json:"session_id" db:"session_id"`
	IsMuted        bool      `json:"is_muted" db:"is_muted"`
	IsDeafened     bool      `json:"is_deafened" db:"is_deafened"`
	IsSelfMuted    bool      `json:"is_self_muted" db:"is_self_muted"`
	IsSelfDeafened bool      `json:"is_self_deafened" db:"is_self_deafened"`
	IsStreaming    bool      `json:"is_streaming" db:"is_streaming"`
	IsVideo        bool      `json:"is_video" db:"is_video"`
	JoinedAt       time.Time `json:"joined_at" db:"joined_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

type ScreenShareType string

const (
	ShareTypeScreen ScreenShareType = "screen"
	ShareTypeWindow ScreenShareType = "window"
	ShareTypeTab    ScreenShareType = "tab"
)

type ScreenShare struct {
	ID          string          `json:"id" db:"id"`
	UserID      string          `json:"user_id" db:"user_id"`
	ChannelID   string          `json:"channel_id" db:"channel_id"`
	SessionID   string          `json:"session_id" db:"session_id"`
	ShareType   ScreenShareType `json:"share_type" db:"share_type"`
	Resolution  string          `json:"resolution" db:"resolution"`
	FrameRate   int             `json:"frame_rate" db:"frame_rate"`
	ViewerCount int             `json:"viewer_count" db:"viewer_count"`
	StartedAt   time.Time       `json:"started_at" db:"started_at"`
	EndedAt     *time.Time      `json:"ended_at,omitempty" db:"ended_at"`
}
