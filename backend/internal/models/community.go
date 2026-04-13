package models

import "time"

type Community struct {
	ServerID       string    `json:"server_id" db:"server_id"`
	IsVerified     bool      `json:"is_verified" db:"is_verified"`
	Category       *string   `json:"category,omitempty" db:"category"`
	Tags           []string  `json:"tags" db:"tags"`
	RulesChannelID *string   `json:"rules_channel_id,omitempty" db:"rules_channel_id"`
	MemberCount    int       `json:"member_count" db:"member_count"`
	ActivityScore  float64   `json:"activity_score" db:"activity_score"`
	GrowthRate     float64   `json:"growth_rate" db:"growth_rate"`
	IsDiscoverable bool      `json:"is_discoverable" db:"is_discoverable"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

type DiscoverableCommunity struct {
	Community
	ServerName        string  `json:"server_name" db:"name"`
	ServerDescription *string `json:"server_description,omitempty" db:"description"`
	ServerIconURL     *string `json:"server_icon_url,omitempty" db:"icon_url"`
}

type CommunityEvent struct {
	ID              string     `json:"id" db:"id"`
	ServerID        string     `json:"server_id" db:"server_id"`
	CreatorID       string     `json:"creator_id" db:"creator_id"`
	Name            string     `json:"name" db:"name"`
	Description     *string    `json:"description,omitempty" db:"description"`
	EventType       string     `json:"event_type" db:"event_type"` // voice, stage, external, text
	Location        *string    `json:"location,omitempty" db:"location"`
	Status          string     `json:"status" db:"status"` // scheduled, active, completed, cancelled
	StartTime       time.Time  `json:"start_time" db:"start_time"`
	EndTime         *time.Time `json:"end_time,omitempty" db:"end_time"`
	RecurrenceRule  *string    `json:"recurrence_rule,omitempty" db:"recurrence_rule"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
	InterestedCount int        `json:"interested_count,omitempty"` // aggregated view
	AttendingCount  int        `json:"attending_count,omitempty"`  // aggregated view
}

type Announcement struct {
	ID               string     `json:"id" db:"id"`
	ServerID         string     `json:"server_id" db:"server_id"`
	ChannelID        string     `json:"channel_id" db:"channel_id"`
	AuthorID         string     `json:"author_id" db:"author_id"`
	Title            string     `json:"title" db:"title"`
	Content          string     `json:"content" db:"content"`
	AnnouncementType string     `json:"announcement_type" db:"announcement_type"` // news, update, alert, event
	Priority         int        `json:"priority" db:"priority"`
	IsPinned         bool       `json:"is_pinned" db:"is_pinned"`
	ViewCount        int        `json:"view_count" db:"view_count"`
	PublishedAt      *time.Time `json:"published_at,omitempty" db:"published_at"`
	ScheduledFor     *time.Time `json:"scheduled_for,omitempty" db:"scheduled_for"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}
