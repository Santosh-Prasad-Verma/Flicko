package models

import (
	"errors"
	"time"
)

type ChannelType string

const (
	ChannelTypeText     ChannelType = "text"
	ChannelTypeVoice    ChannelType = "voice"
	ChannelTypeCategory ChannelType = "category"
	ChannelTypeDM       ChannelType = "dm"
)

type Channel struct {
	ID        string      `json:"id" db:"id"`
	ServerID  string      `json:"server_id,omitempty" db:"server_id"` // null for DMs
	Type      ChannelType `json:"type" db:"type"`
	Name      string      `json:"name" db:"name"`
	Topic     string      `json:"topic" db:"topic"`
	Position  int         `json:"position" db:"position"`
	ParentID  *string     `json:"parent_id,omitempty" db:"parent_id"` // category ID
	CreatedAt time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt time.Time   `json:"updated_at" db:"updated_at"`
}

func (c *Channel) Validate() error {
	if c.Type != ChannelTypeDM {
		if len(c.Name) < 1 || len(c.Name) > 100 {
			return errors.New("channel name must be between 1 and 100 characters")
		}
	}
	return nil
}
