package models

import (
	"time"
)

type ChannelDocument struct {
	ID          string    `json:"id"`
	ChannelID   string    `json:"channel_id"`
	Title       string    `json:"title"`
	StateVector []byte    `json:"state_vector,omitempty"`
	YDocBinary  []byte    `json:"ydoc_binary,omitempty"`
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}
