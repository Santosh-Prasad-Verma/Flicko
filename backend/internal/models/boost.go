package models

import "time"

// ─── Server Boost Models ────────────────────────────────────────────────────

type ServerBoost struct {
	ID        string    `json:"id" db:"id"`
	ServerID  string    `json:"server_id" db:"server_id"`
	UserID    string    `json:"user_id" db:"user_id"`
	StartedAt time.Time `json:"started_at" db:"started_at"`
	ExpiresAt time.Time `json:"expires_at" db:"expires_at"`
	IsActive  bool      `json:"is_active" db:"is_active"`
}

type ServerBoostStatus struct {
	ServerID   string    `json:"server_id" db:"server_id"`
	BoostCount int       `json:"boost_count" db:"boost_count"`
	BoostLevel int       `json:"boost_level" db:"boost_level"` // 0-3
	Perks      any       `json:"perks" db:"perks"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

// BoostLevelThresholds defines boost count requirements per level.
var BoostLevelThresholds = map[int]int{
	1: 2,  // Level 1: 2+ boosts
	2: 7,  // Level 2: 7+ boosts
	3: 14, // Level 3: 14+ boosts
}

// BoostPerks defines what each level unlocks.
type BoostPerks struct {
	CustomStickerSlots  int  `json:"custom_sticker_slots"`
	AudioBitrateKbps    int  `json:"audio_bitrate_kbps"`
	UploadLimitMB       int  `json:"upload_limit_mb"`
	HasServerBanner     bool `json:"has_server_banner"`
	HasVanityURL        bool `json:"has_vanity_url"`
	HasInviteBackground bool `json:"has_invite_background"`
}

var LevelPerks = map[int]BoostPerks{
	0: {CustomStickerSlots: 0, AudioBitrateKbps: 96, UploadLimitMB: 8},
	1: {CustomStickerSlots: 50, AudioBitrateKbps: 128, UploadLimitMB: 8, HasInviteBackground: true},
	2: {CustomStickerSlots: 150, AudioBitrateKbps: 256, UploadLimitMB: 50, HasServerBanner: true},
	3: {CustomStickerSlots: 250, AudioBitrateKbps: 384, UploadLimitMB: 100, HasServerBanner: true, HasVanityURL: true},
}

// CalculateBoostLevel returns the boost level for a given boost count.
func CalculateBoostLevel(boostCount int) int {
	level := 0
	for l := 3; l >= 1; l-- {
		if boostCount >= BoostLevelThresholds[l] {
			level = l
			break
		}
	}
	return level
}

// ─── Webhook Models ─────────────────────────────────────────────────────────

type WebhookType string

const (
	WebhookTypeIncoming WebhookType = "incoming"
	WebhookTypeOutgoing WebhookType = "outgoing"
)

type Webhook struct {
	ID          string      `json:"id" db:"id"`
	ServerID    string      `json:"server_id" db:"server_id"`
	ChannelID   string      `json:"channel_id" db:"channel_id"`
	CreatorID   string      `json:"creator_id" db:"creator_id"`
	Name        string      `json:"name" db:"name"`
	Avatar      *string     `json:"avatar,omitempty" db:"avatar"`
	WebhookType WebhookType `json:"webhook_type" db:"webhook_type"`
	URL         string      `json:"url" db:"url"`
	Secret      string      `json:"secret" db:"secret"`
	IsActive    bool        `json:"is_active" db:"is_active"`
	UsageCount  int         `json:"usage_count" db:"usage_count"`
	CreatedAt   time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at" db:"updated_at"`
}
