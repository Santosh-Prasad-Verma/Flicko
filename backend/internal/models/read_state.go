package models

import (
	"time"

	"github.com/google/uuid"
)

type ReadState struct {
	ChannelID         uuid.UUID `json:"channel_id"`
	UserID            uuid.UUID `json:"user_id"`
	LastReadMessageID uuid.UUID `json:"last_read_message_id"`
	UpdatedAt         time.Time `json:"updated_at"`
}
