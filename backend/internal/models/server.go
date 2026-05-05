package models

import (
	"errors"
	"time"
)

type Server struct {
	ID                          string    `json:"id" db:"id"`
	Name                        string    `json:"name" db:"name"`
	Description                 *string   `json:"description" db:"description"`
	OwnerID                     string    `json:"owner_id" db:"owner_id"`
	IconURL                     *string   `json:"icon_url" db:"icon_url"`
	BannerURL                   *string   `json:"banner_url" db:"banner_url"`
	SystemChannelID             *string   `json:"system_channel_id" db:"system_channel_id"`
	RulesChannelID              *string   `json:"rules_channel_id" db:"rules_channel_id"`
	PublicUpdatesChannelID      *string   `json:"public_updates_channel_id" db:"public_updates_channel_id"`
	PreferredLocale             string    `json:"preferred_locale" db:"preferred_locale"`
	Features                    []string  `json:"features" db:"features"`
	VerificationLevel           int       `json:"verification_level" db:"verification_level"`
	DefaultMessageNotifications int       `json:"default_message_notifications" db:"default_message_notifications"`
	ExplicitContentFilter       int       `json:"explicit_content_filter" db:"explicit_content_filter"`
	MFALevel                    int       `json:"mfa_level" db:"mfa_level"`
	NSFWLevel                   int       `json:"nsfw_level" db:"nsfw_level"`
	PremiumTier                 int       `json:"premium_tier" db:"premium_tier"`
	PremiumSubscriptionCount    int       `json:"premium_subscription_count" db:"premium_subscription_count"`
	VanityURLCode               *string   `json:"vanity_url_code" db:"vanity_url_code"`
	DiscoveryEnabled            bool      `json:"discovery_enabled" db:"discovery_enabled"`
	CreatedAt                   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt                   time.Time `json:"updated_at" db:"updated_at"`
}

type Member struct {
	ID                         string     `json:"id" db:"id"`
	ServerID                   string     `json:"server_id" db:"server_id"`
	UserID                     string     `json:"user_id" db:"user_id"`
	Nickname                   *string    `json:"nickname" db:"nickname"`
	Roles                      []string   `json:"roles" db:"roles"`
	JoinedAt                   time.Time  `json:"joined_at" db:"joined_at"`
	TimeoutUntil               *time.Time `json:"timeout_until,omitempty" db:"timeout_until"`
	CommunicationDisabledUntil *time.Time `json:"communication_disabled_until,omitempty" db:"communication_disabled_until"`
}

type ServerTemplate struct {
	Code           string    `json:"code" db:"code"`
	SourceServerID string    `json:"source_server_id" db:"source_server_id"`
	CreatorID      string    `json:"creator_id" db:"creator_id"`
	Name           string    `json:"name" db:"name"`
	Description    *string   `json:"description,omitempty" db:"description"`
	UsageCount     int       `json:"usage_count" db:"usage_count"`
	TemplateData   any       `json:"template_data" db:"template_data"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

func (s *Server) Validate() error {
	if len(s.Name) < 1 || len(s.Name) > 100 {
		return errors.New("server name must be between 1 and 100 characters")
	}
	return nil
}
