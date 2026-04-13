package models

import (
	"errors"
	"time"
)

type Message struct {
	ID        string     `json:"id" db:"id"`
	ChannelID string     `json:"channel_id" db:"channel_id"`
	AuthorID  string     `json:"author_id" db:"author_id"`
	Content   string     `json:"content" db:"content"`
	EditedAt  *time.Time `json:"edited_at,omitempty" db:"edited_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

func (m *Message) Validate() error {
	if len(m.Content) < 1 || len(m.Content) > 4000 {
		return errors.New("message content must be between 1 and 4000 characters")
	}
	return nil
}
