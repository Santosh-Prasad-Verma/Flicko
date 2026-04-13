package models

import "time"

type Sticker struct {
	ID          string    `json:"id" db:"id"`
	ServerID    string    `json:"server_id" db:"server_id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	Tags        []string  `json:"tags" db:"tags"`
	ImageURL    string    `json:"image_url" db:"image_url"`
	CreatorID   string    `json:"creator_id" db:"creator_id"`
	UsageCount  int       `json:"usage_count" db:"usage_count"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}
