package models

import "time"

type ActivityType string

const (
	ActivityPlaying   ActivityType = "playing"
	ActivityStreaming ActivityType = "streaming"
	ActivityListening ActivityType = "listening"
	ActivityWatching  ActivityType = "watching"
	ActivityCustom    ActivityType = "custom"
)

type Activity struct {
	ID        string                 `json:"id" db:"id"`
	UserID    string                 `json:"user_id" db:"user_id"`
	Type      ActivityType           `json:"type" db:"type"`
	Name      string                 `json:"name" db:"name"`
	Details   *string                `json:"details,omitempty" db:"details"`
	State     *string                `json:"state,omitempty" db:"state"`
	Metadata  map[string]interface{} `json:"metadata,omitempty" db:"metadata"`
	StartedAt time.Time              `json:"started_at" db:"started_at"`
	EndsAt    *time.Time             `json:"ends_at,omitempty" db:"ends_at"`
	CreatedAt time.Time              `json:"created_at" db:"created_at"`
}
