package models

import (
	"errors"
	"time"
)

type Message struct {
	ID              string     `json:"id" db:"id"`
	ChannelID       string     `json:"channel_id" db:"channel_id"`
	AuthorID        *string    `json:"author_id" db:"author_id"`
	Content         string     `json:"content" db:"content"`
	Type            int        `json:"type" db:"type"`
	Flags           int        `json:"flags" db:"flags"`
	Pinned          bool       `json:"pinned" db:"pinned"`
	MentionEveryone bool       `json:"mention_everyone" db:"mention_everyone"`
	TTS             bool       `json:"tts" db:"tts"`
	Nonce           *string    `json:"nonce" db:"nonce"`
	WebhookID       *string    `json:"webhook_id" db:"webhook_id"`
	ApplicationID   *string    `json:"application_id" db:"application_id"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at" db:"deleted_at"`
}

func (m *Message) Validate() error {
	if len(m.Content) < 1 || len(m.Content) > 4000 {
		return errors.New("message content must be between 1 and 4000 characters")
	}
	return nil
}
